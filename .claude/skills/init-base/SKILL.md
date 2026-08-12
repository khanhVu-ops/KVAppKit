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

Cần tên app và bundle id. Thiếu cái nào thì hỏi, đừng đoán.

1. **Kiểm tra repository trống.** Chỉ tiếp tục khi root chỉ có kit (và có thể có
   `.git`, `README.md`, `.gitignore`) — không có `App/`, `Packages/`,
   `project.yml`, hay `.xcodeproj`.

2. Chạy:
   ```bash
   ./tools/init-base.sh --name "<App Name>" --bundle-id <com.company.app>
   ```
   Chỉ truyền `--source` / `--ref` khi người dùng yêu cầu version khác.

3. **Đọc output của script** và báo lại: source + ref KVAppBase đã dùng, bundle id,
   những gì đã đổi tên.

4. Verify ngay: `./tools/verify.sh`. Một base vừa khởi tạo mà không build được là
   thứ phải sửa trước khi viết dòng code đầu tiên.

5. Sau đó cập nhật `AGENTS.md`: mục "App Features" và bảng module để chúng mô tả
   app thật, không còn là template. **Rule file mà mô tả sai cây source là cách
   base project trước đó đã trôi** — agent đọc `CLAUDE.md` sẽ bị dạy sai trước khi
   kịp load skill nào.

Đừng dùng skill này để trộn KVAppBase vào một app legacy. Nói rõ rằng việc đó cần
audit và migrate từng feature, không phải một script.
