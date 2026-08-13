---
name: api-intake
description: >-
  Biến một spec API (OpenAPI/Swagger, Postman collection, hoặc mấy cái curl gửi qua
  chat) thành `docs/API_INVENTORY.md` cho app iOS này, rồi từ đó sinh endpoint + DTO
  theo từng feature. Dùng skill này khi nhận được link Swagger, file
  openapi.json/yaml, Postman export, hoặc khi được hỏi "backend có những API nào",
  "map API vào app", "chuẩn bị data layer cho feature X". Đừng dịch cả spec thành
  code — inventory là để *quyết định lấy gì*, và phần lớn spec là thứ app này sẽ
  không bao giờ gọi.
---

# Nhận một spec API

## Nguyên tắc: inventory trước, code sau

Một spec 200 endpoint dịch máy thành 200 DTO là 200 file phải bảo trì cho một app
gọi 12 cái. Inventory là bước quyết định lấy gì — và nó là tài liệu người đọc, không
phải bước sinh code.

## Bước 1: đọc được spec đã

```bash
# OpenAPI: liệt kê path + method, không đọc cả file
jq -r '.paths | to_entries[] | .key as $p | .value | to_entries[]
       | "\(.key|ascii_upcase) \($p)  \(.value.summary // "")"' openapi.json | sort

# Postman collection
jq -r '.. | objects | select(.request?) | "\(.request.method) \(.request.url.raw)"' collection.json | sort -u

# YAML thì đổi sang JSON trước
yq -o=json openapi.yaml > /tmp/openapi.json
```

Không có `jq`/`yq`, hoặc spec là link Swagger UI: xin file JSON. Đọc HTML của
Swagger UI để suy ra shape là cách chắc chắn nhất để sai một field optional.

## Bước 2: viết `docs/API_INVENTORY.md`

```markdown
# API inventory

> Nguồn: <file/link + version/date>. Cập nhật: <YYYY-MM-DD>.
> Chỉ liệt kê endpoint app **thật sự dùng hoặc sắp dùng**.

## Auth

| Endpoint | Method | Dùng ở đâu | Đã code? | cachePolicy |
|---|---|---|---|---|
| /auth/login | POST | SignIn | ✅ `AuthEndpoint.signIn` | ignore |

## <Nhóm khác>

...

## Field nullable — đọc kỹ mục này

| Endpoint | Field | Nullable? | App làm gì khi thiếu |
|---|---|---|---|

## Lỗi backend trả

| HTTP | Body shape | Map sang AppError |
|---|---|---|

## Chưa rõ / phải hỏi backend

- ...
```

Ba mục cuối là phần đáng tiền. Bảng path thì spec nào cũng có; **nullable, shape của
lỗi, và những chỗ chưa rõ** là thứ quyết định app có crash hay không, và spec thường
nói sai hoặc không nói.

## Bước 3: đối chiếu spec với sự thật

Spec nói `required: true` không có nghĩa production luôn gửi. Với mỗi endpoint sắp
code, xin **một response thật** (curl hoặc log của backend) và so:

- Field nào spec bảo required mà response thật thiếu → DTO khai optional.
- Kiểu số: `total` là number hay string? Backend đổi kiểu là lỗi decode im lặng.
- Ngày: format gì, timezone gì. Đây là nguồn lỗi thứ hai sau nullable.

Không xin được response thật thì **khai optional hết** trừ id, và ghi vào mục "chưa
rõ". Optional quá tay chỉ tốn một dòng `?? default`; non-optional sai một field là
màn hình rỗng.

## Bước 4: sinh code, theo feature — không theo spec

Mỗi endpoint cần dùng thì đi qua skill `ios-endpoint` (DTO → case → protocol →
impl → stub → test). Đừng sinh trước cho những cái "chắc sẽ cần": endpoint không ai
gọi là code chết, và nó vẫn phải sửa mỗi lần backend đổi.

Nhóm endpoint theo enum như base đang làm: `AuthEndpoint`, `OrderEndpoint` — một
enum một nhóm nghiệp vụ, không phải một enum một endpoint.

## Đừng

- Đừng commit cả file `openapi.json` vào repo nếu chỉ dùng 12 endpoint — link +
  version trong inventory là đủ, và không ai review một diff 40 nghìn dòng.
- Đừng đặt tên DTO theo tên schema của backend nếu tên đó vô nghĩa
  (`InlineResponse200`). DTO là của app; đặt theo cái nó chứa.
- Đừng để inventory hết đúng mà không ai biết: mọi PR thêm endpoint phải sửa nó,
  và `ios-endpoint` có nhắc bước đó.
