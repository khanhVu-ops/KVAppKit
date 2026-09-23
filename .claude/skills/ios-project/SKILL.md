---
name: ios-project
description: >-
  Sửa cấu hình project của app iOS này (`<App>.xcodeproj`, commit trong git, không
  có XcodeGen): thêm configuration, thêm giá trị build-config mà code đọc được,
  thêm package SPM, thêm scheme, thêm entitlement/capability, đổi bundle id,
  marketing version hay deployment target. Dùng skill này khi được yêu cầu "thêm
  môi trường QA", "thêm biến vào Info.plist", "cài thêm thư viện", "bật push
  notification", "lên version 1.2", hoặc bất kỳ việc nào chạm build settings. Nó
  giữ cho `project.pbxproj` — file người trong team cùng sửa bằng Xcode — không bị
  một lần sửa tay làm hỏng.
---

# Sửa project

`<App>.xcodeproj` **là nguồn**, được commit, và team sửa nó bằng Xcode. Không có
XcodeGen, không có `project.yml`. Hai hệ quả:

- **File source không cần đụng tới project.** `<App>/` và `<App>Tests/` là
  synchronized folder (Xcode 16+): tạo, xoá, di chuyển file trong đó là target tự
  thấy. Luật 13 của `check-arch.sh` fail nếu ai đó "Convert to Group".
- **Mọi thứ khác là sửa `project.pbxproj`** — package, configuration, build setting,
  capability. Người làm trong Xcode; agent thì sửa text, nên phải cẩn thận hơn người.

## Agent sửa `project.pbxproj` thế nào

Ưu tiên theo thứ tự:

1. **Việc chỉ là một build setting có sẵn** (đổi giá trị, thêm key User-Defined vào
   các configuration đã có) → sửa text trực tiếp. Build setting nằm trong khối
   `XCBuildConfiguration` của **target app** (không phải của project — Xcode tab
   General sửa ở target, nên hai chỗ là hai giá trị lệch nhau).
2. **Việc tạo object mới** (package, configuration, scheme, file entitlements) →
   nói rõ bước bấm trong Xcode cho người làm, hoặc sửa text **chỉ khi** chép được
   đúng cấu trúc từ một object cùng loại đang có. Id là 24 ký tự hex, phải duy nhất.
3. **Sau mọi lần sửa tay:**

```bash
plutil -lint <App>.xcodeproj/project.pbxproj && ./tools/verify.sh
```

`plutil -lint` bắt lỗi cú pháp (thiếu `;`, ngoặc lệch) — thứ khiến Xcode từ chối mở
project mà không nói dòng nào. `verify.sh` bắt phần còn lại.

Đừng sắp xếp lại dòng trong một khối `buildSettings` bằng script: giá trị mảng trải
nhiều dòng (`LD_RUNPATH_SEARCH_PATHS = ( … );`) sẽ vỡ — đã xảy ra khi chuyển repo này.

## Năm việc hay gặp

| Việc | Sửa ở đâu |
|---|---|
| Thêm giá trị code đọc được | build setting của target (mọi configuration) → `Info.plist` → `AppEnvironment` |
| Thêm configuration (QA, Preprod…) | Xcode → Project → Info → Configurations (Duplicate) → scheme → fastlane |
| Thêm package SPM | Xcode → Package Dependencies → chọn **từng product** cho đúng target |
| Thêm entitlement/capability | Xcode → target → Signing & Capabilities |
| Lên version | Xcode → target → General → Version (`1.0` → `1.1`), rồi commit |

## Version và build number

- **`MARKETING_VERSION`**: dạng `1.0`, `1.1`, `1.2`. Sửa tay, commit. Chỉ nằm ở build
  settings của **target app**, và mọi configuration phải cùng số — Fastfile fail
  nếu lệch, vì một Release khác số với bản QA đã thử là một bản không ai thử.
- **`CURRENT_PROJECT_VERSION`**: **đừng sửa**. fastlane tự đặt lúc build qua `xcargs`
  (TestFlight mới nhất + 1 cho lane store, timestamp cho lane nội bộ) và không ghi lại
  vào project. Số `1` trong project chỉ là giá trị cho build local.

`Info.plist` tham chiếu `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`. Viết
cứng số vào plist là có hai nguồn — và fastlane chỉ đổi một.

## Giá trị build-config: một dây ba mắt

Đây là việc hay làm nhất và cũng là chỗ hay đứt nhất, vì ba chỗ phải khớp nhau mà
không chỗ nào biết chỗ nào:

```
// 1. project.pbxproj — build setting User-Defined, trong khối XCBuildConfiguration
//    của target app, ở CẢ BA configuration (Debug / Staging / Release)
FEATURE_FLAG_X = YES;
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
`Info.plist` và giữ nguyên build setting thì nó trả `nil` — mà build vẫn thành công,
test vẫn xanh, không một warning nào. Code lặng lẽ chạy nhánh mặc định, và thứ duy
nhất khác đi là một cờ không bao giờ bật ở Release.

`AppEnvironment+API.swift` assert ở Debug cho `API_BASE_URL` đúng vì lý do đó; cờ mới
mà quan trọng thì làm y như vậy.

**Đọc ở `AppEnvironment`, không đọc rải rác.** Một key thiếu thì hỏng một lần, lúc
launch, ầm ĩ — thay vì đẻ ra một request tới `https://` giữa giờ chạy.

## Thêm configuration

Ba configuration hiện có: `Debug`, `Staging` (dựa trên Release), `Release`. Thêm
một cái nữa là bốn chỗ, thiếu chỗ nào cũng không fail build:

1. Xcode → Project → Info → Configurations → **Duplicate** từ config gần nhất.
   Duplicate chứ đừng tạo trống: nó chép **mọi key** User-Defined. Thiếu
   `API_BASE_URL` ở config mới thì chỉ assert của `AppEnvironment+API` mới bắt, và
   chỉ khi ai đó chạy đúng config đó.
2. Sửa giá trị riêng của config đó (`API_BASE_URL`, `ENVIRONMENT_NAME`…).
3. Scheme: Product → Scheme → Manage Schemes → duplicate, đặt Run/Archive vào config
   mới, và tick **Shared** — scheme không shared nằm trong `xcuserdata/` (gitignore),
   CI và người khác không thấy.
4. `fastlane/Fastfile` — `STORE_CONFIGURATION` / `WEB_TEST_CONFIGURATION` là hằng
   số ở đầu file. Config mới mà muốn ship thì phải có lane trỏ vào.

## Thêm package

Xcode → Project → Package Dependencies → `+`. Hai chỗ hay sai:

- **Mỗi product là một lựa chọn riêng** trong hộp thoại "Add to Target". KVLoggingKit
  có sáu product; chọn thiếu `KVLoggingConsole` là "no such module", không phải
  "package chưa cài".
- **Target test có danh sách riêng** — nó không thừa hưởng product của app. Test cần
  `KVRouterTesting` / `KVNetworkit` thì thêm ở Build Phases → Link của `<App>Tests`.

Pin bằng "Up to Next Major" từ một version cụ thể. Đừng dùng branch — hai máy build
hai cây source khác nhau thì không ai tái lập được lỗi của ai. Commit cả
`project.xcworkspace/xcshareddata/swiftpm/Package.resolved`: đó là thứ khoá version
cho cả team và CI.

Symbol mới của package mà báo "không tìm thấy" sau khi bump version thì đó là
swiftmodule cũ trong DerivedData: xem `ios-troubleshoot`.

## Đừng đụng, trừ khi biết đang đổi gì

| Setting | Vì sao để yên |
|---|---|
| `SWIFT_EMIT_LOC_STRINGS = NO` | bật lên thì compiler tự bơm mọi literal vào bảng dịch, làm bẩn đúng file `check-l10n.sh` vừa kiểm sạch — `verify.sh` đỏ ngay sau một build thành công |
| `IPHONEOS_DEPLOYMENT_TARGET = 16.0` | không phải một setting mà là một quyết định kiến trúc (`ObservableObject` vs `@Observable`) — xem `ios-architecture/references/ios16.md` |
| `SWIFT_STRICT_CONCURRENCY = complete` | hạ xuống là đổi lỗi Sendable từ lỗi build thành crash lúc tải cao |
| `ENABLE_TESTABILITY` ở Staging/Release | `@testable` chỉ cần ở Debug; bật khi ship là bỏ mất tối ưu |
| `CURRENT_PROJECT_VERSION` | fastlane quyết định lúc build; sửa tay không có tác dụng với bản lên store |

## Entitlement và capability

Base không có file entitlements. Thêm bằng Xcode → target → Signing & Capabilities →
`+ Capability`: Xcode tạo file `.entitlements`, trỏ `CODE_SIGN_ENTITLEMENTS` vào nó.
Kéo file đó vào `<App>/App/Resources/` để nó nằm trong folder source cùng mọi thứ
khác.

Capability nào cần provisioning profile riêng thì phải bật trên Developer Portal —
`CODE_SIGN_STYLE = Automatic` lo phần ký, không lo phần đăng ký. Lane fastlane ký
manual bằng profile trong `signing.properties`, nên profile đó cũng phải có
capability mới.

Keychain trên **simulator** trả `-34018` (`errSecMissingEntitlement`) kể cả khi
entitlement đúng, vì build simulator không ký. Đó là bình thường, không phải thứ
để đi sửa entitlements — report status, đừng trap.

## Xong thì

```bash
plutil -lint <App>.xcodeproj/project.pbxproj && ./tools/verify.sh
```

Thêm folder tầng mới trong `<App>/` thì không phải đụng project — nhưng luật 10 của
`check-arch.sh` so danh sách folder trong README với đĩa, nên README phải được sửa
trong cùng lần đó.
