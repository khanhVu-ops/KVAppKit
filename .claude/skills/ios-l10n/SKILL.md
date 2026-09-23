---
name: ios-l10n
description: >-
  Thêm hoặc sửa text người dùng thấy trên app iOS này cho đúng: 19 file
  `<lang>.lproj/Localizable.strings` là nguồn duy nhất, key viết bằng English, text đi
  xuyên tầng mang `LocalizedStringResource`, và **mọi text mới phải có đủ 19 bản dịch
  ngay lúc thêm**. Dùng skill này khi viết bất kỳ chuỗi
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

Bảng dịch là **19 file `.strings`**: `App/Resources/<lang>.lproj/Localizable.strings`.

Không dùng String Catalog, và lý do là kinh nghiệm chứ không phải khẩu vị: catalog bị
**chính build ghi vào** — compiler bóc mọi literal `Text`/`Button` thêm vào ở trạng thái
chưa dịch (kể cả chuỗi đang cố ý nằm trong baseline), rồi đóng dấu `"extractionState":
"stale"` lên những key mà `Core`/`Domain` dùng nhiều nhất, đọc như "không ai dùng nữa".
File `.strings` phẳng thì diff và merge đọc được, mọi hệ dịch thuê ngoài đều nhận, và
không ai tự sửa nó sau lưng.

Hai thứ mất đi, nói ra để không tưởng nhầm là được canh:
- **Không có cột State.** `.strings` không phân biệt "đã dịch" với "điền tạm bằng tiếng
  Anh"; `check-l10n.sh` chỉ đảm bảo đủ key, đủ ngôn ngữ, không giá trị rỗng.
- **Plural cần `.stringsdict` riêng** — xem mục Plural bên dưới.

Thêm một ngôn ngữ là ba chỗ: thư mục `.lproj`, `LANGUAGES` trong `tools/check-l10n.sh`,
và Localizations của project (Xcode → Project → Info) — synchronized folder copy `.lproj`
vào bundle nhưng không tự thêm nó vào `knownRegions`.

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
Button("Retry", action: onRetry)          // SwiftUI tra bảng dịch tự động
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
var userMessage: LocalizedStringResource? {
    switch self {
    case .offline:
        return "No internet connection. Please try again."   // literal LÀ key
    case .server(let message, _):
        // Text của server, viết cho đúng người này bằng ngôn ngữ của họ — không phải
        // key, đừng dịch lại.
        return LocalizedStringResource(String.LocalizationValue(message))
    case .cancelled:
        return nil            // "không hiện gì" là một trạng thái, không phải chuỗi rỗng
    ...
```

`LocalizedStringResource` là Foundation, nên `Domain` và `Core` dùng được mà không phá
luật 1 (chỉ import Foundation). Đây là điểm mấu chốt: giá trị mang **key**, và View
resolve nó theo `\.locale` lúc render — nên đổi ngôn ngữ trong app là câu lỗi đổi theo.

`check-l10n.sh` canh tầng này bằng hai luật: mọi key dùng trong code phải có thật trong
bảng dịch (gõ sai thì app hiện nguyên chữ English, không crash, không log — chỉ người
dùng thấy), và `String(localized:)` **không được xuất hiện** ngoài `LanguageStore` —
xem bảng đo bên trên.

### 3. Thêm key vào **cả 19 file**

```strings
/* Button on the error state view. */
"Retry" = "Thử lại";
```

Cùng một key, cùng thứ tự, ở tất cả 19 file — `en.lproj` giữ bản English (key = value).
Thiếu ở một ngôn ngữ là `check-l10n.sh` fail.

Luôn viết comment `/* … */`. Người dịch (hoặc model dịch) không thấy màn hình; "Close"
trên một nút khác "Close" trong một câu.

⚠️ **Thiếu một dấu `;`** thì `CFBundle` bỏ qua **toàn bộ file**: cả ngôn ngữ đó rơi về
tiếng Anh, build không báo gì, không log gì. `check-l10n.sh` chạy `plutil -lint` từng
file chính vì lỗi này không tự lộ ra.

### 4. Kiểm

```bash
./tools/check-l10n.sh
```

## Đừng để build tự sinh bảng dịch

Build settings của project giữ `SWIFT_EMIT_LOC_STRINGS = NO`. Đây là dấu vết của quãng repo còn dùng
String Catalog: bật nó thì mỗi lần build, compiler bóc chuỗi vào catalog và làm bẩn đúng
file mà `check-l10n.sh` vừa kiểm sạch — xanh, build xong, rồi `verify.sh` đỏ ngay sau đó.

Với `.strings` thì không có chuyện tự ghi, nhưng cứ để tắt: bảng dịch ở repo này là thứ
người viết, script canh. Nếu ai đó chuyển ngược về catalog, cái bẫy kia quay lại nguyên vẹn.

## Plural — đừng nối chuỗi

Tiếng Ả Rập có sáu dạng số, tiếng Nga ba. `"\(count) orders"` là sai ở phần lớn ngôn
ngữ trong danh sách trên, kể cả khi nó đúng ở English và tiếng Việt.

Với `.strings` thì plural nằm ở file riêng: `<lang>.lproj/Localizable.stringsdict`, một
plist khai `NSStringPluralRuleType` cho từng dạng (`one`, `few`, `many`, `other`…). Mỗi
ngôn ngữ có bộ dạng riêng và **chỉ khai đúng những dạng nó có** — thừa một dạng không
sai, thiếu một dạng thì câu đó rơi về `other` và đọc sai với người bản ngữ.

Đây là chỗ String Catalog tiện hơn thật (một ô "Vary by Plural" trong Xcode). Đánh đổi có
ý thức: hiếm dùng hơn nhiều so với việc merge một file dịch, và `.stringsdict` vẫn là
định dạng mọi công cụ dịch hiểu.

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

1. Tạo `App/Resources/<code>.lproj/Localizable.strings` với **đủ mọi key** đang có.
2. Thêm `case` vào `AppLanguage` (picker) và mã đó vào `LANGUAGES` của
   `tools/check-l10n.sh` — script so ba chỗ này với nhau, nên lệch một chỗ là fail.
3. Xcode → Project → Info → Localizations → `+` ngôn ngữ đó (nó ghi vào `knownRegions`
   trong `project.pbxproj`). Bỏ qua bước này thì app vẫn chạy đúng ngôn ngữ, nhưng
   Xcode không liệt kê nó và export localization bỏ sót.
4. `./tools/verify.sh`, rồi mở app bằng ngôn ngữ mới và xem một màn thật.

Bớt một ngôn ngữ thì xoá ở cả bốn chỗ. Để lại một thư mục `.lproj` không còn khai là rác —
nó sẽ được ai đó dịch tiếp vì tưởng còn dùng.
