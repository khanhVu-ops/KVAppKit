---
name: sheet
description: >-
  Dựng một tấm dán đáy / bottom sheet / modal trong SwiftUI. Dùng khi task nhắc
  "sheet", "bottom sheet", "popup", "modal", "tấm dán đáy", "half sheet", "action
  sheet", "confirm dialog", khi một node Figma là một tấm trượt từ đáy lên, hoặc
  khi phải chọn giữa `.sheet`, `.fullScreenCover` và `overlay`.
---

# Sheet

Hai luật, và `tools/check-arch.sh` kiểm cả hai:

1. **Sheet là `.sheet` của hệ thống. Không bao giờ là `overlay`.**
2. **Mọi `.sheet` đặt nền presentation.**

Mặc định dùng `bottomSheet` — nó đã gắn sẵn cả bộ:

```swift
.bottomSheet(
    isPresented: viewModel.state.sheet != nil,
    onDismiss: { viewModel.send(.dismissSheet) }
) {
    sheetContent
}
```

Hết. Không cần detent, không cần scrim, không cần vạch kéo.

## 1 · Không dùng `overlay` cho sheet

`overlay { scrim + content }` *trông* đúng và thiếu hết những gì UIKit làm sẵn cho
một tấm dán đáy:

| Có sẵn ở `.sheet` | Phải tự dựng nếu dùng `overlay` |
|---|---|
| gạt xuống để đóng | pan gesture + ngưỡng vận tốc |
| đà quán tính khi gạt | animation theo vận tốc, không phải theo thời lượng |
| bàn phím đẩy sheet lên | quan sát keyboard frame, đo, dịch |
| VoiceOver coi phần dưới sheet là không chạm được | `accessibilityViewIsModal` + quản lý focus |
| `Reduce Motion` | đọc setting và đổi transition |
| lớp mờ đúng độ | tự vẽ, tự khớp dark mode |

Dựng lại từng cái đó là dựng lại `UISheetPresentationController`. Không ai dựng
lại hết — cái bị bỏ sẽ là accessibility, thứ không lộ ra khi bấm thử trên máy dev.

**Đây là code thật đã từng có trong một repo dùng bộ luật này**, và nó qua được
review vì trên máy người viết nó nhìn giống hệt sheet.

Ba lý do người ta viện ra để né `.sheet`, và cả ba đã có lời giải sẵn:

| Lý do | Lời giải |
|---|---|
| "`.sheet` chiếm cả màn trên iOS 16" | `sheetFitHeight()` đo nội dung rồi đưa vào `presentationDetents` |
| "design vẽ vạch kéo riêng" | `sheetDragIndicator()` — vạch hệ thống đã đúng vị trí, đúng dark mode, VoiceOver đọc được |
| "cần lớp mờ phía sau" | hệ thống tự vẽ |

Sheet vẫn là **state**, không phải hiệu ứng một lần: `isPresented` đọc từ `state`
của ViewModel, nên nó sống sót qua rebuild và test khẳng định được mà không cần
dựng SwiftUI.

## 2 · Luôn đặt nền presentation

Detent cao bằng nội dung, nhưng tấm sheet còn dải safe area dưới (home indicator)
mà nội dung không với tới. **Không đặt nền thì dải đó mang màu mặc định của hệ
thống**, và nó lộ ra thành một vệt khác màu dưới đáy — nhìn như card bị hụt.

`.background(...)` trên content **không** giải quyết: nó tô content, không tô tấm
sheet.

Dùng `sheetBackground(_:)`, không gọi thẳng `presentationBackground`:
`presentationBackground` chỉ có từ **iOS 16.4**, và helper tự hạ xuống
`.background(color)` trên 16.0. Trên bản dưới 16.4 mép sheet vẫn là nền hệ thống —
đó là đánh đổi có ý thức, không phải bug cần sửa.

## Tự xếp modifier — đúng thứ tự này

Chỉ khi `bottomSheet` không đủ (cần detent riêng, cần nhiều detent, sheet cao cả
màn). Thứ tự **không** đổi được:

```swift
.sheet(isPresented: $shown) {
    MySheet()
        .fixedSize(horizontal: false, vertical: true)   // trước sheetFitHeight
        .sheetFitHeight()
        .sheetDragIndicator(.visible)                   // .hidden nếu design không vẽ
        .sheetCornerRadius(Radius.l)                    // no-op dưới 16.4
        .sheetBackground(AppColor.Surface.card)         // bắt buộc
}
```

**`fixedSize` trước `sheetFitHeight` không phải tuỳ chọn.** Chiều cao sheet suy ra
từ chiều cao nội dung, nên hai thứ đó là một vòng: SwiftUI đề nghị chiều cao detent
hiện tại → nội dung co vào cho vừa → phép đo trả về con số đã co → detent chốt ở
đó. Vòng này **đứng yên ở chỗ sai**, và đã thấy thật: một câu mô tả hai dòng bị cắt
còn `"…so you can select i…"` rồi ở lại như vậy.

`fixedSize(horizontal: false, vertical: true)` bắt nội dung báo chiều cao **nó
muốn** thay vì chiều cao được đề nghị, nên phép đo đọc đúng.

## Modifier có sẵn

| Modifier | Ở đâu | Làm gì |
|---|---|---|
| `bottomSheet(isPresented:onDismiss:content:)` | `DesignSystem/Modifiers/View+BottomSheet.swift` | cả bộ, dùng mặc định |
| `sheetFitHeight(maxFraction:)` | `View+SheetFitHeight.swift` | đo content → `presentationDetents` |
| `sheetBackground(_:)` | `View+Availability.swift` | `presentationBackground`, tự hạ xuống `.background` dưới 16.4 |
| `sheetDragIndicator(_:)` | `View+Availability.swift` | `presentationDragIndicator` |
| `sheetCornerRadius(_:)` | `View+Availability.swift` | `presentationCornerRadius`, no-op dưới 16.4 |

`sheetFitHeight` có ba chi tiết đừng viết lại:

- Đo bằng `background(GeometryReader)`, **không** bọc content trong `GeometryReader`
  — reader chiếm hết không gian cha, nên bọc vào là content bị kéo giãn và chiều
  cao đo được thành chiều cao màn hình.
- Detent luôn có ít nhất một giá trị: `presentationDetents([])` là **crash**, và
  lần đo đầu tiên luôn là 0.
- Kẹp trần theo màn hình (`maxFraction`, mặc định 0.9). Content dài hơn màn mà đưa
  nguyên vào detent thì sheet cao quá màn, không kéo xuống và không đóng được.

## Hai ngoại lệ

**Sheet do UIKit sở hữu** — `ShareSheet`, `MailComposerView`, bất cứ gì khai
`UIViewControllerRepresentable` / `UIViewRepresentable`. Chrome của chúng là của
UIKit và ta không sơn nó: dùng `.ignoresSafeArea()`, không dùng bộ modifier trên.
Luật tự miễn chúng bằng cách đọc conformance, không có danh sách tay.

**`.fullScreenCover`** phủ kín màn nên không có dải nào hở → không bắt buộc nền.
**Trừ** khi nền của màn là một **ảnh**: ảnh cần một nhịp để giải mã, và trong nhịp
đó thứ hiện ra là nền presentation. Luật không kiểm `fullScreenCover`, nên chỗ này
là ở người.

## Hai presentation trên cùng một view — một cái biến mất

Trên iOS 16, hai `.sheet` (hay `.sheet` + `.photosPicker`) gắn trên **cùng** một
view thì cái gắn sau ăn cái trước, và cái kia không bao giờ hiện ra — im lặng,
không log, không cảnh báo. Tách ra hai view khác nhau.

Và **đừng đợi `onDismiss` để mở cái thứ hai**: `onDismiss` không chạy khi sheet
đóng vì state tự đặt về `nil`. Đã thử và bỏ.

## Sau khi dựng

```bash
./tools/check-arch.sh
```

Luật sheet là một trong các luật của script đó, và `check-arch-selftest.sh` chứng
minh nó vẫn bắt được vi phạm.
