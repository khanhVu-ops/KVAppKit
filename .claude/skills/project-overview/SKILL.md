---
name: project-overview
description: >-
  Quét repo iOS thật rồi sinh `docs/PROJECT_OVERVIEW.md`: feature nào có màn nào,
  route nào addressable và đã register chưa, endpoint nào tồn tại, DI key nào đang
  khai, entity/use case, số test theo tầng. Dùng skill này khi được yêu cầu "tổng
  quan project", "app này có gì", "map lại codebase", khi onboard người/agent mới,
  hoặc khi cần biết một feature đã có sẵn tới đâu trước khi thêm việc. Overview
  được **sinh từ source**, không viết tay — một bản mô tả tự tin về cây source đã
  đổi là cách dạy sai nhanh nhất.
---

# Sinh PROJECT_OVERVIEW.md

Nguyên tắc: **mọi dòng trong overview phải đến từ một lệnh**. Không suy diễn, không
"có lẽ", không mô tả ý định. Nếu một thông tin không quét được thì ghi rõ là chưa
biết, đừng đoán cho đủ mặt.

## Quét

Chạy từ root của repo. Các lệnh này đã kiểm trên chính base.

Source nằm trong folder mang tên target (`name:` của `project.yml`), test ở
`<tên>Tests/` — nên bước đầu là vào folder đó. Quét từ root thì `Features/*/` không
khớp gì, và overview ra một app "chưa có feature nào" trông rất thuyết phục.

```bash
app="$(awk '/^name:/ { print $2; exit }' project.yml)"
cd "$app"

# Feature và màn hình của nó
for f in Features/*/; do
  printf '%s: ' "$(basename "$f")"
  find "$f" -name '*View.swift' -exec basename {} .swift \; | tr '\n' ' '; echo
done

# Route được khai, và route đã register
grep -rhoE 'case [a-zA-Z]+(\(.*\))?' Features/*/*Route.swift
grep -oE 'register\([A-Za-z]+\.self' App/Navigation/AppRoutes.swift

# Endpoint theo nhóm
for f in Data/Network/Endpoints/*.swift; do
  printf '%s: ' "$(basename "$f" .swift)"
  grep -oE '^    case [a-zA-Z]+' "$f" | awk '{print $2}' | tr '\n' ' '; echo
done

# DI key, entity, use case
grep -rhoE 'enum [A-Za-z]+Key' DI/ | sort -u
ls Domain/Entities Domain/UseCases

# Test: tổng và theo tầng
grep -rho 'func test_[a-zA-Z_]*' "../${app}Tests" | wc -l
for d in "../${app}Tests"/*/; do printf '%s: ' "$(basename "$d")"; grep -rho 'func test_' "$d" | wc -l; done
```

Thêm hai thứ chỉ đọc được ở file, không quét bằng một dòng:

- **Cấu hình build** (từ root): `grep -nE 'API_BASE_URL|USES_STUB_BACKEND|deploymentTarget' project.yml`
  — overview phải nói rõ Debug đang chạy stub hay API thật. App tool không có hai key
  đầu (init-base gỡ chúng cùng `Data/`): ghi "không có backend", đừng ghi "chưa biết".
- **Version package**: `grep -A2 -E '^  KV' project.yml`.

## Ghi

Vào `docs/PROJECT_OVERVIEW.md`, theo đúng thứ tự này — người đọc cần "app này làm
gì" trước "nó được lắp thế nào":

```markdown
# <Tên app> — tổng quan

> Sinh bằng skill `project-overview` ngày <YYYY-MM-DD>, từ commit <sha>.
> Đừng sửa tay: chạy lại skill.

## Feature

| Feature | Màn | Route addressable | Đã register |
|---|---|---|---|

## API

| Endpoint | Case | cachePolicy | Repository dùng nó |
|---|---|---|---|

## Domain

Entity · use case · port (`Services/`), mỗi cái một dòng nói nó *để làm gì*.

## Dependency

| Key | liveValue | có testValue? |
|---|---|---|

## Test

Tổng, và theo tầng. Kèm một câu: tầng nào đang mỏng nhất.

## Cấu hình

Deployment target, ba configuration, `USES_STUB_BACKEND` đang bật ở đâu, base URL.

## Chỗ chưa biết

Cái gì quét không ra và tại sao. Mục này rỗng là dấu hiệu bạn đang đoán.
```

## Đọc kết quả cho đúng

Ba thứ đáng nói ra khi thấy, vì chúng là bug đang chờ:

- **Route khai mà chưa register** → màn trắng khi deep link tới. `switch` trong
  `AppRoutes.swift` là chỗ compiler bắt giúp, nhưng chỉ khi route đó có trong enum.
- **DI key thiếu `testValue`** → test nào chạm tới nó sẽ đi ra mạng thật.
- **Endpoint không repository nào gọi** → hoặc code chết, hoặc một feature làm nửa
  đường.

## Đừng

- Đừng viết overview cho code *sắp* có. Overview là ảnh chụp, không phải kế hoạch.
- Đừng copy `AGENTS.md` vào đây. Rule ở đó; overview nói repo này hiện có gì.
- Đừng bỏ dòng "sinh ngày/commit". Không có nó thì không ai biết bản này còn đúng
  hay không — và một overview cũ đọc y như một overview đúng.
