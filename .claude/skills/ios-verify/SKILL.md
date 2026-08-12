---
name: ios-verify
description: >-
  Kiểm chứng thay đổi trên app iOS này thật sự chạy: build, test, kiểm luật kiến
  trúc, rồi mở app trên simulator và screenshot đúng màn vừa sửa. Dùng skill này
  khi được yêu cầu build thử, chạy test, "chạy xem đúng chưa", "mở app lên xem",
  hoặc BẤT KỲ KHI NÀO vừa xong một feature hay một fix và cần nói là đã hoàn
  thành. Test xanh không chứng minh màn hình hiện ra đúng — đừng báo xong khi chưa
  chạy skill này.
---

# Verify

## Một lệnh cho ba việc

```bash
./tools/verify.sh
```

Nó chạy `check-arch.sh` → build → test, và fail sớm ở bước đầu tiên sai. Thứ tự
đó có lý: luật kiến trúc kiểm trong một giây, build mất một phút.

Chạy riêng khi cần khoanh vùng:

```bash
./tools/check-arch.sh
xcodegen generate                                   # sau khi thêm/di chuyển file
xcodebuild -quiet -scheme AppModules-Package \
  -destination 'generic/platform=iOS' build          # chỉ module, nhanh nhất
```

`xcodegen generate` là bước hay bị quên: file mới thêm vào `App/` sẽ không có
trong project cho tới khi generate lại. Module trong `Packages/AppModules` thì
không cần, SPM tự thấy.

## Rồi phải chạy thật

Test không chứng minh màn hình hiện ra đúng. Sau khi verify xanh:

1. **Mở panel trước khi build** — `control` action `attach`. Nó rẻ, mở ngay nếu
   simulator đang chạy, và báo lỗi vô hại nếu chưa có gì boot.
2. Build cho simulator:
   ```bash
   xcodebuild -quiet -project MyApp.xcodeproj -scheme MyApp \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -derivedDataPath /tmp/myapp-dd CODE_SIGNING_ALLOWED=NO build
   ```
3. `launch` với `app_path: /tmp/myapp-dd/Build/Products/Debug-iphonesimulator/MyApp.app`
4. `screenshot`, rồi `tap`/`text` để đi tới đúng màn vừa sửa và screenshot lại.

⚠️ **Toạ độ `tap` là device point, không phải pixel của ảnh screenshot.** Ảnh
iPhone 17 Pro trả về ~918×1900 px nhưng không gian toạ độ là 402×874 pt. Chia cho
~2.28 (ngang) và ~2.17 (dọc), hoặc đọc con số panel in ra khi attach. Tap bằng toạ
độ pixel sẽ rơi ra ngoài màn hình và trông y như "app không phản hồi".

## Chạy test một suite

```bash
xcodebuild -scheme AppModules-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FeatureOrderTests test
```

## Đọc kết quả cho đúng

- `check-arch.sh` fail → đọc thẳng vào luật bị vi phạm, đừng nới luật để đi tiếp.
- Test crash với `Assertion failed: API_BASE_URL missing` → test bundle không có
  Info.plist của app; `AppEnvironment` đã xử lý, nhưng nếu bạn thêm key mới thì
  phải xử lý tương tự.
- Build fail ở `conformance ... crosses into main actor-isolated code` → `View +
  Equatable` cần `nonisolated static func ==`.
- `Unable to find module dependency` cho một product `KV*` → thiếu khai trong
  `project.yml` (target App) hoặc `Package.swift` (module).

## Báo cáo

Nói rõ ba điều: lệnh nào đã chạy, kết quả thật (bao nhiêu test, pass/fail), và cái
gì **chưa** kiểm được. Nếu có bước bị bỏ, nói ra — đừng để im lặng ngụ ý là đã
kiểm.
