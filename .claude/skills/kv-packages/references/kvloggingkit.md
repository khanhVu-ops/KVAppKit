# KVLoggingKit 1.1

## Product

| Product | Dùng khi |
|---|---|
| `KVLoggingKit` | luôn — `LogClient`, `ScopedLogClient`, `LogValue`, processor |
| `KVLoggingLocal` | file rolling có mã hoá + unified log |
| `KVLoggingSecurity` | AES-GCM + key trong Keychain |
| `KVLoggingSwiftUI` | `.kvLogging(_:)` — inject + flush khi vào background |
| `KVLoggingNetwork` | capture request/response cho console |
| `KVLoggingConsole` | console trên máy, lắc để mở (DEBUG) |
| `KVLoggingRemote` | HTTP transport + batch + offline queue |
| `KVLoggingTesting` | `InMemoryLogDestination` để assert log |

## Ghi log

```swift
logger.debug("...") / .info / .notice / .warning / .error(_, error:) / .critical
```

Call là đồng bộ và không block caller trên I/O.

## Privacy — phần dễ làm sai nhất

```swift
logger.info("Đăng nhập thành công", metadata: ["email": .private(email)])
```

- `.public` được gửi tới mọi destination.
- `.private` tới được file mã hoá local, vào unified log dưới dạng private data, và
  thành `<redacted>` trước khi gửi remote.
- **Message string không được bảo vệ như metadata.** Khai một field là private
  chẳng có tác dụng gì nếu cùng giá trị đó bị nội suy vào câu message. Đừng làm
  `logger.info("email=\(email)")`.
- Đừng đưa password, access token, hay raw body vào logger.

`PrivacyProcessor.strict(allowedMetadataKeys:)` **drop** mọi key ngoài allowlist.
Nó tự union key của `DeviceContextProcessor` nên device context không bị mất, và
phải chạy **sau** những processor mà key của chúng cần giữ.

Thêm key metadata mới mà muốn nó tồn tại → thêm vào allowlist trong
`AppBootstrap`. Đó là một quyết định privacy, nên nó ở một chỗ.

## Scoped logger

Mỗi repository/ViewModel một category, context tự đi kèm:

```swift
private let logger: ScopedLogClient        // logger.scoped(category: "order")
logger.error("Không thể tải đơn", error: mapped)
```

`ScopedLogClient.error(_ message:metadata:error:file:function:line:)` — chú ý
label `error:` cho error object.

`LogClient.scoped(category:metadata:)`. Fallback an toàn: `LogClient.disabled` —
một logger chạy được, drop mọi thứ.

## SwiftUI

```swift
.kvLogging(logger)         // inject + flush khi scene vào background
@Environment(\.logClient) private var logger
```

## Network capture

| | `NetworkLoggingDelegate` | `NetworkLoggingURLProtocol` |
|---|---|---|
| Body request/response | chỉ delegate-based data task | có |
| Hiện request đang bay | không, ghi lúc xong | có |
| Background session | có | không |
| Dùng cho release | được | **chỉ DEBUG** |

```swift
#if DEBUG
NetworkLoggingURLProtocol.settings = .init(
    recorder: NetworkLogRecorder(logger: logger),
    shouldCapture: { $0.url?.host != "logs.example.com" }   // tránh log sinh ra log
)
NetworkLoggingURLProtocol.installGlobally(swizzlingSessionConfigurations: true)
#endif
```

`swizzlingSessionConfigurations: true` **đã sửa ở 1.1.0** và đo lại trên iOS
26.2: bật cờ rồi bắn request qua session tự dựng configuration thì không crash,
và traffic của session đó vào console thật. Bản 1.0.0 thì crash — nó exchange
getter `protocolClasses` toàn process bằng một `@objc` method của Swift, mảng
trả về hỏng, và CFNetwork gọi `+canInitWithTask:` lên chính class configuration.

Vẫn nên mặc định `install(in:)` trên configuration của chính app: nó hẹp hơn một
lần exchange toàn process, và đây là đường package tự mô tả là "the explicit,
swizzle-free way".

```swift
let configuration = URLSessionConfiguration.default
#if DEBUG
NetworkLoggingURLProtocol.install(in: configuration)
#endif
KVAPIClient(session: KVNetworkSession(configuration: configuration), …)
```

Bật cờ swizzle khi cần console **thấy cả session app không tự dựng** — ảnh
Kingfisher, SDK bên thứ ba. Đó là thứ duy nhất nó mua thêm.

`installGlobally()` **không kèm swizzle** vẫn an toàn — nó chỉ
`URLProtocol.registerClass`, phủ `URLSession.shared`.

Release mà vẫn muốn timing/status: `URLSession.networkLogging(configuration:recorder:delegate:)`
với `NetworkLogRecorder(redactor: .headersAndBodiesOff, logger:)`.

Header và body ở lại `NetworkLogStore` — một ring trong RAM, không xuống disk. Mỗi
exchange xong chỉ emit một `LogEvent` category `network` mang method, host, path,
status, duration, byte count.

## Console

`KVLoggingConsole` (iOS 16+): lắc máy để mở, xem log + API call, export cURL.
Gate bằng `DebugAccessPolicy`, **đừng ship vào production build**.

## Test

`InMemoryLogDestination` từ `KVLoggingTesting` để assert event đã emit. Trong test
ViewModel/repository thường chỉ cần `LogClient.disabled.scoped(category: "test")`.
