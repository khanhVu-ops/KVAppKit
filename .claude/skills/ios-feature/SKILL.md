---
name: ios-feature
description: >-
  Pipeline chuẩn để làm một feature trong app iOS SwiftUI này, từ spec/API tới
  code chạy được và test: route → entity → repository protocol → use case → DTO →
  endpoint → repository impl → DI key → ViewModel(State/Action/send) → View →
  register route → test → verify. Dùng skill này khi được yêu cầu làm feature
  mới, thêm màn hình, "code màn login", "làm chức năng đặt hàng", "thêm luồng X",
  hoặc khi sửa một feature đã có mà phải chạm nhiều tầng. Skill giữ cho 12 bước
  không bỏ sót bước nào — quên DI key, quên register route, hay quên test là ba
  lỗi hay gặp nhất khi làm nhanh.
---

# Làm một feature

## Trước khi viết dòng code đầu tiên

1. **Đọc skill `ios-architecture`** nếu chưa. Bảng "file này đặt ở đâu" là thứ
   bạn sẽ cần ở mọi bước.
2. **Mở thư mục Features/Order/OrderList (repo template KVAppBase) ra soi.** Nó là bản mẫu đã build, test và chạy
   được. Bắt chước nó; đừng phát minh biến thể.
3. **Có spec chưa?** Không có thì viết `docs/features/<tên>.md` theo
   `assets/feature-spec.md`, xác nhận với người dùng, rồi mới code. Spec sai thì
   12 bước dưới đều sai.
4. **Endpoint đã có chưa?** Xem `docs/API_INVENTORY.md`.

## 12 bước, đi từ trong ra ngoài

Thứ tự này không tuỳ tiện: mỗi bước sau dùng type của bước trước. Làm ngược (View
trước) thì ViewModel bị nhào theo layout thay vì theo nghiệp vụ, và bạn sẽ phát
hiện API thiếu field khi UI đã xong.

| # | Bước | Ở đâu | Ghi chú |
|---|---|---|---|
| 1 | Route | `Features/<X>/<X>Route.swift` | **chỉ khi** cần addressable — xem dưới |
| 2 | Entity | `Domain/Entities/` | + fixture trong `Fixtures.swift` |
| 3 | Repository protocol | `Domain/Repositories/` | mô tả *cái gì*, không nói *bằng gì* |
| 4 | Use case | `Domain/UseCases/` | **chỉ khi có logic thật**, xem dưới |
| 5 | DTO + mapper | `Data/DTO/` | field optional, `toDomain()` cho default |
| 6 | Endpoint | `Data/Network/Endpoints/` | khai `cachePolicy` có ý thức |
| 7 | Repository impl | `Data/Repositories/` | map lỗi qua `perform(_:_:)` |
| 8 | Stub | `Data/Testing/` | để làm `testValue` |
| 9 | DI key | `DI/Dependencies+*.swift` | **kèm `testValue`** |
| 10 | ViewModel | `Features/<X>/<Screen>/` | `State` + `Action` + `send`, `import KVRouterCore` |
| 11 | View + view con | `Features/<X>/<Screen>/` | con nhận value + closure, `Equatable` |
| 12 | Register route | `App/Navigation/AppRoutes.swift` | quên = màn trắng + assert ở debug |

Bước 12 là chỗ compiler giúp bạn: thêm case vào enum route mà quên nhánh trong
`switch` là **lỗi compile**, không phải bug runtime. Đó là tính năng.

## Bước 1: màn này có cần route không?

Chỉ khi phải **addressable**: deep link, push notification, state restoration, hoặc
bị auth-guard chặn.

Còn lại đẩy bằng `router.pushView { DetailView(order: order) }` — không route
case, không registry, truyền object trực tiếp, và `popTo(DetailView.self)` chạy
được. Đây là đường **chính**, không phải đường phụ.

Ranh giới: `pushView` trong cùng feature module, `push(route)` khi xuyên module.

## Bước 4: có cần use case không?

Có, khi có validate, orchestrate nhiều repository, hoặc một quy tắc nghiệp vụ.
Xem `SignInUseCase`: validate → authenticate → persist, ba việc phải xảy ra cùng
nhau và đúng thứ tự.

Không, khi nó forward một dòng sang repository. Đó là nghi lễ; để ViewModel gọi
repository trực tiếp.

## Test: tối thiểu ba

1. **Repository** với `KVMockNetworkSession` — chạy pipeline thật, gồm một case
   payload thiếu field và một case lỗi server.
2. **ViewModel happy path** — `send(action)` → assert `state`.
3. **ViewModel error path** — offline hoặc server error → assert state + toast.

Và ít nhất một assert **phủ định**: "validate fail thì không điều hướng",
`XCTAssertTrue(router.operations.isEmpty)`. `KVRouterSpy` ghi đồng bộ nên nó chắc
chắn, không phải một cuộc đua với timeout.

Đừng `Task.sleep` để chờ state — dùng `waitForLoad()`.

## Xong thì verify, đừng báo xong

Chạy skill `ios-verify`: build + test + `check-arch.sh`, rồi chạy app thật xem
đúng màn đó. Test xanh không chứng minh màn hình hiện ra đúng.

## Dấu hiệu đang đi sai — dừng lại

- `import Data` trong file dưới `Features/`
- File ViewModel có `import KVRouterKit`, hoặc gọi `pushView`
- ViewModel có `URL`, `JSONDecoder`, `KVAPIClientError`
- View con nhận `ViewModel` thay vì value
- `Color(red:)` hoặc hex literal trong feature
- Field `isLoading` **và** `Loadable` cùng tồn tại — hai nguồn chân lý
- Đang viết `ViewEffect`/`AsyncStream` cho alert (alert là state)
