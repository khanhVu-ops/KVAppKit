# Luật riêng cho iOS 16

Đây là file quan trọng nhất trong bộ reference này, vì nó là chỗ SwiftUI iOS 16
khác Compose và khác iOS 17 về **bản chất**, không phải về cú pháp.

## Vấn đề gốc

`ObservableObject` phát tín hiệu theo **object**, không theo property.

```swift
state.isLoading = true      // → objectWillChange → MỌI view observe VM chạy lại body
```

Compose thì `StateFlow<UiState>` + recomposition *skip* được composable có input
không đổi. iOS 17 thì `@Observable` track theo từng property được đọc. iOS 16
không có cả hai.

**Suy luận ngược trực giác: tách `State` thành nhiều `@Published` KHÔNG giúp gì.**
Một struct hay tám property, `objectWillChange` vẫn phát một lần và mọi observer
vẫn re-render. Đừng mất công tách state — hãy tách *view*.

## Cách duy nhất hiệu quả: chẻ view con nhận value

Body của view cha luôn chạy lại. Body view **con** được bỏ qua nếu input so sánh
bằng nhau — SwiftUI so các stored property của view struct. Nên chi phí bị chặn
ở biên view con:

```swift
// ✅ Chi phí bị chặn: OrderRows.body không chạy lại khi chỉ `query` đổi
var body: some View {
    OrderRows(orders: viewModel.state.visibleOrders,
              onTap: { viewModel.send(.orderTapped(id: $0)) })
}

struct OrderRows: View, Equatable {
    let orders: [Order]
    let onTap: (String) -> Void
    // Closure không so được; so theo dữ liệu. Trong Swift 6, `View` là
    // @MainActor-isolated nên `==` phải `nonisolated`.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.orders == rhs.orders }
}
```

```swift
// ❌ Con giữ VM → re-render mỗi lần bất kỳ field nào đổi, Equatable vô nghĩa
struct OrderRows: View {
    @ObservedObject var viewModel: OrderListViewModel
}
```

## Bốn luật cứng

1. **View con không nhận `ViewModel`** — chỉ value + closure. Màn hình sở hữu VM
   bằng `@StateObject`; đó là trường hợp duy nhất được phép giữ VM.
2. **View con nhận >1 property thì cho `Equatable`** và tự viết `==` (bỏ closure
   ra ngoài phép so).
3. **Text đang gõ giữ ở `@State` cục bộ**, commit có debounce. Xem dưới.
4. **Store theo màn, không theo app.** Một `ObservableObject` toàn app khiến mọi
   view re-render khi bất kỳ field nào đổi, và iOS 16 không có selector để scope
   lại. Redux global chờ iOS 17.

## TextField: cái bẫy đắt nhất

Bind thẳng qua `send` → mỗi ký tự là một state mới là một lần cả màn chạy lại:

```swift
// ❌ 20 ký tự = 20 lần body cha chạy lại
TextField("Email", text: Binding(
    get: { viewModel.state.email },
    set: { viewModel.send(.emailChanged($0)) }))
```

Nhưng commit **chỉ khi mất focus** cũng sai — nút Submit bind vào state đã commit
sẽ còn disabled trong khi người dùng thấy cả hai field đã đầy. Nhìn như app hỏng.
(Đây là bug thật đã xảy ra khi dựng base project này.)

Đúng: debounce bằng `.task(id:)`, nó tự cancel lần trước khi id đổi nên không có
timer nào phải quản.

```swift
@State private var text = ""
@State private var committed = ""

.task(id: text) {
    guard text != committed else { return }
    try? await Task.sleep(nanoseconds: 250_000_000)
    guard !Task.isCancelled else { return }
    commit()
}
.onSubmit(commit)
.onChange(of: isFocused) { if !$0 { commit() } }   // rời field không phải chờ debounce
```

Xem bản đầy đủ ở `Features/Auth/SignIn/SignInView.swift` → `DebouncedField`.

## Lên iOS 17 — diff theo file, không đụng kiến trúc

```diff
-@MainActor
-public final class OrderListViewModel: ObservableObject {
+@MainActor
+@Observable
+public final class OrderListViewModel {
-    @Published public private(set) var state = State()
+    public private(set) var state = State()
-    private let repository: any OrderRepositoryProtocol
+    @ObservationIgnored private let repository: any OrderRepositoryProtocol
```
```diff
-    @StateObject private var viewModel = OrderListViewModel()
+    @State private var viewModel = OrderListViewModel()
```

`State`, `Action`, `send(_:)`, router, DI, test — không đổi một dòng. Luật 1–3
thành tối ưu hoá tuỳ chọn, luật 4 bỏ được.

**Không thử làm cả hai đường cùng lúc.** `@Observable` là macro compile-time gắn
conformance vào protocol `Observable` (`@available(iOS 17)`), nên class buộc phải
`@available(iOS 17, *)` — không khởi tạo được trên iOS 16. Cách duy nhất là tự
viết lại machinery của macro (`ObservationRegistrar` sau một `Any?` gated theo
availability, mỗi property tự gọi `access`/`withMutation` **và**
`objectWillChange.send()`). Hợp lý cho một class hạ tầng của package — như
`KVAppRouter` đang làm — nhưng nhân lên 40 ViewModel thì là hai đường quan sát
phải test song song, và bug tệ nhất là "màn này re-render trên 16 mà không trên
17 vì quên một dòng `access`".
