# KVRouterKit 3.5

Ba product, và việc chọn đúng product là cách ép kiến trúc bằng compiler:

| Product | Ai import | Có gì |
|---|---|---|
| `KVRouterCore` | ViewModel, presentation | `KVRoute`, `KVRestorableRoute`, `AnyKVRoute`, `KVRouting`, `KVPathCodec`, `KVUnhostedRouter`. Foundation only |
| `KVRouterKit` | View, App | `KVAppRouter`, `KVRouterHost`, `.kvRoutes`, `KVViewRouting`, transition |
| `KVRouterTesting` | test target | `KVRouterSpy` |

## Route là type của app

```swift
import KVRouterCore

public enum OrderRoute: KVRestorableRoute {     // = KVRoute + Codable
    case detail(id: String)
    case history
}
```

`KVRoute: Hashable, Sendable`. `KVRestorableRoute` thêm `Codable` +
`restorationID` (mặc định là tên type; override khi đổi tên type mà vẫn cần decode
path đã lưu).

## Registry — một chỗ duy nhất route gặp view

```swift
KVRouterHost(router: router, defaultTransition: .system) { RootView() }
    .kvRoutes { routes in
        routes.register(OrderRoute.self) { route in
            switch route {
            case .detail(let id): OrderDetailView(orderID: id)
            case .history:        OrderHistoryView()
            }
        }
    }
```

Hai tham số của host về back-swipe, đều đọc lại mỗi lần đổi nên bind được vào state:

| | |
|---|---|
| `interactivePopEnabled:` | `false` = tắt hẳn back-swipe. Router giữ recognizer của UIKit lúc đang attach, nên tự set `isEnabled = false` không ăn — đây là đường được hỗ trợ. Từ chối theo từng màn thì dùng `willPop(from:to:)` của middleware. |
| `interactivePopEdgeWidth:` (3.5.0) | Bề rộng vùng bắt swipe, mặc định 44pt. **Chỉ áp dụng cho màn dùng transition riêng của router** — `.system` và native zoom do UIKit vuốt, vùng đó là chuyện của UIKit. Đánh đổi: recognizer giờ là pan thường nên không được UIKit delay touch, content sát mép trái (row cuộn ngang, slider) có thể tranh chấp — nới/thu tham số này là van xả. |

- `@ViewBuilder`, view cụ thể, **không** `AnyView` ở call site.
- Nhiều route type song song → mỗi feature module tự đăng ký.
- Route type chưa register → `assertionFailure` ở debug, không phải màn trắng.
- ⚠️ `configure` chạy **một lần**. Destination đừng capture state thay đổi được.

## Hai port

```swift
@MainActor
public protocol KVRouting: AnyObject, Sendable {
    var stackDepth: Int { get }
    var topRoute: (any KVRoute)? { get }
    var routes: [any KVRoute] { get }
    func push(_ route: any KVRoute)
    func replaceTop(with route: any KVRoute)
    func setPath(_ routes: [any KVRoute])
    func pop(); func pop(count: Int); func popToRoot()
    func popTo(_ route: any KVRoute)
    func popTo(where predicate: @escaping (any KVRoute) -> Bool)
}
```

`KVViewRouting: KVRouting` thêm `push(_:transition:)`, `pushView(tag:_:)`,
`replaceTopWithView`, `popTo(tag:)`, `popTo(V.self)`.

`@Environment(\.router)` trả `any KVViewRouting`. Thiếu `KVRouterHost` thì nó là
`KVNullRouter` — assert kèm hướng dẫn, không im lặng.

## Placeholder cho DI

`KVUnhostedRouter` (Core, 3.2.0+) đứng thay `any KVRouting` cho tới khi
composition root gắn router thật: no-op và `assertionFailure` ở lệnh đầu tiên,
có nêu tên lệnh và route type. Hai lựa chọn hiển nhiên đều tệ hơn — `KVAppRouter`
chưa host thì nuốt push vào một stack vô hình, còn no-op im lặng thì đọc như nút
bấm hỏng.

`init()` là `nonisolated` từ **3.2.1** — và đó là điểm cả kiểu dùng này dựa vào:
`KVDependencyKey.liveValue` là một `static` nonisolated, nên một init thừa hưởng
`@MainActor` của class thì không gọi được ở đó ("main actor-isolated default value
in a nonisolated context"). Trên 3.2.0 phải tự viết một class tương đương; từ
3.2.1 dùng thẳng, xem `DI/Dependencies+Infra.swift` trong base.

`KVRouterSpy` (KVRouterTesting) thì *ghi lại* lệnh thay vì phàn nàn — đó là test
double, chỉ link vào test target.

⚠️ `stackDepth`/`topRoute`/`routes` là **snapshot, không observable**. Đọc từ VM
thì được; đừng lấy nó lái `body`.

## pushView — đường chính cho điều hướng trong luồng

```swift
router.pushView { OrderDetailView(order: order) }              // lazy
router.pushView(OrderDetailView(order: order))                 // dựng ngay tại call site
router.pushView(tag: "checkout") { CheckoutView() }            // để popTo(tag:)
router.pushView(transition: .depth) { DetailView(id: 42) }
router.popTo(OrderDetailView.self)                             // router ghi kiểu view lúc push
```

Chúng là `KVDynamicViewRoute` (mang `tag` + `typeName`) nên **middleware thấy
được**. Không `KVRestorableRoute` — closure chỉ sống trong process, nên
restoration sẽ cắt stack ở đó.

## Transition

Ba tầng ưu tiên: call site → host `defaultTransition` → `.system`.

```
.system  .fade  .scale  .scaleAndFade  .depth
.slide(edge:)  .sharedAxis(axis:)  .reveal(origin:)  .flip3D(axis:)
.pageTurn(edge:)  .zoom(sourceID:)  .custom(push:pop:animation:interactiveBack:)
```

Hero zoom cần view nguồn khai id trùng:

```swift
Button { router.pushView(transition: .zoom(sourceID: item.id)) { Detail(item: item) } }
    label: { Card(item: item) }
    .buttonStyle(.plain)
    .kvTransitionSource(id: item.id)
```

iOS 18+ dùng zoom native; 16–17 fallback live-view. Nguồn không còn hiện →
`.scaleAndFade` thay vì treo queue.

⚠️ `KVNavigationTransition` là `@MainActor` và **chưa** `Sendable` — không nhét
được vào một struct `Sendable`.

## Middleware

```swift
@MainActor
public protocol KVRouteMiddleware {
    func willNavigate(from: (any KVRoute)?, to: any KVRoute) async -> (any KVRoute)?
    func willPop(from: (any KVRoute)?, to: (any KVRoute)?) async -> Bool     // default true
}
```

`nil` = chặn, trả route khác = redirect. Có `middlewareTimeout` (mặc định 5s):
`willNavigate` timeout → coi như chặn, `willPop` timeout → cho pop. Timeout
assert vì nó là bug.

## Restoration

```swift
var codec = KVPathCodec()
codec.register(OrderRoute.self)
codec.register(AuthRoute.self)

try codec.encode(router.routes).write(to: url)      // lưu
router.setPath(try codec.decode(Data(contentsOf: url)))   // phục hồi
```

Thứ không mang qua được (`pushView`, type chưa register, payload không decode)
**cắt stack tại điểm đó**, không bỏ lỗ giữa: `[Home, Product, Checkout]` với
`Product` hỏng phục hồi thành `[Home]`, không phải `[Home, Checkout]`.

## Test

```swift
// VM: spy đồng bộ, không host, không await
let router = KVRouterSpy()
viewModel.send(.orderTapped(id: "42"))
#expect(router.operations == [.push(AnyKVRoute(OrderRoute.detail(id: "42")))])

// Tích hợp với router thật: await queue thay vì poll
router.push(OrderRoute.history)
await router.settle()
```

`KVRouterSpy.Operation`: `.push` `.replaceTop` `.setPath` `.pop` `.popCount`
`.popToRoot` `.popTo` `.popToMatching`. Có `pushed(R.self)` lọc theo type, và
`stack` mô phỏng.

## Không còn nữa ở v3

`KVAppRoute` · `appFeatureViewBuilder` · `deepLinkViewBuilder` · `handle(url:)` ·
`restorePath` · `KVSheetRoute` · `KVFullCoverRoute` · `present*` / `dismiss*` ·
`willDismiss` · `path`. Modal dùng SwiftUI; deep link app tự parse.
