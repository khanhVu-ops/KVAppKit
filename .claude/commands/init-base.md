---
description: Khởi tạo repository này từ template KVAppBase.
argument-hint: <App Name> <bundle.id>
---

Dùng skill `init-base`. Parse `$ARGUMENTS` thành tên app rồi bundle id. Thiếu cái
nào thì hỏi. Chỉ khởi tạo repository mới; không bao giờ ghi đè project iOS đã có.
