---
name: figma-intake
description: >-
  Đọc design trên Figma (qua Figma Dev Mode MCP) rồi định nghĩa **design system**
  cho app iOS này TRƯỚC KHI code màn nào: màu, font, spacing, radius vào
  `DesignSystem/Foundation` + `Tokens.xcassets`, và một bảng kiểm kê component
  chung (button, card, input, chip…) đối chiếu với component đã có. Dùng skill này
  khi nhận link Figma, khi được yêu cầu "check design", "define design system",
  "lấy token từ Figma", hoặc trước bất kỳ việc code UI nào từ design. Code màn
  hình trước khi có token là cách chắc chắn nhất để có hex literal rải khắp
  `Features/` — và `check-arch.sh` luật 6 fail build vì đúng chuyện đó.
---

# Figma → design system

Đây là **cửa đầu tiên**, và nó là cửa chặn: không code màn nào trước khi token có
tên. Một màn viết `Color(hex: "#4C6FFF")` là một màn không restyle được, và luật 6
của `check-arch.sh` fail build khi thấy color literal ngoài `DesignSystem`.

## Trước khi bắt đầu: MCP đã nối chưa

Skill này cần Figma Dev Mode MCP. Server chạy **trong app Figma desktop**
(Preferences → `Enable local MCP server`), nghe ở `http://127.0.0.1:3845/mcp`.
Kiểm sống chết bằng cổng, đừng tin cảm giác:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3845/mcp   # 400 = sống, 000 = chưa bật
```

`400` cho một `GET` trần là **đúng** — endpoint chỉ nhận `POST` JSON-RPC. `000`
mới là chưa bật.

Sáu tool, đối chiếu trực tiếp với danh sách server tự khai (JSON-RPC **tools·list**)
ngày 14/08
(`Figma Dev Mode MCP Server 1.0.0`) — không phải nhớ ra:

| Tool | Việc |
|---|---|
| `get_design_context` | tool **chính** cho design→code: reference code của một node |
| `get_variable_defs` | Figma Variables → `{'icon/default/secondary': #949494}`. Nguồn token sạch nhất |
| `get_screenshot` | ảnh node, hoặc node đang chọn trong Figma desktop |
| `get_metadata` | metadata node/page — doc của chính nó nói ưu tiên `get_design_context` |
| `get_motion_context` | keyframe, easing |
| `get_figjam` | node FigJam |

Server có thể đổi tool giữa các bản Figma. Thấy lệch thì **liệt kê lại** rồi sửa
bảng này, đừng chống chế bằng cách đoán:

```
ToolSearch: "figma"
```

Không có tool nào thì **dừng và nói rõ**, đừng tự nghĩ ra token. Một bộ design
system bịa ra trông y như một bộ đọc từ Figma, và sai lệch chỉ lộ ra khi designer
mở app lên xem.

## Bốn bước

### 1. Kiểm kê, chưa viết code

`get_variable_defs` trên node gốc (hoặc trên frame chứa design system) rồi lập
bảng **trước khi** sửa file nào. File chưa dùng Variables thì rơi về
`get_design_context` và đọc giá trị trong reference code — kém sạch hơn một bậc,
và đáng nói với designer. Bảng này là
thứ đưa người ta xem, và là chỗ phát hiện việc design chưa chốt:

```
Figma                     → token app                  ghi chú
Primary/500  #4C6FFF       AppColor.Brand.primary      có dark: #7C93FF
Neutral/900  #111827       AppColor.Text.primary
Title/28/Bold              AppFont.titleL              Figma cố định 28pt
spacing/md   16            Spacing.m
```

Ba thứ phải hỏi lại designer, đừng tự quyết:

- **Màu thiếu dark mode.** App này có dark mode thật (mọi colorset đều có
  `appearances: luminosity dark`). Một token chỉ có light là một câu hỏi, không
  phải một giá trị mặc định.
- **Font cố định pt.** Figma nói 28pt; app này bắt buộc đi qua text style để
  Dynamic Type còn scale (xem bước 3).
- **Cùng một hex hai tên khác nhau**, hoặc hai hex gần nhau cùng một tên. Nhân
  bản token ở bước này rẻ hơn nhiều lần sửa sau.

### 2. Màu → `Tokens.xcassets`, tên theo *nghĩa*

Mỗi màu là một `.colorset` trong `DesignSystem/Resources/Tokens.xcassets`, hai
appearance:

```json
{
  "colors": [
    { "idiom": "universal",
      "color": { "color-space": "srgb",
                 "components": { "red": "0x4C", "green": "0x6F", "blue": "0xFF", "alpha": "1.000" } } },
    { "idiom": "universal",
      "appearances": [ { "appearance": "luminosity", "value": "dark" } ],
      "color": { "color-space": "srgb",
                 "components": { "red": "0x7C", "green": "0x93", "blue": "0xFF", "alpha": "1.000" } } }
  ],
  "info": { "author": "xcode", "version": 1 }
}
```

Rồi khai trong `DesignSystem/Foundation/AppColor.swift`. **Tên theo nghĩa, không
theo màu**: `Semantic.error` sống sót khi designer đổi đỏ sang cam; `red500` thành
một lời nói dối ngay lúc đó. Nếu Figma đặt tên theo thang màu (`Red/500`) thì việc
của bước này là *dịch* sang nghĩa, và ghi lại bản dịch vào `DESIGN_TOKENS.md`.

### 3. Font — giữ Dynamic Type, kể cả khi Figma cố định pt

`AppFont` khai mọi style qua `Font.system(.textStyle)`. Một `.system(size: 28)`
cứng bỏ qua cỡ chữ hệ thống và là lý do phổ biến nhất khiến app không dùng được ở
mức chữ lớn. Nên map Figma → **text style gần nhất**, đừng map sang số:

```swift
static let titleL = Font.system(.largeTitle, design: .rounded).weight(.bold)
```

Font riêng của brand thì cần thêm file font + `UIAppFonts` trong `Info.plist` +
`project.yml` — base **không** có `UIAppFonts` nào, nên đó là việc của skill
`ios-project`, không phải sửa tay `Info.plist`. Và khi có custom font thì vẫn phải
đi qua `Font.custom(_:size:relativeTo:)`, không phải `Font.custom(_:size:)`, để
Dynamic Type sống.

### 4. Component: đối chiếu trước, viết sau

Base đã có sẵn, và phần lớn design không cần cái mới:

| Có sẵn | Ở đâu |
|---|---|
| `PrimaryButtonStyle` (`.buttonStyle(.primary)`) | `DesignSystem/Components/` |
| `cardStyle`, `Surface` | `DesignSystem/Modifiers/Surface.swift` |
| `LoadableContent`, `LoadingView`, `EmptyStateView`, `ErrorStateView` | `DesignSystem/Components/` |
| `RemoteImage` (Kingfisher) | `DesignSystem/Components/` |
| `Spacing`, `Radius` | `DesignSystem/Foundation/AppFont.swift` |

Với mỗi component chung trong Figma, kết luận đúng một trong ba: **đã có** (dùng
luôn), **có nhưng thiếu variant** (thêm variant vào component cũ), **chưa có**
(viết mới trong `DesignSystem/Components/`). Đừng tạo `CouponCard` khi cái cần là
`cardStyle` + nội dung khác.

Component mới thì bắt buộc có `#Preview` — luật 11 của `check-arch.sh` — và
preview nên có đủ variant, vì đó là chỗ designer soi mà không cần build app.

## Đầu ra

- `DesignSystem/Foundation/AppColor.swift`, `AppFont.swift` (+ `Spacing`, `Radius`)
- `DesignSystem/Resources/Tokens.xcassets/<Tên>.colorset/`
- `docs/DESIGN_TOKENS.md` — bảng Figma → token, **kèm link node**, và danh sách
  câu hỏi còn treo cho designer
- Component mới (nếu có) trong `DesignSystem/Components/`

## Xong thì

```bash
./tools/verify.sh
```

Luật 6 kiểm không còn color literal ngoài `DesignSystem`; luật 11 kiểm preview.
File `.swift` mới thì hook đã `xcodegen generate`, nhưng **thêm folder mới trong
`Tokens.xcassets` không phải file Swift** — nếu asset mới không hiện ra thì chạy
`xcodegen generate` bằng tay.

Bước tiếp theo là `figma-spec`, không phải code màn hình.
