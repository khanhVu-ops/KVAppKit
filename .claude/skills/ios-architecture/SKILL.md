---
name: ios-architecture
description: >-
  Kiến trúc chuẩn của app iOS SwiftUI này (MVVM + Clean Architecture, iOS 16+,
  Swift 6): phân lớp Core/Domain/Data/DI/DesignSystem/Feature*, luật
  import, State + Action + send(), map lỗi về AppError, DI bằng KVDIKit, và các
  luật riêng cho iOS 16. Đọc skill này TRƯỚC KHI tạo hoặc sửa bất kỳ file Swift
  nào trong repo — kể cả việc nghe rất nhỏ như "thêm một hàm", "sửa ViewModel
  này", "đổi chỗ file". Bắt buộc dùng khi được hỏi code nên đặt ở tầng nào, file
  mới nằm đâu, "đúng clean architecture chưa", "tầng nào gọi tầng nào", hoặc khi
  thêm ViewModel, repository, use case, endpoint, DI key, entity, route, screen.
---

# Kiến trúc iOS — SwiftUI + MVVM + Clean Architecture

Nguyên tắc số một: **bắt chước màn hàng xóm, không phát minh.** Mở
`Features/Order/OrderList/` ra soi trước khi viết — nó là bản mẫu đã build và test
được. Skill này mô tả *vì sao*; repo thật mới là *cái gì*.

## Quyết định nhanh: file này đặt ở đâu?

Đi từ trên xuống, dừng ở câu trả lời đầu tiên là "có".

| Câu hỏi | Nếu có → |
|---|---|
| Là vocabulary chung, không phụ thuộc gì? (`Loadable`, `AppError`, `AlertState`) | `Core/` |
| Là khái niệm nghiệp vụ, không biết HTTP/JSON/SwiftUI? (entity, protocol repository, use case, port) | `Domain/` |
| Có biết wire format, endpoint, keychain, cache? (DTO, endpoint, repository impl, interceptor) | `Data/` |
| Là khai báo dependency key? | `DI/` (nơi **duy nhất**) |
| Là màu/font/spacing/component tái dùng? | `DesignSystem/` |
| Là màn hình hoặc state của màn hình? | `Features/<Tên>/` |
| Là dây nối mọi thứ lại — `@main`, `.kvRoutes`, middleware, bootstrap, session? | `App/` |

Không chắc giữa `Domain` và `Data`: hỏi "cái này có đổi khi backend đổi field
không?" Có → `Data`.

## Bốn luật, kèm lý do

Bốn luật này có trong `tools/check-arch.sh`; CI fail nếu vi phạm.

1. **`Domain` chỉ import Foundation.** Nó import SwiftUI hay KVNetworkit là lúc
   business rule mất khả năng test trong micro-giây và bắt đầu cần simulator.
2. **`KVAPIClientError` chết trong `Data`.** Repository map sang `AppError` (xem
   `Data/Mapping/AppError+Network.swift`). ViewModel switch trên status code sẽ
   vỡ ngày transport đổi.
3. **Feature không import `Data`.** Nó nói chuyện với *protocol* ở `Domain` — đó
   là thứ làm cho một màn test được bằng stub.
4. **View con nhận value, không nhận ViewModel.** Đây là luật hiệu năng, không
   phải luật thẩm mỹ — xem `references/ios16.md`.

## Khi luật chặn bạn

Hợp lệ: thêm method vào protocol ở `Domain`; mở một port mới; thêm một
`Loadable` field. Không hợp lệ: `import Data` trong feature, `@testable import`
để lách, force cast, hay bê type của `Data` sang `Domain` "cho nhanh".

Nếu một luật thật sự sai với việc bạn đang làm, nói ra và đề xuất sửa luật + sửa
`check-arch.sh` cùng lúc. Một luật không kiểm được sẽ thối trong ba tháng.

## Dấu hiệu đang đi sai — dừng lại nếu thấy

- `import Data` trong file dưới `Features/`
- ViewModel có `URL`, `JSONDecoder`, `KVAPIClientError`, hoặc `import KVRouterKit`
- View con nhận `@ObservedObject var viewModel:`
- `Color(red:...)` hoặc hex literal ngoài `DesignSystem`
- Hai nguồn chân lý: một field `isEmpty` được lưu **và** một computed `isEmpty`
- Một `ObservableObject` được nhiều màn cùng observe

## Đọc thêm khi cần

| Việc | File |
|---|---|
| Chi tiết từng module, được import gì, ví dụ file thật | `references/layers.md` |
| State/Action/send, `Loadable`, alert là state, test ViewModel | `references/state-action.md` |
| ViewModel đẩy route vs View đẩy view, khi nào cần route | `references/navigation.md` |
| KVDIKit key, `liveValue`/`testValue`, session layer, `prepare` | `references/di.md` |
| Bảng map `KVAPIClientError` → `AppError` → message | `references/errors.md` |
| **Luật riêng iOS 16** — chẻ view, Equatable, TextField, và diff khi lên 17 | `references/ios16.md` |
| Checklist review trước khi mở PR | `references/review-checklist.md` |
