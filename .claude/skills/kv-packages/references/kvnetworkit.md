# KVNetworkit 2.x

Chỉ `Data` được import. Lỗi bị map sang `AppError` tại repository.

## Endpoint

```swift
enum OrderEndpoint: KVAPIEndpointProtocol {
    case list
    case detail(id: String)

    var baseURL: String { AppEnvironment.current.apiBaseURL }
    var apiVersion: String { "/api/v1" }
    var path: String { ... }
    var method: KVHTTPMethod { ... }          // .get .post .put .patch .delete
    var body: KVHTTPBody? { try? .jsonEncoded(request) }
    var cachePolicy: KVCachePolicy { .cacheFirst(ttl: 60) }
}
```

Có default: `apiVersion` (rỗng), `headers`, `urlParams`, `body` (nil), `timeout`
(nil), `cachePolicy` (`.ignore`). `Content-Type` suy từ `body`.

`KVCachePolicy`: `.ignore` · `.cacheFirst(ttl:)` · `.networkFirst(ttl:)`.
Khai theo từng endpoint có ý thức — kết quả của một mutation không bao giờ được
từ cache.

## Client

```swift
KVAPIClient(
    session: KVNetworkSession(),                       // default
    interceptors: [ ... ],
    retryPolicy: .default,                             // default là .never
    cache: KVHybridCache()
)
```

Thứ tự interceptor **không tuỳ tiện**:

1. `KVNetworkAwareInterceptor()` — offline fail ngay, không chờ timeout
2. `KVAuthInterceptor(tokenProvider: { store.accessToken })` — header trước khi ai đó soi request
3. `TokenRefreshInterceptor(...)` — phản ứng với 401 mà header sinh ra
4. `KVLoggingInterceptor(level:output:)` — cuối, để in đúng request đã gửi

Cache: `KVMemoryCache` (RAM, LRU) · `KVDiskCache` · `KVHybridCache` (khuyến nghị).

## Gọi

```swift
let orders: [OrderDTO] = try await client.request(OrderEndpoint.list)
try await client.request(OrderEndpoint.cancel(id: id))            // chỉ cần thành/bại
try await client.request(endpoint, progressDelegate: progress)     // upload
client.cancelRequest(with: id)                                     // → .taskCanceled
```

Signature đầy đủ có `decoder:` và `id:`, cả hai đều có default.

## Lỗi

`KVAPIClientError`: `.invalidURL` `.unauthorized` `.refreshTokenInvalid`
`.statusCode(Int)` `.invalidResponse(Data)` `.decodingFailed(Error)`
`.networkError(URLError)` `.requestFailed(Error)` `.taskInProgress`
`.taskCanceled` `.serverMessage(message: String, statusCode: Int)` `.timeout`
`.networkUnavailable`

⚠️ `.serverMessage` có **label**. `isNetworkConnectivityError` là computed
property dùng để tách "mạng chết" khỏi "session chết" — đừng logout trên nó.

Message của server được tự trích từ `{"message":…}` `{"error":…}` `{"detail":…}`
`{"error":{"message":…}}` `{"errors":[…]}`.

Bảng map sang `AppError`: xem `ios-architecture/references/errors.md`.

## Token refresh

```swift
struct TokenRefreshInterceptor: KVTokenRefreshingInterceptorProtocol {
    let coordinator = KVTokenRefreshCoordinator()

    func refreshAction(response: URLResponse?, data: Data?) async throws -> KVInterceptorAction {
        guard (response as? HTTPURLResponse)?.statusCode == 401,
              let refresh = tokenStore.refreshToken else { return .proceed }
        try await coordinator.refresh { ... }
        return .retryWithUpdatedToken
    }
}
```

`KVTokenRefreshCoordinator` gộp: mười request 401 cùng lúc → **một** lần refresh.
Client retry tối đa **một** lần mỗi request, không có vòng lặp refresh.

Client dùng để refresh phải **không** có auth interceptor (token là thứ đang hỏng)
và **không** có refresh interceptor (sẽ đệ quy).

Throw `.refreshTokenInvalid` để báo logout. Nhưng nếu lỗi là
`isNetworkConnectivityError` thì rethrow nguyên — mạng chết không phải session
chết.

## Test

```swift
// Transport level — chạy cả pipeline thật (interceptor, retry, cache, decode)
let session = KVMockNetworkSession()
session.enqueue(.success((json, KVMockNetworkSession.httpResponse(url: url, statusCode: 200))))
let client = KVAPIClient(session: session, interceptors: [], retryPolicy: .never)

// Client level — nhanh hơn, nhưng không chứng minh pipeline
let mock = KVMockAPIClient()
mock.stub(path: "/orders", with: [OrderDTO(...)])
```

Dùng `KVMockNetworkSession` cho test repository: nó chứng minh app sống được với
cái server thật sự gửi, không chỉ chứng minh repository có gọi gì đó.

## Stream (SSE / NDJSON)

```swift
for try await delta in try await client.stream(ChatEndpoint.ask(text), as: ChatDelta.self) { ... }
try await client.streamEvents(endpoint, framing: .serverSentEventsPerLine)
try await client.streamLines(endpoint)      // khi chưa rõ server gửi gì
```

Framing: `.serverSentEvents` (mặc định) · `.serverSentEventsPerLine` ·
`.jsonLines`. Cache bị bỏ qua cho stream. Retry chỉ phủ lúc mở kết nối và response
head — một khi chunk đã chảy thì lỗi được đưa ra thay vì âm thầm restart.

## Network status trong SwiftUI

`KVNetworkStatusModel` (iOS 17+, `@Observable`) / `KVNetworkStatusObject` (iOS 16,
`ObservableObject`). Chọn theo version bằng `if #available`.
