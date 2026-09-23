---
name: ios-project
description: >-
  Sửa cấu hình project của app iOS này qua `project.yml` (XcodeGen): thêm
  configuration, thêm giá trị build-config mà code đọc được, thêm package SPM,
  thêm scheme, thêm entitlement/capability, thêm folder nguồn, đổi bundle id hay
  version. Dùng skill này khi được yêu cầu "thêm môi trường QA", "thêm biến vào
  Info.plist", "cài thêm thư viện", "bật push notification", "đổi deployment
  target", hoặc bất kỳ việc nào mà bản năng đầu tiên là mở Xcode ra bấm. KHÔNG
  bao giờ sửa `.xcodeproj` — nó được sinh ra và đã gitignore, nên mọi thay đổi bấm
  trong Xcode sẽ biến mất ở lần `xcodegen generate` kế tiếp mà không báo gì.
---

# Sửa project.yml

`MyApp.xcodeproj` là **sản phẩm**, không phải nguồn: nó được `xcodegen` sinh ra từ
`project.yml` và đã nằm trong `.gitignore`. Sửa trong Xcode thì thay đổi sống đến
lần generate kế tiếp rồi biến mất — không có conflict, không có cảnh báo, chỉ là
một buổi chiều bấm lại.

**Sau mọi lần sửa `project.yml`:**

```bash
xcodegen generate && ./tools/verify.sh
```

Hook `PostToolUse` chỉ generate khi có file `.swift` **mới** — nó không nhìn
`project.yml`. Đây là chỗ duy nhất phải tự chạy.

## Năm việc hay gặp

| Việc | Sửa ở đâu |
|---|---|
| Thêm giá trị code đọc được | `settings.configs` → `Info.plist` → `AppEnvironment` |
| Thêm configuration (QA, Preprod…) | `configs:` → `settings.configs` của target → `schemes:` → fastlane |
| Thêm package SPM | `packages:` → **một dòng cho mỗi product** ở `dependencies` |
| Thêm entitlement/capability | file `.entitlements` → `CODE_SIGN_ENTITLEMENTS` |
| Thêm folder tầng mới | tạo trong `MyApp/` (đã nằm trong `sources:`) → README (luật 10) → cân nhắc luật mới trong `check-arch.sh` |

## Giá trị build-config: một dây ba mắt

Đây là việc hay làm nhất và cũng là chỗ hay đứt nhất, vì ba chỗ phải khớp nhau mà
không chỗ nào biết chỗ nào:

```yaml
# 1. project.yml — giá trị, theo từng configuration
targets:
  MyApp:
    settings:
      configs:
        Debug:   { FEATURE_FLAG_X: "YES" }
        Staging: { FEATURE_FLAG_X: "YES" }
        Release: { FEATURE_FLAG_X: "NO" }
```

```xml
<!-- 2. App/Resources/Info.plist — đường cho giá trị đi từ build sang bundle -->
<key>FEATURE_FLAG_X</key>
<string>$(FEATURE_FLAG_X)</string>
```

```swift
// 3. Core/AppEnvironment.swift — nơi duy nhất đọc
//    (key chỉ app có backend mới cần — như API_BASE_URL — đọc ở
//    Data/Network/AppEnvironment+API.swift, để app tool xoá Data/ là mất theo)
let flagX = Bundle.main.object(forInfoDictionaryKey: "FEATURE_FLAG_X") as? String == "YES"
```

**Quên mắt số 2 là lỗi im lặng — đã đo, không phải suy:** thêm key vào cả ba chỗ
thì `Bundle.main.object(...)` trả `Optional("YES")`; bỏ đúng hai dòng trong
`Info.plist` và giữ nguyên `project.yml` thì nó trả `nil` — mà build vẫn thành
công, test vẫn xanh, không một warning nào. Code lặng lẽ chạy nhánh mặc định, và
thứ duy nhất khác đi là một cờ không bao giờ bật ở Release.

`AppEnvironment+API.swift` assert ở Debug cho `API_BASE_URL` đúng vì lý do đó; cờ mới mà
quan trọng thì làm y như vậy.

**Đọc ở `AppEnvironment`, không đọc rải rác.** Một key thiếu thì hỏng một lần, lúc
launch, ầm ĩ — thay vì đẻ ra một request tới `https://` giữa giờ chạy.

## Thêm configuration

Ba configuration hiện có: `Debug` (debug), `Staging` (release), `Release`
(release). Thêm một cái nữa là bốn chỗ, thiếu chỗ nào cũng không fail build:

1. `configs:` ở đầu file — khai tên và nó dựa trên debug hay release.
2. `settings.configs.<Tên>` trong target — **mọi key** mà các config khác có.
   Thiếu `API_BASE_URL` ở đây thì assert của `AppEnvironment+API` mới bắt, và chỉ khi
   ai đó chạy đúng config đó.
3. `schemes:` — không có scheme thì không chọn được trong Xcode lẫn `xcodebuild`.
4. `fastlane/Fastfile` — `STORE_CONFIGURATION` / `WEB_TEST_CONFIGURATION` là hằng
   số ở đầu file. Config mới mà muốn ship thì phải có lane trỏ vào, nếu không nó
   chỉ là một dòng yaml.

## Thêm package

Một package có thể có nhiều product, và **mỗi product cần một dòng riêng**:

```yaml
packages:
  KVLoggingKit:
    url: https://github.com/khanhVu-ops/KVLoggingKit.git
    from: 1.1.0

targets:
  MyApp:
    dependencies:
      - package: KVLoggingKit
        product: KVLoggingKit
      - package: KVLoggingKit
        product: KVLoggingConsole     # thiếu dòng này = "no such module"
```

Target test có danh sách `dependencies` **riêng** — nó không thừa hưởng của app.
Symbol mới của package mà báo "không tìm thấy" sau khi bump version thì đó là
swiftmodule cũ trong DerivedData, không phải project.yml: xem `ios-troubleshoot`.

Pin bằng `from:` (semver). Đừng dùng `branch:` — hai máy build hai cây source khác
nhau thì không ai tái lập được lỗi của ai.

## Đừng đụng, trừ khi biết đang đổi gì

| Setting | Vì sao để yên |
|---|---|
| `SWIFT_EMIT_LOC_STRINGS: "NO"` | bật lên thì compiler tự bơm mọi literal vào bảng dịch, làm bẩn đúng file `check-l10n.sh` vừa kiểm sạch — `verify.sh` đỏ ngay sau một build thành công |
| `deploymentTarget iOS 16.0` | không phải một dòng yaml mà là một quyết định kiến trúc (`ObservableObject` vs `@Observable`) — xem `ios-architecture/references/ios16.md` |
| `SWIFT_STRICT_CONCURRENCY: complete` | hạ xuống là đổi lỗi Sendable từ lỗi build thành crash lúc tải cao |
| `ENABLE_TESTABILITY` ở Staging/Release | `@testable` chỉ cần ở Debug; bật khi ship là bỏ mất tối ưu |

## Entitlement và capability

Base không có file entitlements. Thêm một cái:

1. Tạo file `<Tên app>.entitlements` trong `App/Resources/`.
2. Trỏ `settings.base.CODE_SIGN_ENTITLEMENTS` vào đúng đường dẫn đó.
3. Capability nào cần provisioning profile riêng thì phải bật trên Developer
   Portal — `CODE_SIGN_STYLE: Automatic` lo phần ký, không lo phần đăng ký.

Keychain trên **simulator** trả `-34018` (`errSecMissingEntitlement`) kể cả khi
entitlement đúng, vì build simulator không ký. Đó là bình thường, không phải thứ
để đi sửa entitlements — report status, đừng trap.

## Xong thì

```bash
xcodegen generate && ./tools/verify.sh
```

Thêm folder tầng mới thì luật 10 của `check-arch.sh` so danh sách folder trong
README với đĩa — README phải được sửa trong cùng lần đó, không phải "để sau".
