# Lỗi

## Một loại lỗi qua biên

`AppError` là loại **duy nhất** đi qua biên tầng. `KVAPIClientError`,
`DecodingError`, `URLError` bị map ở rìa `Data` và không đi xa hơn.

Chốt chặn: `Data/Mapping/AppError+Network.swift`.

| `KVAPIClientError` | `AppError` | Vì sao |
|---|---|---|
| `.taskCanceled` | `.cancelled` | Không phải lỗi. Hiện gì cũng là nhiễu |
| `.unauthorized`, `.refreshTokenInvalid` | `.unauthorized` | `SessionController` lo, tập trung một chỗ |
| `.serverMessage(message:statusCode:)` | `.server(message:code:)` | Server viết cho user này, về request này — hiện nguyên văn |
| `.decodingFailed`, `.invalidResponse` | `.decoding` | Backend đổi shape. User không làm gì được; chi tiết vào log |
| `.networkUnavailable`, `.timeout` | `.offline` | Đáng retry, **không bao giờ** đáng logout |
| còn lại | `.offline` nếu `isNetworkConnectivityError`, ngược lại `.unknown` | Mạng chết không phải session chết |

## Repository map ở một chỗ

```swift
private func perform<T>(_ description: String, _ work: () async throws -> T) async throws -> T {
    do { return try await work() }
    catch {
        let mapped = AppError(networkError: error)
        if mapped != .cancelled { logger.error("Không thể \(description)", error: mapped) }
        throw mapped
    }
}
```

Một chỗ map và log, nên không call site nào quên được cả hai — quên là cách một
`KVAPIClientError` thô lọt vào ViewModel.

## `userMessage` sống ở `AppError`

Để mọi màn diễn đạt cùng một thất bại theo cùng một cách. `.cancelled` có
`userMessage` rỗng có chủ ý, và `ToastService.error(_ error: AppError)` bỏ qua
message rỗng — nên `toast.error(.cancelled)` hiện *không gì cả* thay vì một viên
thuốc trắng.

`isRetryable` quyết định có hiện nút Thử lại: 5xx và offline thì có, 4xx và
decoding thì không (bấm lại cũng thế).

## Không logout vì mạng yếu

`TokenRefreshInterceptor` throw nguyên `KVAPIClientError` khi
`isNetworkConnectivityError`, chứ không đổi thành `.refreshTokenInvalid`. Một
người bước vào thang máy không nên bị đăng xuất.
