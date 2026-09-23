---
name: init-base
description: >-
  Khởi tạo một repository iOS mới từ template KVAppBase đã pin version. Dùng khi
  người dùng nói "init base", "tạo project mới", "khởi tạo app iOS", hoặc yêu cầu
  scaffold app mới kèm tên app và bundle id. KHÔNG dùng cho project đã có source
  iOS — script sẽ từ chối để tránh ghi đè, và trường hợp đó cần một workflow
  migrate riêng.
---

# Khởi tạo KVAppBase

Cần tên app, bundle id, **và tier**. Thiếu cái nào thì hỏi, đừng đoán.

1. **Kiểm tra repository trống.** Chỉ tiếp tục khi root chỉ có kit (và có thể có
   `.git`, `README.md`, `.gitignore`) — không có `MyApp/`, `App/`, `Packages/`,
   `project.yml`, hay `.xcodeproj`.

2. **Chốt tier — app này có gọi backend không, có đăng nhập không.** Đây là câu
   phải hỏi, không phải câu suy từ tên app: "Photo Editor" có thể có tài khoản,
   "Admin Tool" có thể không gọi API nào.

   | Tier | Cờ | App được gì |
   |---|---|---|
   | tool | *(không cờ)* | không network, không đăng nhập |
   | api | `--with-api` | `Data/`, `APIClientFactory`, KVNetworkit |
   | auth | `--with-auth` | thêm màn sign-in, keychain, `SessionController`, guard |

   `--with-auth` bao hàm `--with-api` (token lấy từ đâu nếu không có API). Thêm
   `--keep-demo` khi người ta muốn giữ luồng Order mẫu để đọc — nó kéo theo cả
   hai tầng.

   **Mặc định là tier tool, và mặc định đó có chủ đích:** tầng thêm vào thì dễ,
   gỡ ra thì không. Một app tool lỡ mang tầng auth sẽ mang nó mãi mãi. Nhưng
   đoán thiếu cũng đắt: dựng lại `SignInView` đã nối use case, keychain và
   `SessionController` bằng tay tốn hơn nhiều so với hỏi một câu. Nên **hỏi**.

3. Chạy:
   ```bash
   ./tools/init-base.sh --name "<App Name>" --bundle-id <com.company.app> [--with-api|--with-auth]
   ```
   Chỉ truyền `--source` / `--ref` khi người dùng yêu cầu version khác.

4. **Đọc output của script** và báo lại: source + ref KVAppBase đã dùng, tier,
   bundle id, những gì đã đổi tên. Source nằm trong folder mang tên module
   (`--name "Photo Tool"` → `PhotoTool.xcodeproj` + `PhotoTool/` + `PhotoToolTests/`),
   như project Xcode tạo tay. Không có XcodeGen: project được commit và mở thẳng
   bằng Xcode 16+. Tier tool không có package KVNetworkit, và không có
   `API_BASE_URL`/`USES_STUB_BACKEND` trong build settings lẫn `Info.plist` — đó là
   chủ đích, không phải thiếu. Script in cả số key l10n nó xoá vì không còn
   code nào dùng — nói con số đó ra, đừng nuốt.

5. Verify ngay: `./tools/verify.sh`. Một base vừa khởi tạo mà không build được là
   thứ phải sửa trước khi viết dòng code đầu tiên.

   `check-arch.sh` sẽ **skip** vài luật ở tier tool và api ("app không có tầng
   tương ứng"), và `doctor.sh` in vài dòng vàng về path chưa tồn tại. Cả hai là
   đúng, không phải lỗi cần sửa.

6. Sau đó cập nhật `AGENTS.md`: mục "App Features" và bảng module để chúng mô tả
   app thật, không còn là template. **Rule file mà mô tả sai cây source là cách
   base project trước đó đã trôi** — agent đọc `CLAUDE.md` sẽ bị dạy sai trước khi
   kịp load skill nào.

Đừng dùng skill này để trộn KVAppBase vào một app legacy. Nói rõ rằng việc đó cần
audit và migrate từng feature, không phải một script.
