# Feature: <Tên>

## Mục đích
Một đoạn: người dùng làm được gì sau feature này, và vì sao nó đáng làm.

## Màn hình

| Màn | Addressable? | Vào từ đâu | Ra đi đâu |
|---|---|---|---|
| | route / pushView | | |

"Addressable" = cần deep link, notification, restoration, hoặc bị auth chặn.
Nếu không, dùng `pushView` và bỏ trống cột route.

## State mỗi màn

```
State:
  <field>: <type>              # nguồn dữ liệu
  derived: <computed>          # tính từ field nào
Action:
  <case>                       # do UI nào gây ra
```

## API

| Endpoint | Method | Response | cachePolicy | Ghi chú |
|---|---|---|---|---|

Field nào **nullable**? Ghi rõ — đây là nguồn crash decode số một.

## Trạng thái lỗi

| Lỗi | Người dùng thấy gì |
|---|---|
| offline | |
| server 4xx | |
| server 5xx | |
| rỗng (không lỗi) | |

## Ngoài phạm vi
Cái gì *không* làm ở lần này, để không bị vẽ thêm giữa đường.

## Test phải có
- [ ]
- [ ]
- [ ]
