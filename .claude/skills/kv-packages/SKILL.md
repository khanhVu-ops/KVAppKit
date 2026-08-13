---
name: kv-packages
description: >-
  API đúng và các bẫy đã kiểm chứng của 5 package nội bộ: KVRouterKit 3.2 (điều
  hướng + transition), KVDIKit (dependency injection), KVNetworkit 2.x
  (networking async/await), KVToastKit (toast), KVLoggingKit (log + network
  console). Dùng skill này NGAY khi code chạm tới bất kỳ symbol bắt đầu bằng KV,
  khi push/pop màn hình, gọi API, khai dependency, hiện toast hay ghi log trong
  app iOS này. ĐỪNG đoán API của các package này từ trí nhớ — chúng là package
  riêng, không có trong training data, KVRouterKit đã đổi tên module ở v2 và đổi
  hẳn mô hình route ở v3, nên code nhìn đúng mà không compile là kết quả thường
  gặp nhất.
---

# 5 package nội bộ

## Sai nhiều nhất — đọc trước

| Sai | Đúng | Vì sao |
|---|---|---|
| `import KVRouter` | `import KVRouterKit` (View) / `KVRouterCore` (ViewModel) | v2.0 đổi tên module |
| `router.push(.appFeature("profile"))` | `router.push(OrderRoute.detail(id: id))` | v3.0 bỏ `KVAppRoute`; route là type của app |
| `router.appFeatureViewBuilder = { ... }` | `.kvRoutes { $0.register(R.self) { ... } }` | v3.0 bỏ builder stringly-typed |
| `router.presentSheet { ... }` | SwiftUI `.sheet` / `.fullScreenCover` | v3.0 bỏ modal khỏi router hẳn |
| `router.handle(url:)` | app tự parse rồi `setPath(...)` | v3.0 bỏ deep link khỏi router |
| ViewModel gọi `pushView` | `pushView` ở `KVViewRouting` (View) | VM chỉ thấy `KVRouting` |
| poll `router.path` trong test | `await router.settle()`, hoặc `KVRouterSpy` | v3.0 thêm `settle()` |
| `KVAPIClientError.serverMessage(m, code)` | `.serverMessage(message:statusCode:)` | label bắt buộc |
| `logger.info("token=\(t)")` | `metadata: ["k": .private(t)]` | message string không được redact như metadata |
| `installGlobally(swizzlingSessionConfigurations: true)` | `install(in: configuration)` | swizzle `protocolClasses` crash trên iOS 26 |
| capture `var` trong `ToastService {}` | `ToastRecorder` | `post` là `@Sendable`, Swift 6 chặn |

## Version đang dùng

| Package | Version | Module import |
|---|---|---|
| KVRouter | 3.2.1 | `KVRouterKit` · `KVRouterCore` · `KVRouterTesting` |
| KVNetworkit | 2.0.0 | `KVNetworkit` |
| KVDIKit | 1.0.0 | `KVDIKit` |
| KVToastKit | 1.0.0 | `KVToastKit` |
| KVLoggingKit | 1.0.0 | `KVLoggingKit` + `KVLogging{Local,Security,Network,SwiftUI,Console}` |

Nếu `Package.resolved` khác bảng này, tin `Package.resolved` và đọc source trong
`.build/checkouts/` — đừng tin file này.

## Đọc gì khi làm gì

| Việc | File |
|---|---|
| push/pop, route, transition, hero zoom, middleware, restoration, test router | `references/kvrouterkit.md` |
| khai key, `liveValue`/`testValue`, session layer, `prepare`, override trong test | `references/kvdikit.md` |
| endpoint, client, interceptor, cache, token refresh, stream, mock session | `references/kvnetworkit.md` |
| toast center riêng, style, `.overlay` vs `.window`, test | `references/kvtoastkit.md` |
| log có privacy, scoped logger, network capture, console lắc máy | `references/kvloggingkit.md` |

## Khi reference lệch source

Reference là bản chép đã kiểm chứng, không phải nguồn chân lý. Nghi ngờ thì
`grep` trong `.build/checkouts/<package>/Sources/` — và sửa lại file reference
cùng lúc, đừng để lệch lần thứ hai.
