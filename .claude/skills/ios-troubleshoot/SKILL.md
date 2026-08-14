---
name: ios-troubleshoot
description: >-
  Triệu chứng → nguyên nhân → cách xử cho những lỗi đã gặp thật trên app iOS này:
  build fail, "cannot find X in scope" dù code có đó, test crash trước khi chạy,
  symbol mới của package "không tìm thấy", app crash ở request đầu tiên, keychain
  trả -34018, row trong List bấm không ăn, os_log không thấy gì, toạ độ tap trên
  simulator lệch, `grep | exit 1` không bao giờ fire. Dùng skill này NGAY khi một
  lệnh build/test/chạy app thất bại hoặc cư xử lạ, TRƯỚC KHI đoán nguyên nhân hay
  đổi code — phần lớn những lỗi này trông như lỗi code nhưng là lỗi môi trường,
  cache, hoặc project file, và đã tốn hàng giờ để biết một lần.
---

# Gỡ lỗi: những cái đã trả giá để biết

Mỗi dòng dưới đây đã xảy ra thật trong repo này. Đọc trước khi sửa code — sửa code
cho một lỗi hạ tầng là cách nhanh nhất để tạo ra một bug thật.

## Quy tắc chung: đọc lỗi, đừng đoán

Ba câu hỏi, theo thứ tự:

1. **Lệnh nào?** Copy nguyên lệnh và exit code, đừng kể lại.
2. **Lỗi đầu tiên hay lỗi cuối?** Xcode in lỗi phái sinh sau lỗi gốc. Cuộn **lên**.
3. **Nó có phải lỗi của code không?** Nếu cùng cây source vừa xanh cách đây năm phút,
   nghi hạ tầng trước.

## Build

| Triệu chứng | Nguyên nhân | Xử |
|---|---|---|
| "cannot find X in scope" mà file có trên đĩa | file mới chưa vào project — một app target không tự phát hiện | `xcodegen generate`. Hook `PostToolUse` lo file mới; **di chuyển/xoá thì phải tự chạy** |
| Symbol mới của package `KV*` "không tìm thấy" ngay sau khi bump version | swiftmodule cũ trong DerivedData | xoá DerivedData **rồi** mới tin thông báo lỗi |
| `Unable to find module dependency` cho một product `KV*` | chưa khai product trong `dependencies` của target | thêm vào `project.yml` rồi `xcodegen generate` |
| `conformance ... crosses into main actor-isolated code` | `View + Equatable` mà `==` bị suy ra là `@MainActor` | `nonisolated static func ==` |
| Build chậm bất thường, SPM resolve lại từ đầu | vừa xoá DerivedData vô cớ | đừng xoá theo phản xạ; chỉ xoá khi thật sự nghi cache bẩn |

## Test

| Triệu chứng | Nguyên nhân | Xử |
|---|---|---|
| `Early unexpected exit` / `crashed with signal kill before establishing connection` | simulator chưa boot xong, chưa phải lỗi code | `verify.sh` đã boot trước + retry một lần. Chạy tay thì `xcrun simctl bootstatus <udid> -b` |
| `Assertion failed: API_BASE_URL missing` khi chạy test | test bundle không có Info.plist của app | `AppEnvironment` đã xử; thêm key mới thì phải xử tương tự |
| Test không link được symbol của app | test bundle không host | `TEST_HOST` phải trỏ app; `App.init` bỏ bootstrap khi `AppEnvironment.isRunningTests` |
| Test treo rồi timeout khi chờ state | đang `Task.sleep` để chờ | `waitForLoad()`, hoặc spy đồng bộ như `KVRouterSpy` |

## Chạy app

| Triệu chứng | Nguyên nhân | Xử |
|---|---|---|
| Crash ở **request đầu tiên**, `+[NSURLSessionConfiguration canInitWithTask:]: unrecognized selector` | KVLoggingKit **dưới 1.1.0** đang swizzle getter `protocolClasses` — do `installGlobally(swizzlingSessionConfigurations: true)`, **hoặc** `LogConsole.install()` trần vì scope mặc định `.allSessions` cũng bật swizzle | lên **1.1.0** (đã sửa, đo trên iOS 26.2 và 18.6). Còn kẹt bản cũ: tắt cờ, đặt `LogConsole` capture scope hẹp lại, và dùng `install(in: configuration)` trên configuration của client mình; `installGlobally()` không cờ vẫn an toàn |
| Gỡ app rồi cài lại mà vẫn **đang đăng nhập**, không về được màn login | Keychain **không** nằm trong container của app nên iOS giữ lại khi gỡ; `SessionController` seed `isSignedIn` từ token của lần cài trước | `AppBootstrap.clearTokensOnFirstLaunch` — cờ trong `UserDefaults` (thứ **có** bị xoá cùng app) đánh dấu lần chạy đầu của bản cài mới. Phải chạy **trước** khi dựng `SessionController` |
| Crash lúc đăng nhập trên simulator, keychain `-34018` | build simulator không ký thì `errSecMissingEntitlement` là **bình thường** | report status, đừng trap. Bản đầu trap và crash |
| Row trong `List` bấm không ăn | `.buttonStyle(.plain)` bỏ vùng chạm cả-ô | `.contentShape(Rectangle())` |
| Đăng nhập rồi mà mọi push vẫn bị đẩy về sign-in | hai nguồn chân lý cho "đã đăng nhập" | `SessionController` là câu trả lời duy nhất; middleware hỏi nó |
| Toast/alert in nguyên văn chuỗi hệ thống ("Không thể tìm thấy máy chủ...") | `AppError.unknown` mang `localizedDescription` ra UI | `userMessage` chung chung, chi tiết vào `diagnostic` |
| Kéo-xuống-refresh mà dữ liệu không đổi | `cachePolicy` chỉ đọc từ endpoint; `request` **không** có tham số override | cờ `forceRefresh` phải là case của endpoint và đổi policy — xem `OrderEndpoint.list(forceRefresh:)` |

## Quan sát

| Triệu chứng | Nguyên nhân | Xử |
|---|---|---|
| `log show` không thấy log của app | os_log mức info/debug bị lọc mặc định | `log show --info --debug`, nếu không sẽ tưởng code không chạy |
| Tap trên simulator "không phản hồi" | toạ độ tap là **device point**, không phải pixel ảnh screenshot | iPhone 17 Pro: ảnh ~918×1900 px, toạ độ 402×874 pt. Chia ~2.28 ngang, ~2.17 dọc |
| Log/metadata nhạy cảm không bị redact | dữ liệu nội suy vào message string | `metadata: ["k": .private(v)]`; message không được redact |

## Script và git

| Triệu chứng | Nguyên nhân | Xử |
|---|---|---|
| `cmd \| grep error: && exit 1` không bao giờ fire | dưới `set -o pipefail`, exit code của pipe là của `cmd` | kiểm exit code tường minh, xem `run_xcodebuild` trong `tools/verify.sh` |
| `git checkout <file>` để undo một thí nghiệm → mất sạch | index có thể còn nội dung **trước** một lần sửa hàng loạt | backup bằng `cp` trước khi thí nghiệm |
| File có trên đĩa, `git add -A` xong vẫn không thấy trong commit | `~/.gitignore_global` ăn mất (đã xảy ra với `.agents`) | `git check-ignore -v <path>`, rồi `git add -f` + negate trong `.gitignore` của repo |

## Khi không có dòng nào khớp

Đừng nhét bừa vào một dòng gần đúng. Làm ba việc:

1. Thu nhỏ lại: lệnh nhỏ nhất còn tái hiện được lỗi.
2. Kiểm điểm xuất phát: `git stash` rồi chạy lại — xanh nghĩa là lỗi ở diff của bạn,
   đỏ nghĩa là lỗi ở môi trường.
3. Khi tìm ra, **thêm một dòng vào bảng trên**. Bảng này chỉ có giá trị vì nó được
   viết ngay lúc còn đau.
