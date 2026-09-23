---
name: ios-endpoint
description: >-
  Thêm hoặc sửa MỘT endpoint API trên app iOS này, đi hết đường: DTO → case
  endpoint (path, method, cachePolicy) → method trong repository protocol →
  implementation map lỗi → stub → test qua `KVMockNetworkSession`. Dùng skill này
  khi được yêu cầu gọi thêm một API, "thêm endpoint", "app cần lấy thêm dữ liệu X",
  hoặc khi backend đổi shape của một response đã dùng. Cho một feature trọn vẹn
  nhiều tầng thì dùng `ios-feature`; skill này là một lát mỏng trong `Data`.
---

# Thêm một endpoint

Cả việc này nằm trong `Data` + một dòng ở `Domain`. Nếu bạn thấy mình sửa file dưới
`Features/`, dừng lại: đó là `ios-feature`, không phải skill này.

Mở `Data/Network/Endpoints/OrderEndpoint.swift` và
`Data/Repositories/OrderRepository.swift` ra soi trước khi viết — chúng là bản mẫu
đã chạy và test được.

## Sáu bước

| # | Bước | Ở đâu |
|---|---|---|
| 1 | DTO + `toDomain()` | `Data/DTO/` |
| 2 | Case trong enum endpoint | `Data/Network/Endpoints/` |
| 3 | Method trong protocol | `Domain/Repositories/` |
| 4 | Implementation, gọi qua `perform(_:_:)` | `Data/Repositories/` |
| 5 | Stub tương ứng | `Data/Testing/` |
| 6 | Test qua `KVMockNetworkSession` | `Tests/DataTests/` |

Thứ tự này không tuỳ tiện: bước 3 là chỗ duy nhất `Domain` biết có việc mới, và nó
phải mô tả *cái gì* chứ không phải *bằng gì*. Không có `URL`, `statusCode`, `Data`
nào xuất hiện trong signature ở `Domain`.

## Bước 1: DTO — optional là mặc định

```swift
struct OrderDTO: Decodable {
    let id: String          // chỉ non-optional khi thiếu nó thì record vô nghĩa
    let code: String?
    let total: Decimal?

    func toDomain() -> Order {
        Order(id: id, code: code ?? id, total: total ?? 0)
    }
}
```

Backend bỏ field là chuyện thường. DTO khai non-optional biến một thiếu sót vô hại
thành **màn hình rỗng** — đây là nguồn crash decode số một. `toDomain()` là nơi
optional biến thành default hợp lý, và cũng là nơi `nil` chết, không leo lên tầng
trên.

## Bước 2: endpoint — `cachePolicy` là quyết định, không phải mặc định

```swift
var cachePolicy: KVCachePolicy {
    switch self {
    case .list(let forceRefresh): return forceRefresh ? .ignore : .cacheFirst(ttl: 60)
    case .detail:                 return .cacheFirst(ttl: 30)
    case .cancel:                 return .ignore
    }
}
```

⚠️ **KVNetworkit đọc `cachePolicy` chỉ từ endpoint** — `client.request(_:)` không có
tham số override. Nên "lần này bỏ qua cache" **phải** là một phần của endpoint, như
`case list(forceRefresh: Bool)` ở trên. Bản đầu của repo này có `forceRefresh` ở
repository mà endpoint thì cố định `.cacheFirst(ttl: 60)`: cờ đó không làm gì trong
nhiều tháng, pull-to-refresh trả lại đúng bản cache cũ, và không test nào đỏ.

Ghi mọi thứ ghi (POST/PUT/DELETE) là `.ignore`. Một lệnh huỷ đơn trả về từ cache là
một lệnh chưa xảy ra.

## Bước 4: implementation — đi qua `perform`

```swift
func detail(id: String) async throws -> Order {
    try await perform("load order \(id)") {
        let dto: OrderDTO = try await client.request(OrderEndpoint.detail(id: id))
        return dto.toDomain()
    }
}
```

`perform` là chỗ duy nhất map lỗi và log, nên không call site nào quên được cả hai.
Quên nó là cách một `KVAPIClientError` thô đi tới ViewModel — vi phạm luật 2, và
`check-arch.sh` sẽ bắt, nhưng chỉ khi type đó xuất hiện trong signature.

Kiểu trả về của `request` được suy từ chỗ khai `let dto:` — khai sai kiểu thì lỗi là
decoding lúc runtime, không phải lúc compile. Viết `let dto: [OrderDTO]` cho list,
`let dto: OrderDTO` cho một record.

## Bước 6: test — ba case, không phải một

```swift
private let url = URL(string: "https://api.test.local/api/v1/orders")!

let session = KVMockNetworkSession()
session.enqueue(.success((json, KVMockNetworkSession.httpResponse(url: url, statusCode: 200))))
let repo = OrderRepository(
    client: KVAPIClient(session: session, interceptors: [], retryPolicy: .never),
    logger: LogClient.disabled.scoped(category: "test")
)
```

Stub ở tầng **transport**, không mock client: như vậy test chạy pipeline thật —
interceptor, retry, decode, map lỗi. Mock client chỉ chứng minh repository có gọi
một cái gì đó.

Ba case tối thiểu:

1. **Happy** — decode đúng, map sang domain đúng.
2. **Thiếu field optional** — không throw, ra default.
3. **Lỗi server** (4xx/5xx) — throw ra `AppError` đúng loại, không phải
   `KVAPIClientError`.

Thêm case thứ tư nếu endpoint có cờ ảnh hưởng cache: assert thẳng `cachePolicy`, như
`test_forceRefresh_bypassesCache`. Nó rẻ và nó canh đúng chỗ đã từng nối sai.

## Xong thì

`./tools/verify.sh`. File mới trong folder source tự vào target (synchronized folder),
không cần đụng project.

Và cập nhật `docs/API_INVENTORY.md` nếu repo có — một endpoint tồn tại mà inventory
không biết là inventory bắt đầu vô dụng.
