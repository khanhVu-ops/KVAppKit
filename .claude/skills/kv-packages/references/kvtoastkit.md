# KVToastKit 1.0

App dùng nó **qua port `ToastService`** (ở `Domain`), nên ViewModel không import
KVToastKit. Bridge ở `DesignSystem/Toast/AppToastStyle.swift`.

## Cài một lần ở root

```swift
KVRouterHost(...) { RootView() }
    .kvToast(style: AppToast.style, center: toastCenter)
```

Center do app sở hữu và đăng ký vào DI, để service/ViewModel raise được toast:

```swift
let toastCenter = KVToastCenter()
KVDependencies.prepare { $0.toast = .live(toastCenter) }
```

`ToastService.live(_:)` gọi `center.post(_:)` — `post` là `nonisolated` và tự hop
sang main actor, nên VM gọi từ đâu cũng được, không cần `await`.

⚠️ **Đọc center *dưới* chỗ install, không ngang nó.** Mỗi `.kvToast(...)` tạo
center riêng và inject cho view nó gắn vào *và những gì bên dưới*. Một screen tự
gắn modifier lên body của chính nó vẫn đọc center của **cha**.

## Hiện toast

```swift
toast.show("Đã lưu", kind: .success)
toast.show("Upload thất bại", kind: .error, position: .bottom)
toast.show("Chạm để đóng", duration: nil)        // ở lại tới khi bị đóng
center.post(KVToastItem(message: "...", kind: .error))     // từ ngoài main actor
toast.dismiss(); toast.dismissAll()
```

`KVToastKind`: `.info` `.success` `.warning` `.error` — chỉ mang **nghĩa**, style
quyết định màu và icon.

`KVToastItem(id:message:kind:position:duration:haptic:content:onDismiss:)` — mọi
tham số đều có default. Factory: `.info(_:)` `.success(_:)` `.warning(_:)`
`.error(_:)`.

## Style

```swift
var appearance = KVToastAppearance.default
appearance.shape = .rounded(Radius.m)
appearance.font = AppFont.bodyStrong
appearance.tint = { kind in ... }         // @Sendable (KVToastKind) -> Color
KVDefaultToastStyle(appearance: appearance)
```

`KVDefaultToastStyle.init` là `@MainActor`, nên hàm/property dựng style phải
`@MainActor`.

Thay hẳn view: conform `KVToastStyle` (như `ButtonStyle`) — bạn sở hữu body,
package sở hữu gesture, queue và accessibility. Phần sau là phần đáng không viết
lại.

## Queue và trình bày

| Policy | Hành vi |
|---|---|
| `.replaceCurrent` (default) | toast mới thay cái đang hiện |
| `.enqueue` | xếp hàng, phát theo thứ tự gọi |
| `.dropWhilePresenting` | bỏ qua toast mới khi đang có cái hiện |

`.overlay` (default) vs `.window`: chọn `.window` nếu bạn hiện toast từ trong
`.sheet` / `.fullScreenCover`, vì `.overlay` bị chúng che. Đổi lại, `Material`
trong `.window` phải fallback sang `appearance.materialFallbackColor`.

## Test

`KVToastCenter` sở hữu queue và timing nên test được không cần SwiftUI:

```swift
let center = KVToastCenter(animation: KVToastAnimation(exitDuration: 0.01))
center.show("First", duration: nil)
center.show("Second", duration: nil)
try? await Task.sleep(nanoseconds: 150_000_000)
XCTAssertEqual(center.current?.message, "Second")
```

Nhưng để test **ViewModel**, đừng dùng center — dùng `ToastRecorder` từ `Domain`.
`ToastService.post` là `@Sendable`, nên capture một `var` local sẽ không compile ở
Swift 6, và compiler đúng: call có thể tới từ bất kỳ isolation nào.
