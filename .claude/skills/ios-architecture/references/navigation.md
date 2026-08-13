# Navigation

KVRouterKit 3.2 cho hai đường. Chọn đường theo **ai biết đích đến**, không theo
sở thích.

## Hai đường

```swift
// ViewModel — đích do nghiệp vụ quyết định. Port `KVRouting`, không có SwiftUI.
router.push(OrderRoute.detail(id: id))

// View — trong luồng, đã có object trong tay. Truyền thẳng, kiểu UIKit.
@Environment(\.router) private var router          // any KVViewRouting
router.pushView(transition: .zoom(sourceID: order.id)) {
    OrderDetailView(order: order)
}
```

Ranh giới này trùng ba thứ cùng lúc, nên nó không tuỳ tiện:

| | View đẩy view | VM đẩy route |
|---|---|---|
| Ai biết đích | View (bấm row → detail) | VM (đăng nhập xong → tuỳ response) |
| Có đáng unit test | Không — xem preview/screenshot là ra | Có — `KVRouterSpy` |
| Có cần addressable | Không | Thường có |

`KVRouting` **không có** `pushView` — nó nằm ở `KVViewRouting` trong
KVRouterKit. Nên file ViewModel chỉ `import KVRouterCore` là đủ ép luật bằng
compiler.

## Khi nào một màn cần `KVRoute`

Chỉ khi phải **addressable**: deep link, push notification, state restoration,
hoặc bị auth-guard chặn. Còn lại `pushView { }` — không route case, không
registry, và `popTo(DetailView.self)` chạy được (route không mang kiểu view).

Ranh giới thực dụng: **`pushView` trong cùng feature module, `push(route)` khi
xuyên module.** Vì `pushView { OrderDetailView(order:) }` bắt module gọi phải
import module chứa view đó — trong cùng module thì miễn phí, xuyên module thì
bạn vừa tạo một cạnh phụ thuộc, và đúng chỗ đó mới đáng trả phí indirection.

Hệ quả: định nghĩa "feature module" = **một luồng**, không phải một màn.
`Features/Order` chứa list + detail + filter. App 6 module thực tế ra ~10 route,
không phải 40.

## Route sống trong feature module

```swift
// Features/Order/OrderRoute.swift — không import SwiftUI
import KVRouterCore
public enum OrderRoute: KVRestorableRoute {
    case detail(id: String)
    case history
}
```

`KVRestorableRoute` = `KVRoute` + `Codable`, opt-in cho restoration và deep link.

Mapping route → view chỉ ở một chỗ, `App/Navigation/AppRoutes.swift`:

```swift
.kvRoutes { routes in
    routes.register(OrderRoute.self) { route in
        switch route {
        case .detail(let id): OrderDetailView(orderID: id)
        case .history:        OrderHistoryView()
        }
    }
    routes.register(AuthRoute.self) { ... }
}
```

Mỗi feature đăng ký route type của mình → **không có file trung tâm nào mà cả
team phải sửa**, và `Features/Order` không cần biết `Features/Auth` tồn tại.

⚠️ `kvRoutes` chạy `configure` **một lần**. Destination không được capture state
thay đổi được — cái này compile ngon và sai âm thầm:

```swift
routes.register(R.self) { _ in DetailView(theme: currentTheme) }   // theme đóng băng mãi
```
Đọc từ environment trong chính view thay vì capture.

## Màn vừa addressable vừa nhận object

Cho hai init. Đây cũng là cách xử cái bẫy duy nhất của việc truyền object: object
là snapshot, list refresh thì detail cầm data cũ.

```swift
init(order: Order)      // pushView trong luồng — render ngay, không spinner
init(orderID: String)   // route / deep link / restore — tự fetch
```

Màn detail coi object truyền vào là **seed để render ngay**, rồi vẫn refresh theo
id ở `.task`.

## Deep link

Package không còn `handle(url:)`. App tự parse — và đó là điểm tốt, vì nó thành
pure function test được không cần router:

```swift
.onOpenURL { url in
    guard let route = AppDeepLink.route(for: url) else { return }
    router.setPath(AppDeepLink.stack(for: route))
}
```

`stack(for:)` chứ không `push`: chỉ push màn đích để lại người dùng cách một cú
back-swipe là rơi ra khỏi app. Cho link một stack thì Back đưa họ *vào* app.

## Middleware

Chặn ở một chỗ, không rải `if` đầu mỗi màn:

```swift
struct AuthGuardMiddleware: KVRouteMiddleware {
    func willNavigate(from: (any KVRoute)?, to: any KVRoute) async -> (any KVRoute)? {
        guard requiresAuth(to), !isSignedIn() else { return to }
        return AuthRoute.signIn
    }
}
```

Middleware nhận `any KVRoute` nên thấy **cả** màn đẩy bằng `pushView` (chúng là
`KVDynamicViewRoute`, mang `tag` + `typeName`). Đừng log associated value của
route: nó có thể chứa id, email hoặc token, và hàm này chạy mỗi lần điều hướng.
