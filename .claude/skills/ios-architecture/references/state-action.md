# State, Action, và ViewModel

## Hình dạng

Hai file một màn: `<Name>ViewModel.swift` + `<Name>View.swift`. Swift lồng type
được, nên `State`/`Action` nằm trong VM — không cần file `Contract` thứ ba như
bản Android.

```swift
@MainActor
public final class OrderListViewModel: ObservableObject {

    public struct State: Equatable {
        public var orders: Loadable<[Order]> = .idle
        public var query = ""
        public var alert: AlertState?

        // Derived là computed. Một field lưu song song là nguồn chân lý thứ hai,
        // và nó sai ngay lần đầu ai đó quên cập nhật.
        public var visibleOrders: [Order] { ... }
    }

    public enum Action: Equatable {
        case appeared, pulledToRefresh, retryTapped
        case queryChanged(String)
        case orderTapped(id: String)
        case alertDismissed
    }

    @Published public private(set) var state = State()

    public func send(_ action: Action) { ... }    // cửa DUY NHẤT để state đổi
}
```

`private(set)` là phần có răng: View không set được state, chỉ gửi action.

## `Loadable` thay cho ba field rời

```swift
public enum Loadable<Value: Equatable>: Equatable {
    case idle, loading, loaded(Value), failed(AppError)
}
```

`(value, isLoading, error)` biểu diễn được cả những trạng thái không thể xảy ra —
loading *và* failed, value cạnh error — rồi mỗi màn phải tự quyết định render gì
cho chúng. Ở đây trạng thái phi lý không biểu diễn được.

`reloading()` giữ `.loaded` khi refresh: về `.loading` sẽ thay list bằng spinner
mỗi lần pull-to-refresh, người dùng đọc đó là app làm mất thứ họ đang xem.

## Alert là state, không phải effect

```swift
public var alert: AlertState?
```

Alert là *trạng thái màn hình đang ở*, không phải một cú bắn one-shot: nó sống
qua backgrounding, nó là thứ nên hiện lại nếu view bị dựng lại, và test assert
được nó mà không cần SwiftUI. Vì thế **không có kênh `ViewEffect`** ở đây.

Bốn case của Compose ánh xạ thành:

| Compose `ViewEffect` | Ở đây |
|---|---|
| `ShowError` → Toast | gọi thẳng `toast.error(...)` — KVToastKit là fire-and-forget |
| Điều hướng có điều kiện | gọi thẳng `router.push(...)` |
| Alert / sheet | **state**: `state.alert`, View bind `.alert(item:)` |
| Haptic, scroll-to-id, focus, play sound | one-shot thật — mới cần cơ chế |

Chỉ nhóm cuối cần gì thêm, và một `@Published var effect: Effect?` + `.onChange`
rồi set `nil` là đủ.

## Xử lý lỗi trong `send`

```swift
private func handle(_ error: AppError) {
    switch error {
    case .cancelled:     break            // người dùng đi rồi, hiện gì cũng là nhiễu
    case .unauthorized:  break            // SessionController lo, tập trung một chỗ
    case .offline:
        if state.orders.value == nil { state.orders = .failed(error) }
        toast.error(error)                // nội dung cũ ở lại, toast giải thích vì sao cũ
    default:
        if state.orders.value == nil { state.orders = .failed(error) }
        else { state.alert = AlertState(error: error) }
    }
}
```

Quy tắc: **màn trống thì `.failed`, màn có nội dung thì toast/alert.** Thay nội
dung đang đọc bằng một trang lỗi vì một refresh thất bại là mất dữ liệu người
dùng đang xem.

## Task đơn cho việc load

```swift
private var loadTask: Task<Void, Never>?
loadTask?.cancel()
```

Một task in-flight, để pull-to-refresh hai lần nhanh không làm hai response về
sai thứ tự. `waitForLoad()` là hook cho test await thay vì sleep.

## Test

```swift
@MainActor
func test_orderTapped_pushesDetailRoute() {
    let (viewModel, router) = makeViewModel()
    viewModel.send(.orderTapped(id: "42"))
    XCTAssertEqual(router.operations, [.push(AnyKVRoute(OrderRoute.detail(id: "42")))])
}
```

Không `await`, không host, không simulator. `KVRouterSpy` ghi đồng bộ nên assert
**phủ định** ("validate fail thì không điều hướng") cũng chắc chắn, chứ không
phải một cuộc đua với timeout.

Toast: dùng `ToastRecorder` từ `Domain` — `ToastService.post` là `@Sendable` nên
capture một `var` local sẽ không compile ở Swift 6, và compiler đúng.

Tối thiểu ba test một feature: repository (qua `KVMockNetworkSession`), VM happy
path, VM error path.
