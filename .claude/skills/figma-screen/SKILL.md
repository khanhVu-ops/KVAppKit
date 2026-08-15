---
name: figma-screen
description: >-
  Code MỘT màn SwiftUI từ một node Figma: dùng đúng token và component đã định
  nghĩa (`AppColor`, `AppFont`, `Spacing`, `PrimaryButtonStyle`, `cardStyle`),
  export ảnh **vector** vào asset catalog thay vì chụp PNG, và đưa mọi chuỗi hiển
  thị vào 19 file `.strings`. Dùng skill này khi được yêu cầu "code màn này theo
  Figma", "dựng UI từ node", hoặc khi làm task màn hình trong `docs/TASKS.md`.
  Chạy sau `figma-intake` và `figma-spec` — code màn khi chưa có token là cách
  chắc chắn nhất để có hex literal trong `Features/`, và luật 6 fail build.
---

# Một node Figma → một màn SwiftUI

Trước khi mở Figma, đọc lại `docs/DESIGN_TOKENS.md`. Việc của skill này là **ráp
token đã có**, không phải phát minh giá trị mới. Thấy một màu chưa có tên thì đó
là việc của `figma-intake`, không phải chỗ để viết một hex.

## Bốn luật của màn hình, kiểm được bằng script

| Luật | Script bắt |
|---|---|
| Không color literal ngoài `DesignSystem` | `check-arch.sh` 6 |
| View con nhận **value**, không nhận ViewModel; có `Equatable` | `check-arch.sh` 7 |
| Mọi `View` có `#Preview` | `check-arch.sh` 11 |
| Mọi chuỗi user-facing có key trong 19 ngôn ngữ | `check-l10n.sh` |

Cái thứ tư là cái hay quên nhất khi dựng từ design: Figma đưa sẵn chữ, và chép
thẳng vào `Text("Áp dụng")` thì fail `check-l10n.sh` — hoặc tệ hơn, lọt qua và
thành một app chỉ có một ngôn ngữ. Text trong design là **bản tiếng Việt của một
key**, không phải chuỗi. Xem skill `ios-l10n`; text mới phải có đủ 19 bản dịch
ngay lúc thêm.

## Ảnh: vector, không phải PNG

Icon và illustration export **SVG hoặc PDF**, không phải PNG @1x/@2x/@3x:

⚠️ **Chưa xác minh**: Dev Mode MCP (1.0.0) có 6 tool — `get_design_context`,
`get_variable_defs`, `get_screenshot`, `get_metadata`, `get_motion_context`,
`get_figjam` — và `get_screenshot` trả **ảnh raster**, không phải SVG. Đường ra
file vector chưa được thử lần nào. Lần đầu làm thật thì kiểm xem
`get_design_context` có trả link asset không; không có thì export tay từ Figma
hoặc đi REST `GET /v1/images/:key?ids=…&format=svg`. **Đừng báo là đã export
vector khi thứ nằm trong asset là PNG** — nó nhìn giống nhau cho tới lúc phóng to.

1. Export node từ Figma dạng SVG (hoặc PDF).
2. Bỏ vào `App/Resources/Assets.xcassets/<Tên>.imageset/`.
3. `Contents.json` phải bật giữ vector, và chỉ một scale:

```json
{
  "images": [ { "idiom": "universal", "filename": "icon-coupon.svg" } ],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "preserves-vector-representation": true, "template-rendering-intent": "template" }
}
```

`preserves-vector-representation` là thứ khiến ảnh còn nét khi phóng to hoặc khi
Dynamic Type kéo icon lớn lên; thiếu nó thì Xcode rasterize lúc build và vector
thành vô nghĩa. `template-rendering-intent: template` chỉ dùng cho **icon một
màu** — khi đó tô bằng `.foregroundStyle(AppColor…)` và icon tự đổi theo dark
mode. Illustration nhiều màu thì bỏ dòng đó.

Ảnh **từ URL** (ảnh sản phẩm, avatar) thì không phải asset: dùng `RemoteImage`
(Kingfisher) — `AsyncImage` không cache xuống đĩa và tải lại mỗi lần cell cuộn qua.

Thêm imageset **không phải là thêm file `.swift`**, nên hook `PostToolUse` không
chạy. Ảnh không hiện ra thì `xcodegen generate` bằng tay.

## Dựng view

Ráp theo thứ tự này, vì nó cũng là thứ tự dễ sửa nhất khi design đổi:

1. **Bố cục trước, màu sau.** `VStack`/`HStack`/`Grid` + `Spacing.*`. Khoảng cách
   lấy từ token, đừng lấy số đo trong Figma — Figma đo pixel, app đo point và
   phải co giãn theo Dynamic Type.
2. **Component có sẵn trước, view mới sau.** `PrimaryButtonStyle`, `cardStyle`,
   `LoadableContent`, `EmptyStateView`, `ErrorStateView`, `RemoteImage`.
3. **Chẻ view con ngay**, đừng để một `body` dài rồi hẹn tách sau. View con nhận
   value + closure và conform `Equatable` với `nonisolated static func ==`. Đây là
   luật **hiệu năng** của iOS 16, không phải thẩm mỹ: `ObservableObject` phát tín
   hiệu theo object, nên mọi view đọc ViewModel đều rebuild cùng lúc.
4. **`#Preview` cho mọi view**, và preview nên có trạng thái đáng xem — rỗng, lỗi,
   dữ liệu dài — chứ không chỉ một trạng thái đẹp.

Text đang gõ giữ ở `@State` cục bộ trong view con, commit lên ViewModel có debounce
bằng `.task(id:)`. Đẩy từng ký tự lên ViewModel là rebuild cả màn mỗi phím.

## Kiểm bằng mắt, không chỉ bằng test

Test xanh không chứng minh màn hình giống design. Sau khi build:

```bash
./tools/verify.sh
```

rồi mở app trên simulator (skill `ios-verify`) và soi đúng màn vừa dựng, tối thiểu
bốn thứ: **light + dark**, **cỡ chữ lớn nhất**, **vùng chạm** (bấm thật vào từng
row/nút — `Button` + `.buttonStyle(.plain)` trong `List` mất vùng chạm cả ô nếu
thiếu `.contentShape(Rectangle())`), và **một ngôn ngữ khác** để thấy chuỗi đã đi
qua bảng dịch.

So với node Figma bằng screenshot cạnh nhau. Lệch spacing thì sửa token hoặc sửa
view — đừng nhét một con số lẻ vào một chỗ.

## Xong thì

Cập nhật `docs/TASKS.md`: cột **Code** ✅ khi màn chạy được, cột **Test** ✅ chỉ
khi test đã chạy xanh. Hai cột tách nhau có lý do — gộp lại thì "xong" luôn có
nghĩa là "code xong".
