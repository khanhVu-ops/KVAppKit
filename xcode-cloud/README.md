# Xcode Cloud cho app cá nhân

Bộ này thay fastlane + GitHub Actions self-hosted (chuẩn của công ty) bằng **Xcode Cloud**
cho các app thuộc team cá nhân **Van Khanh Vu (`W3274W2Y83`)**, nơi bạn là Account Holder.

Vì sao đổi:

- **Không còn giữ khoá ký.** Xcode Cloud tự tạo và quản chứng chỉ phân phối, profile
  (cloud-managed signing). Không còn `.p12`, `signing.properties`, `asc-api-key.json`,
  không cần máy nào bật sẵn làm runner.
- **Miễn phí trong giới hạn.** Gói Apple Developer Program đã kèm 25 giờ compute mỗi tháng.
  Một lần Verify của app cỡ Veilnest mất khoảng 10–15 phút.
- **Đẩy thẳng TestFlight.** Archive xong là bản lên TestFlight cho nhóm tester nội bộ,
  không phải gọi API upload riêng.

## Trong thư mục này

| File | Vai trò |
|---|---|
| `install.sh` | Cài vào một repo app: chép script, sửa `.gitignore`, kiểm `Package.resolved` và team, xoá CI cũ nếu được bảo |
| `ci_post_clone.sh` | Bản chung. Xcode Cloud chạy ngay sau khi clone: tải Metal Toolchain nếu repo có shader, `xcodegen generate` nếu có `project.yml`, `pod install` nếu có `Podfile`, kiểm `Package.resolved`, rồi gọi `app_post_clone.sh` |
| `ci_post_xcodebuild.sh` | Bản chung. Sau khi archive: viết "What to Test" cho TestFlight từ 10 commit gần nhất |
| `snippets/` | Đoạn README/AGENTS mô tả Xcode Cloud, chép vào repo dựng từ KVAppBase khi xoá fastlane |

Mỗi app có thêm `ci_scripts/app_post_clone.sh` của riêng nó (lint, luật kiến trúc,
localization). `install.sh` chỉ tạo file này khi chưa có và không bao giờ ghi đè.

## Cài vào app

App mới dựng từ kit:

```bash
./tools/init-base.sh --name "My App" --bundle-id com.khanhvu.myapp --xcode-cloud
```

App đã có (đứng ở bất kỳ đâu):

```bash
~/personal/KVAppKit/xcode-cloud/install.sh ~/personal/MyApp --remove-fastlane
```

`--dry-run` để xem trước. Chạy lại bao nhiêu lần cũng được; đó cũng là cách cập nhật bản
chung sau khi sửa script ở đây. Script làm:

1. Chép `ci_post_clone.sh`, `ci_post_xcodebuild.sh` vào `ci_scripts/` **cạnh**
   `.xcodeproj`/`.xcworkspace` (Xcode Cloud tìm ở đó, không phải ở gốc repo).
2. Tạo `app_post_clone.sh` nếu chưa có. Repo có `tools/check-arch.sh`, `check-l10n.sh`
   (KVAppBase) thì file này gọi sẵn chúng.
3. Repo KVAppBase: thêm `ci_scripts`, `TestFlight` vào danh sách bỏ qua của luật
   "README khớp thư mục tầng" trong `check-arch.sh`, nếu không luật đó đỏ ngay.
4. Thêm `TestFlight/` vào `.gitignore`.
5. Kiểm `Package.resolved`. Repo XcodeGen ignore cả `*.xcodeproj` thì đổi thành ignore
   nội dung, chừa riêng `Package.resolved`.
6. Kiểm team: project commit sẵn mà chưa chọn team thì điền `W3274W2Y83`; đang là team
   khác (công ty) thì chỉ cảnh báo.
7. `--remove-fastlane`: xoá `fastlane/`, `Gemfile` có fastlane, mọi workflow GitHub nhắc
   fastlane hoặc self-hosted; viết lại mục CI/CD trong README và lệnh fastlane trong
   AGENTS.md nếu đúng khuôn KVAppBase; liệt kê file còn nhắc fastlane để sửa tay.

Xong thì commit và push. Script in lệnh `git add` đúng cho repo đó.

## Thiết lập một lần cho tài khoản

Chỉ làm ở app đầu tiên:

1. Xcode → Settings → Accounts: đăng nhập Apple ID có team **Van Khanh Vu**.
2. Lần đầu tạo workflow, Xcode mở trang **Grant Access** để cài app *Xcode Cloud* lên
   GitHub `khanhVu-ops`. Chọn **Only select repositories** và tick:
   - repo app,
   - mọi repo package **private** mà app kéo về: hiện là `KVIAPKit`, `KVAdsKit`,
     `KVCameraKit`, `KVEditorKit`. Package public (`KVRouter`, `KVDIKit`,
     `KVNetworkit`, `KVToastKit`, `KVLoggingKit`, `KVNotesKit`…) không cần.

   Thiếu một repo private thì build đỏ ở bước resolve với lỗi không có quyền. Thêm sau
   được: GitHub → Settings → Applications → Xcode Cloud → Configure.
3. App Store Connect → TestFlight → Internal Testing: tạo một nhóm (ví dụ `Studio`) và
   thêm chính bạn. Workflow Release sẽ đẩy bản vào nhóm này.

## Thiết lập cho từng app (khoảng 5 phút)

App phải đã có record trên App Store Connect, cùng bundle id với project.

1. Mở project trong Xcode → **Integrate → Create Workflow…** (hoặc Report navigator ⌘9 →
   tab Cloud). Chọn app, Xcode tự tạo "product" trên Xcode Cloud.
2. Sửa workflow mặc định thành **Verify**, rồi Duplicate ra **Release**:

| | Verify | Release |
|---|---|---|
| Start Conditions | Branch Changes: `main` · Pull Request Changes: mọi nhánh | Tag Changes: `v*`. Xoá hết điều kiện nếu chỉ muốn bấm tay |
| Environment | Xcode: Latest Release · macOS: Latest | như Verify · bật **Clean** |
| Action | **Test** · scheme có test (Veilnest: `iOSVault-CI`) · iOS Simulator, 1 máy (iPhone mới nhất) | **Archive** · scheme Release (Veilnest: `iOSVault`) · Deployment Preparation: **TestFlight and App Store** |
| Post-Actions | không | **TestFlight Internal Testing** → nhóm ở bước trên |

3. App Store Connect → app → **Xcode Cloud → Settings → Build Number**: đặt số tiếp theo
   **lớn hơn build cao nhất đã upload** cho version hiện tại. Xcode Cloud tự đánh build
   number (`CI_BUILD_NUMBER`) và ghi đè `CURRENT_PROJECT_VERSION` khi archive; trùng số cũ
   thì TestFlight từ chối.
4. Bấm **Start Build** cho Verify để xác nhận lần đầu.

Release theo tag:

```bash
git tag v1.4-b5 && git push origin v1.4-b5
```

Không workflow nào submit review. Submit vẫn bấm trong App Store Connect.

## Biến môi trường và secret

Workflow → Environment → **Environment Variables**. Tick **Secret** để giá trị bị ẩn
trong log. `ci_post_clone.sh`, `app_post_clone.sh` đọc được như biến shell. Không commit
secret vào repo.

Biến Xcode Cloud hay dùng trong script: `CI_WORKFLOW`, `CI_XCODEBUILD_ACTION`
(`build-for-testing`, `test-without-building`, `archive`…), `CI_BRANCH`, `CI_TAG`,
`CI_PULL_REQUEST_NUMBER`, `CI_BUILD_NUMBER`, `CI_PRIMARY_REPOSITORY_PATH`.

## Lỗi hay gặp

| Triệu chứng | Nguyên nhân · cách sửa |
|---|---|
| `a resolved file is required when automatic dependency resolution is disabled` | Chưa commit `Package.resolved`. Mở Xcode cho nó resolve, commit file đó |
| `Package.resolved is out-of-date` | Đổi `packages:`/dependency mà quên commit file resolved mới |
| `Repository not found` khi resolve | Chưa cấp quyền repo package private cho Xcode Cloud (mục Thiết lập một lần, bước 2) |
| `cannot execute tool 'metal'` | Image mới thiếu Metal Toolchain; `ci_post_clone.sh` tự tải khi repo có `.metal`. Gặp lại thì xem log bước post-clone |
| `Could not find project` | `ci_scripts/` không nằm cạnh project, hoặc repo XcodeGen mà `ci_post_clone.sh` không chạy (thiếu quyền thực thi: `chmod +x ci_scripts/*.sh` rồi commit) |
| TestFlight từ chối vì build number | Tăng Build Number ở Xcode Cloud → Settings |
| Đỏ ở `app_post_clone.sh` | Luật của app vi phạm thật. Chạy ở máy: `CI_PRIMARY_REPOSITORY_PATH="$PWD" ci_scripts/ci_post_clone.sh` |

Chạy thử script ở máy trước khi push:

```bash
CI_PRIMARY_REPOSITORY_PATH="$PWD" ci_scripts/ci_post_clone.sh
```

Lưu ý: script chạy `xcodegen generate` (repo XcodeGen) và các self-test có tạm ghi file
probe vào source. Đừng chạy nó trong lúc một lệnh `xcodebuild test` khác đang chạy trên
cùng repo.
