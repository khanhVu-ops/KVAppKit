---
description: Khởi tạo repository này từ template KVAppBase.
argument-hint: <App Name> <bundle.id>
---

Dùng skill `init-base`. Parse `$ARGUMENTS` thành tên app rồi bundle id. Thiếu cái
nào thì hỏi. Chỉ khởi tạo repository mới; không bao giờ ghi đè project iOS đã có.

Hỏi cả **tier** trước khi chạy — app có gọi backend không, có đăng nhập không —
và đừng suy nó từ tên app. Không cờ = app tool: không network, không đăng nhập.
