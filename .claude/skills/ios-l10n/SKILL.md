---
name: ios-l10n
description: >-
  Thêm hoặc sửa text người dùng thấy trên app iOS này cho đúng: String Catalog
  (`Localizable.xcstrings`) là nguồn duy nhất, key viết bằng English, và **mọi text
  mới phải có đủ 19 bản dịch ngay lúc thêm**. Dùng skill này khi viết bất kỳ chuỗi
  nào người dùng đọc được — `Text`, `Button`, tiêu đề, message của alert/toast,
  `AppError.userMessage`, validate của use case — hoặc khi thêm/bớt ngôn ngữ, làm
  plural, format số/ngày/tiền, kiểm layout RTL cho tiếng Ả Rập. Một chuỗi hardcode
  không làm gì cả cho tới khi có người mở app bằng ngôn ngữ khác, nên đây là loại nợ
  chỉ lộ ra ở tay người dùng.
---

# Text và 19 ngôn ngữ

App khai **19 ngôn ngữ**, English là source:

```
en (source) · ar · zh-Hans · zh-Hant · nl · fr · de · hi · id
it · ja · ko · pt-BR · pt-PT · ru · es · th · tr · vi
```

`App/Resources/Localizable.xcstrings` là **nguồn duy nhất**. XcodeGen suy
`knownRegions` từ chính catalog — thêm một ngôn ngữ ở đó là danh sách Localizations
trong Xcode tự đúng, và build ra một folder `.lproj` cho mỗi ngôn ngữ. Không có chỗ
thứ hai khai ngôn ngữ, nên không có chỗ nào để lệch.

## Luật

**Text mới phải có đủ 19 bản dịch ngay trong commit thêm nó.** Không "để sau", không
"tạm English". `tools/check-l10n.sh` fail nếu thiếu, và nó chạy trong `verify.sh`.

Lý do luật này khắt khe hơn cảm giác cần thiết: thiếu một bản dịch **không hỏng gì
cả**. App fallback về English, không test nào đỏ, không log nào kêu. Nó chỉ lộ ra khi
một người dùng thật mở app bằng tiếng Thái và thấy một câu English giữa màn hình. Đó
là loại nợ không có ai đòi, nên nếu không chặn lúc thêm thì không bao giờ trả.

Nợ có sẵn của template nằm trong `tools/l10n-baseline.txt`. Danh sách đó **chỉ được
co lại**: trả một dòng thì xoá dòng đó, và script fail nếu còn dòng đã chết.

## Thêm một string

### 1. Trong View — key là chính chuỗi English

```swift
Button("Retry", action: onRetry)          // SwiftUI tra catalog tự động
Text("Orders")
.navigationTitle("Order detail")
```

Key viết bằng English để code đọc được cả khi chưa dịch. Đừng đặt key kiểu
`order_detail_title`: nó biến mọi file view thành một câu đố phải tra bảng mới hiểu.

Chuỗi **không** dịch — mã đơn, số, tên riêng — nói tường minh:

```swift
Text(verbatim: order.code)                // check-l10n.sh miễn `verbatim:`
```

## Đổi ngôn ngữ trong app — và vì sao kiểu dữ liệu quyết định chuyện đó

Người dùng chọn ngôn ngữ trong app (`LanguagePickerView`), `LanguageStore` giữ lựa
chọn, `MyApp` bơm vào `\.locale`. Không ghi `AppleLanguages` rồi bắt khởi động lại.

Đo thật trên simulator (ngôn ngữ máy `vi`, environment `ja`):

| Cách viết | Đổi theo ngôn ngữ chọn trong app? |
|---|---|
| `Text("key")` (`LocalizedStringKey`) | có |
| `Text(LocalizedStringResource("key"))` | có |
| `Text(String(localized: "key"))` | **không** |
| `String(localized: "key", locale: ja)` | **không** — `locale:` chỉ đổi format số/ngày, không đổi `.lproj` |
| `Text(value, format: …)` | có |
| `value.formatted(…)` | **không** |

Nên **text đi xuyên tầng mang `LocalizedStringResource`, không mang `String`**:
`AppError.userMessage`, `AlertState.title/message`, `ToastService.post`,
`ValidationError.userMessage`. Trả `String` là resolve sớm — và mọi cách sai ở bảng
trên đều compile, chạy, không log gì; chúng chỉ lộ ra khi người dùng đổi ngôn ngữ rồi
thấy một nửa màn hình không đổi theo.

Hai điều đã trả giá để biết:

- **`navigationTitle` không đổi theo `\.locale` khi đang hiển thị.** Nó do navigation
  bar của UIKit vẽ và không resolve lại; tiêu đề giữ nguyên ngôn ngữ cũ tới khi mở lại
  màn. Vì vậy `MyApp` gắn `.id(language.current)` — đổi ngôn ngữ là rebuild cả cây.
  Stack **không** mất: `KVAppRouter` giữ path bên ngoài view identity (đã kiểm: đang ở
  màn chi tiết, đổi ngôn ngữ, vẫn ở màn chi tiết).
- **Toast nằm ngoài environment của SwiftUI** (KVToastKit dựng window riêng), nên nó
  không thấy `\.locale`. Đó là chỗ **duy nhất** cần `Bundle` của một `.lproj` cụ thể:
  `LanguageStore.localized(_:)`. `check-l10n.sh` cấm `String(localized:)` ở mọi nơi
  khác.

### 2. Ngoài View (ViewModel, Domain, Core) — `LocalizedStringResource`

```swift
// Core/AppError.swift
var userMessage: String {
    switch self {
    case .offline:
        return String(localized: "No internet connection. Please try again.")
    case .server(let message, _):
        return message          // text của server, KHÔNG phải key — đừng bọc
    ...
```

`String(localized:)` là Foundation, nên `Domain` và `Core` dùng được mà không phá luật
1 (chỉ import Foundation).

`check-l10n.sh` canh tầng này bằng hai luật: mọi key trong `String(localized: "...")`
phải có thật trong catalog (gõ sai key thì app hiện nguyên chữ English, không crash,
không log — chỉ người dùng thấy), và trong `Core/`+`Domain/` thì `return "..."` **phải**
đi qua `String(localized:)`. Miễn `return ""` và chuỗi nội suy thuần như
`"\(code): \(message)"` — cái đầu là "không hiện gì", cái sau là diagnostic cho log.

### 3. Vào catalog, đủ 19 ngôn ngữ

Mở `Localizable.xcstrings` bằng Xcode (nó có editor riêng, dùng nó thay vì sửa JSON
tay khi có thể). Sửa bằng script thì đây là hình dạng:

```json
"Retry" : {
  "comment" : "Button on the error state view",
  "localizations" : {
    "vi" : { "stringUnit" : { "state" : "translated", "value" : "Thử lại" } },
    "ja" : { "stringUnit" : { "state" : "translated", "value" : "再試行" } }
  }
}
```

`state` phải là `translated`. `new` hay `needs_review` đều bị `check-l10n.sh` tính là
thiếu — cố ý: "đã điền" và "đã dịch" là hai chuyện khác nhau.

Luôn viết `comment`. Người dịch (hoặc model dịch) không thấy màn hình; "Close" trên
một nút khác "Close" trong một câu.

### 4. Kiểm

```bash
./tools/check-l10n.sh
```

## Plural — đừng nối chuỗi

Tiếng Ả Rập có sáu dạng số, tiếng Nga ba. `"\(count) orders"` là sai ở phần lớn ngôn
ngữ trong danh sách trên, kể cả khi nó đúng ở English và tiếng Việt.

Catalog có variant theo plural: trong Xcode chọn string → **Vary by Plural**. JSON có
thêm một lớp `variations.plural.{one,other,...}`. Mỗi ngôn ngữ có bộ dạng riêng, và
Xcode biết ngôn ngữ nào cần dạng nào — đó là lý do nên mở bằng Xcode cho string dạng
này thay vì viết JSON tay.

## Số, ngày, tiền — `Text(value, format:)`, KHÔNG phải `.formatted()`

```swift
Text(order.total, format: .currency(code: "VND"))          // ✅ theo ngôn ngữ đang chọn
Text(order.placedAt, format: .dateTime.day().month().year())

Text(order.total.formatted(.currency(code: "VND")))        // ❌ đứng yên
```

Cả hai đều "dùng locale", nên nhìn như nhau. Khác nhau ở **lúc nào**:
`.formatted()` dựng chuỗi ngay tại chỗ bằng `Locale.current` — ngôn ngữ của **máy** —
còn `Text(value, format:)` để SwiftUI format lúc render, theo `\.locale` của
environment. Đã thấy tận mắt trên simulator: sau khi đổi app sang tiếng Nhật, cùng một
đơn hàng hiện `đ250,000` ở list (`Text(value, format:)`) và `250.000 đ` ở màn chi tiết
(`.formatted()`).

`check-l10n.sh` fail nếu `.formatted(` xuất hiện trong `Features/` hay `DesignSystem/`.

Tự nối `"\(total) đ"` thì hỏng ở cả 19 ngôn ngữ, không chỉ chuyện locale.

## RTL — tiếng Ả Rập

Layout của repo này đã đúng RTL vì nó chỉ dùng `.leading`/`.trailing`, không dùng
`.left`/`.right`. Giữ như vậy:

- Alignment, padding, `HStack` spacing: `leading`/`trailing`.
- Icon chỉ hướng (mũi tên "next"): dùng SF Symbol có biến thể RTL, hoặc lật theo
  `\.layoutDirection`.
- Kiểm bằng preview, không cần đổi ngôn ngữ máy:
  ```swift
  #Preview { OrderListView().environment(\.layoutDirection, .rightToLeft) }
  ```
- Kiểm thật thì đổi scheme argument `-AppleLanguages (ar)`, hoặc đổi ngôn ngữ simulator.

## Chỗ script chưa với tới

`check-l10n.sh` soi: chuỗi ở vị trí `Text`/`Button`/`Label`/`navigationTitle`/
`confirmationDialog`/`alert`, `title:`/`message:` của alert, và `toast.success/error/...`
trong `Features/` + `DesignSystem/`; key của `String(localized:)` ở mọi tầng; và
`return "..."` thô trong `Core/`+`Domain/`. Nó **chưa** soi:

- `Data/` — tầng đó đầy literal wire-level (path, JSON key, key keychain) nên luật
  `return "..."` sẽ toàn báo sai. Text người dùng gần như không sinh ở đây; nếu có thì
  vẫn phải `String(localized:)`.
- Chuỗi ghép động (`"\(a) \(b)"`) — script không đọc được ý định. Ghép câu bằng nội suy
  cũng là cách làm sai với ngôn ngữ có trật tự từ khác; dùng một key có placeholder.
- `accessibilityLabel`, `accessibilityHint` — vẫn phải dịch, VoiceOver đọc chúng.

Khoảng trống của script không phải là sự cho phép.

## Thêm hoặc bớt một ngôn ngữ

1. Sửa danh sách `LANGUAGES` trong `tools/check-l10n.sh` — đó là nguồn của luật.
2. Điền ngôn ngữ đó cho **mọi** string đang có trong catalog (script sẽ chỉ ra thiếu ở
   đâu).
3. `xcodegen generate` → `knownRegions` tự cập nhật.
4. `./tools/verify.sh`, rồi mở app bằng ngôn ngữ mới và xem một màn thật.

Bớt một ngôn ngữ thì xoá ở cả hai chỗ. Để lại bản dịch của một ngôn ngữ không còn khai
là rác — nó sẽ được bảo trì bởi người tưởng rằng nó còn dùng.
