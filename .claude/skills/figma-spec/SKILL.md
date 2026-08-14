---
name: figma-spec
description: >-
  Biến design trên Figma thành ba văn bản trước khi code, theo đúng thứ tự có
  cổng review: `docs/FEATURE_SPEC.md` (người duyệt) → `docs/FEATURE_TEST_SPEC.md`
  (sau khi duyệt) → `docs/TASKS.md` (bảng task theo feature, mỗi màn kèm link
  Figma và trạng thái code/test). Dùng skill này sau `figma-intake` và trước
  `figma-screen`, hoặc khi được yêu cầu "viết feature spec", "viết test spec",
  "list task theo feature", "đang làm tới đâu rồi". Đừng viết test spec trước khi
  spec được duyệt — test spec sinh ra từ spec, nên viết trước là viết lại hai lần.
---

# Figma → spec → test spec → task board

Ba văn bản, ba thời điểm khác nhau. **Cổng review nằm giữa văn bản 1 và 2** và nó
là cổng thật: dừng lại, đưa người duyệt, đợi trả lời.

| # | File | Viết khi | Ai đọc |
|---|---|---|---|
| 1 | `docs/FEATURE_SPEC.md` | ngay sau `figma-intake` | người duyệt |
| 2 | `docs/FEATURE_TEST_SPEC.md` | **sau khi** spec được duyệt | QA + người code |
| 3 | `docs/TASKS.md` | cùng lúc với (2) | ai cũng đọc, cập nhật liên tục |

## 1 · FEATURE_SPEC.md

Một feature là **một luồng**, không phải một màn — cùng nghĩa với một folder trong
`Features/`. Mỗi feature một mục, mỗi màn một mục con.

Mỗi màn phải có, và mỗi thứ đều là một câu hỏi đã được trả lời:

- **Link Figma tới đúng node** (không phải link file chung). Đây là thứ khiến spec
  còn dùng được sau ba tuần.
- **Vào từ đâu, ra đi đâu** — và màn này có phải *addressable* không (deep link,
  notification, khôi phục state, guard đăng nhập). Có thì cần `KVRoute`; không thì
  `pushView` là đủ. Đây là quyết định kiến trúc, không phải chi tiết code — xem
  `ios-architecture/references/navigation.md`.
- **Cần đăng nhập không** → route conform `RequiresAuthentication`.
- **Dữ liệu từ đâu**: endpoint nào, hay chỉ là state cục bộ.
- **Bốn trạng thái**: loading, rỗng, lỗi, có dữ liệu. Design hay chỉ vẽ trạng thái
  đủ dữ liệu; ba cái còn lại phải hỏi chứ đừng tự chế.
- **Text người dùng đọc**, liệt kê ra. Chúng sẽ thành key trong 19 file `.strings`,
  nên phải biết có bao nhiêu chuỗi ngay từ đây.
- **Việc gì đã có sẵn** trong base (`LoadableContent`, `PrimaryButtonStyle`,
  `AppError` + toast, `RemoteImage`…) để không ai viết lại.

Có sẵn template: `.claude/skills/ios-feature/assets/feature-spec.md`.

**Rồi dừng.** Nói rõ đang chờ duyệt và liệt kê những chỗ mình đã phải đoán. Đừng
viết tiếp sang test spec.

## 2 · FEATURE_TEST_SPEC.md — chỉ sau khi duyệt

Test spec bám theo **tầng test của repo**, vì đó là nơi test thật sẽ nằm:

| Tầng | Test cái gì | Ở đâu |
|---|---|---|
| Domain | luật nghiệp vụ, validate | `Tests/DomainTests/` |
| Data | map DTO → entity, map lỗi → `AppError`, qua `KVMockNetworkSession` | `Tests/DataTests/` |
| Feature | `send(action)` → state đổi đúng, alert là state | `Tests/FeatureTests/` |
| Bằng tay | thứ không test nào bắt được | ghi thành checklist |

Mục "bằng tay" không phải chỗ đổ rác — nó có lý do: ba bug tệ nhất khi dựng base
(row trong `List` bấm không ăn, hai nguồn chân lý cho "đã đăng nhập", toast in
nguyên văn chuỗi hệ thống) **không có test nào bắt được**. Nên mỗi màn tối thiểu
có: bấm thật vào từng vùng chạm, xem ở dark mode, xem ở cỡ chữ lớn nhất, và mở
bằng một ngôn ngữ RTL nếu app còn bật tiếng Ả Rập.

Mỗi case viết dạng **hành động → kết quả quan sát được**, không viết "hoạt động
đúng".

## 3 · TASKS.md — bảng theo dõi

Một dòng một việc, và **task nhỏ nhất là một màn**, không phải một feature. Giữ
đúng các cột này để nhìn phát biết đang ở đâu:

```markdown
## Feature: Coupon

| # | Task | Figma | Tầng | Code | Test | Ghi chú |
|---|------|-------|------|------|------|---------|
| C1 | Entity + repository protocol | – | Domain | ✅ | ✅ | |
| C2 | Endpoint + DTO + map lỗi | – | Data | ✅ | ✅ | |
| C3 | Màn danh sách | [node](https://figma.com/design/…?node-id=12-345) | Feature | 🔨 | ⬜ | |
| C4 | Màn chi tiết | [node](https://figma.com/design/…?node-id=12-901) | Feature | ⬜ | ⬜ | chờ API |
| C5 | Đăng ký route + deep link | – | App | ⬜ | ⬜ | |

⬜ chưa làm · 🔨 đang làm · ✅ xong · ⛔ chặn (ghi lý do ở Ghi chú)
```

Ba luật của bảng này, mỗi luật vì một cách nó hay hỏng:

- **Cột Code và cột Test tách nhau.** Gộp một cột thì "xong" luôn có nghĩa là
  "code xong", và test không bao giờ được đòi.
- **Link Figma trỏ node, không trỏ file.** Link file bắt người đọc tự đi tìm, và
  ba tuần sau thì không ai tìm nữa.
- **⛔ phải kèm lý do.** Một task chặn mà không nói vì sao là một task sẽ bị bỏ
  quên chứ không phải được gỡ.

Task chỉ được đánh ✅ ở cột Test khi test **đã chạy xanh**, không phải khi đã viết
xong. `./tools/verify.sh` là câu trả lời cho "chạy xanh chưa".

## Thứ tự và ranh giới

```
figma-intake  →  figma-spec  →  [người duyệt]  →  test spec + TASKS.md  →  figma-screen
```

Skill này **không viết code**. Cần dựng tầng cho một feature thì đó là
`ios-feature` (12 bước); cần code một màn từ node Figma thì đó là `figma-screen`.
