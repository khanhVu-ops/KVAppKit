---
name: ios-review
description: >-
  Review một diff trên app iOS này theo luật của repo: phân tầng, State/Action,
  luật hiệu năng iOS 16, navigation, logging/privacy, test. Dùng skill này khi được
  yêu cầu review code, xem lại diff, "check hộ đoạn này", trước khi mở PR, hoặc sau
  khi vừa làm xong một feature và muốn biết còn sai gì. Skill lo *quy trình và cách
  báo cáo*; luật thì lấy từ `ios-architecture/references/review-checklist.md`, không
  viết lại — hai bản luật là hai bản sẽ lệch nhau.
---

# Review một diff

## Trước khi đọc dòng nào

```bash
./tools/verify.sh
```

Chạy trước, không sau. Nó lo 10 luật phân tầng + build + test, nên mọi thứ nó bắt
được thì bạn không cần mắt. Review bằng mắt là để tìm những cái script **không**
kiểm được — và danh sách đó là
`ios-architecture/references/review-checklist.md`. Mở nó ra, đi từng mục.

Lấy diff đúng phạm vi:

```bash
git diff --stat                    # đang sửa gì
git diff                           # chưa commit
git diff main...HEAD               # cả branch
```

## Thứ tự đọc

Từ trong ra ngoài, đúng chiều phụ thuộc. Lỗi ở tầng trong làm mọi thứ ngoài nó sai
theo, nên tìm ở đó trước rẻ hơn.

1. `Domain` — có import gì mới ngoài Foundation? entity có field nào chỉ backend quan tâm?
2. `Data` — lỗi mới đã map trong `AppError+Network.swift`? DTO có optional đúng chỗ?
3. `DI` — key mới có `testValue`?
4. `Features` — State/Action, view con nhận value, alert là state.
5. `App` — route mới đã register, deep link đã có trong cả `AppDeepLink` **và** `stack(for:)`.
6. `Tests` — có assert phủ định không?

## Loại lỗi đáng tìm nhất

Script bắt được vi phạm cấu trúc. Cái nó không bắt được là **lời hứa không ai thực
hiện** — và đó là loại đắt nhất, vì code đọc như đúng.

Ví dụ thật trong repo này: `OrderRepositoryProtocol.list(forceRefresh:)` có doc
comment "Skip any cached copy", ViewModel truyền `true` khi pull-to-refresh, test
truyền `true` — mà repository lại gọi một endpoint có `cachePolicy` cố định. Cờ đó
không làm gì cả trong nhiều tháng: kéo xuống refresh vẫn nhận đúng bản cache tới 60
giây. Không luật phân tầng nào vi phạm, không test nào đỏ.

Khi review, cho mỗi tham số/cờ/flag mới hỏi đúng một câu: **ai đọc nó?** Nếu lần
theo không tới nơi nào dùng, đó là một finding.

Cùng họ với nó:

- Field lưu **và** computed cùng nói một chuyện → hai nguồn chân lý.
- `Loadable` cạnh một `isLoading` riêng.
- Doc comment nói khác code (doc là lời hứa; code là hành vi).
- `catch` bắt rồi bỏ, hoặc map về `.unknown` khiến người dùng thấy chuỗi hệ thống.
- Route mới có case nhưng chưa ai push tới.

## Báo cáo

Mỗi finding một dòng, xếp nặng trước nhẹ sau:

```
<file>:<line> — <cái gì sai>. Vỡ khi: <tình huống cụ thể>. Sửa: <việc nhỏ nhất đủ sửa>.
```

"Vỡ khi" là phần bắt buộc. Không nêu được tình huống cụ thể thì đó là ý kiến về
thẩm mỹ, không phải finding — hoặc để nó xuống mục riêng và gọi đúng tên là gợi ý.

Kết thúc bằng ba câu:

- Đã chạy gì (kết quả thật: bao nhiêu test, pass/fail).
- Cái gì **chưa** kiểm được (chưa mở app? chưa thử offline? nói ra).
- Có nên merge hay không, và nếu không thì thiếu chính xác cái gì.

## Đừng

- Đừng nới luật để diff đi tiếp. Luật sai thì đề xuất sửa luật **và** sửa
  `check-arch.sh` cùng lúc, trong một PR riêng.
- Đừng review lại thứ `verify.sh` vừa xanh (import, màu literal, view con giữ VM) —
  trùng việc, và làm loãng finding thật.
- Đừng đếm số finding để chứng minh đã review kỹ. Một finding "vỡ khi offline" đáng
  hơn mười góp ý về tên biến.
