# DI với KVDIKit

## Key chỉ ở `DI`

Feature *đọc* key; chỉ composition root *ghi*. Đó là thứ ngăn một feature với
tay vào `Data` lấy type cụ thể.

```swift
public enum OrderRepositoryKey: KVDependencyKey {
    public static let liveValue: any OrderRepositoryProtocol = {
        @KVDependency(\.apiClient) var client        // resolve khi ĐỌC
        @KVDependency(\.logger) var logger
        return OrderRepository(client: client, logger: logger.scoped(category: "order"))
    }()
    public static let testValue: any OrderRepositoryProtocol = StubOrderRepository()
}
```

`@KVDependency` bên trong `liveValue` là chi tiết quan trọng: KVDIKit resolve lúc
đọc, nên **thứ tự `prepare()` không thành bẫy** — repository này vẫn thấy API
client thật dù client được cấu hình sau khi key này khai báo.

Luôn khai `testValue`. Thiếu nó, KVDIKit log runtime issue (dấu tím trong Xcode)
nhưng test vẫn chạy — và bạn sẽ có một test gọi network thật mà không biết.

## Ba key cần `prepare`

`logger`, `toast`, `router` là object `@MainActor` chỉ tồn tại sau `App.init`,
nên key ship một placeholder và composition root thay đồ thật:

```swift
KVDependencies.prepare {
    $0.logger = logger
    $0.apiClient = APIClientFactory.make(...)
    $0.toast = .live(toastCenter)
    $0.router = router
}
```

Placeholder **assert** thay vì im lặng: một lệnh điều hướng âm thầm không làm gì
là bug khó nhất trong khu vực này. Xem `DI/UnhostedRouter.swift`.

## ViewModel: hai init

```swift
// Designated — test truyền fake vào đây, nên không có gì resolve ngầm
public init(repository:..., router:..., toast:..., logger:...)

// Convenience — View gọi cái này
public convenience init() {
    @KVDependency(\.orderRepository) var repository
    ...
    self.init(repository: repository, ...)
}
```

Được cả hai: dependency vẫn đọc được bằng mắt ở designated init, mà View viết
được `@StateObject private var viewModel = OrderListViewModel()`. Property wrapper
dùng làm biến local là hợp lệ trong Swift.

## Session layer

Thứ gì thuộc về một user cụ thể thì vào session layer, để sign out là được giải
phóng chứ không phải để lại object của user cũ:

```swift
func didSignIn(_ session: AuthSession) {
    KVDependencies.startSession { $0.currentUser = session.user }
}
func signOut() {
    KVDependencies.endSession()          // object ở trên được thả ở đây
}
```

Object đã tồn tại tự nhận thay đổi, vì `@KVDependency` resolve lúc đọc chứ không
lúc `init`. Muốn phản ứng với chính ranh giới đó thì nghe `sessionChanges` — xem
`App/Session/SessionController.swift`.

## Test override

```swift
withKVDependencies { $0.orderRepository = StubOrderRepository(error: .offline) } operation: {
    let viewModel = OrderListViewModel()
    ...
}
```

Task-local nên test song song không đá nhau và không có teardown nào để quên.
Với ViewModel, init trực tiếp bằng designated init thường rõ hơn — dùng
`withKVDependencies` khi cần override một dependency nằm sâu bên trong.

## Không để library depend KVDIKit

`Domain` và `Data` nhận dependency qua `init`. KVDIKit là keo tầng app; giữ nó ra
khỏi hai tầng đó là thứ cho phép chúng test được mà không cần dựng DI.
