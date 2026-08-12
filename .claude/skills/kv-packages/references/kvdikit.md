# KVDIKit 1.0

Không có bước registration: một dependency là một key có giá trị. Không compile
được nếu key thiếu giá trị — không có crash "unregistered type" để ship.

## Khai key

```swift
public enum OrderRepositoryKey: KVDependencyKey {
    public static let liveValue: any OrderRepositoryProtocol = { ... }()
    public static let testValue: any OrderRepositoryProtocol = StubOrderRepository()
}

public extension KVDependencyValues {
    var orderRepository: any OrderRepositoryProtocol {
        get { self[OrderRepositoryKey.self] }
        set { self[OrderRepositoryKey.self] = newValue }
    }
}
```

Ba giá trị: `liveValue` (bắt buộc), `previewValue` (default = live), `testValue`
(default = preview). Context tự dò từ process — XCTest → `.test`, Xcode preview →
`.preview`.

Key **không** có `testValue` vẫn resolve trong test nhưng log runtime issue lần
đầu (dấu tím trong Xcode). Luôn khai `testValue`, nếu không bạn sẽ có một test
gọi network thật mà không biết.

## Đọc

```swift
@KVDependency(\.orderRepository) private var repository       // trong class
@KVViewDependency(\.featureFlags) private var flags          // trong View body
```

`@KVDependency` resolve **lúc đọc**, không lúc `init`. Hai hệ quả quan trọng:

1. Thứ tự `prepare()` không thành bẫy — một `liveValue` đọc key khác vẫn thấy giá
   trị đã cấu hình sau đó.
2. Object đã tồn tại tự nhận thay đổi khi session mở/đóng.

Property wrapper dùng làm **biến local** là hợp lệ — đó là cách `convenience init()`
của ViewModel resolve dependency mà vẫn giữ designated init tường minh.

`@KVDependency` trong View body **không** nhận được override task-local (SwiftUI
đánh giá body ngoài task đã tạo nó) — dùng `@KVViewDependency` +
`.kvDependencies { }` cho preview.

Trong class `@Observable` (iOS 17+): `@ObservationIgnored @KVDependency(...)`.

## Bốn layer, trong ra ngoài

| Layer | Set bằng | Sống bao lâu |
|---|---|---|
| Scope | `withKVDependencies { } operation: { }` | một call và task con |
| Session | `KVDependencies.startSession { }` | một user đã đăng nhập |
| App | `KVDependencies.prepare { }` | cả process |
| Key | `liveValue` / `previewValue` / `testValue` | fallback |

Layer đầu tiên có giá trị cho key đó thắng.

## App layer

```swift
KVDependencies.prepare {              // gọi lúc launch, trong App.init
    $0.logger = logger
    $0.router = router
}
```

Đổi app layer khi session đang mở **không** với tới session layer, và KVDIKit nói
ra điều đó.

## Session layer

```swift
KVDependencies.startSession { $0.currentUser = user }   // gọi lại = đổi account
KVDependencies.endSession()                             // object ở trên được thả
```

Closure bắt đầu từ app layer, nên session dependency có thể **bọc** cái nó thay:
`values.apiClient = .authenticated(wrapping: values.apiClient, token: token)`.

Phản ứng với chính ranh giới:
```swift
for await session in KVDependencies.sessionChanges where session == nil { router.popToRoot() }
```

## Test

```swift
withKVDependencies { $0.orderRepository = StubOrderRepository(error: .offline) } operation: {
    let viewModel = OrderListViewModel()
    ...
}
```

Task-local: test song song override cùng một key không đá nhau, không teardown
nào để quên, không thứ tự nào để phụ thuộc. Override lồng được và với tới task
con (nhưng không tới `Task.detached`).

Object dựng bên trong scope giữ scope đó sau khi `operation` return.

## Hai ràng buộc

- **`Value` phải `Sendable`.** Struct của closure, `actor`, hoặc class `@MainActor`
  đều đạt. Đây là thứ cho phép resolve từ mọi isolation domain mà không cần `await`.
- **Library không được depend KVDIKit.** `Domain` và `Data` nhận dependency qua
  `init`. KVDIKit là keo tầng app; giữ nó ra ngoài là thứ cho phép hai tầng đó
  test được mà không dựng DI.
