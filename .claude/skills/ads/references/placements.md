# Bảng placement — mẫu

**File này là mẫu.** Điền nó từ bảng kịch bản ads của team growth / PO ngay khi
bảng về, và xoá phần "Ví dụ" bên dưới. Một bảng placement trống mà app vẫn có ads
nghĩa là tên placement đang nằm rải rác trong code — và đó là chỗ chúng lệch với
Remote Config mà không ai thấy.

Cột **File** điền đường dẫn thật của app khi bảng được điền.

Cột `name` là chuỗi truyền vào `SwiftUINativeView(name:)` /
`SwiftUIBannerView(name:)` / `tryShowInterstitialOnNavigation(name:)`.

> Nguồn: bảng kịch bản ads ngày **<ngày nhận>**.

| # | `name` | Format | Đặt ở đâu | File | Reload / Preload |
|---|---|---|---|---|---|
| 1 | | | | | |

Mọi space trong bảng phải có mặt **ở hai chỗ**: trên Firebase Remote Config, **và**
trong `<App>/Resources/remote_config_defaults.plist` để fallback khi chưa fetch
được. Xem mục "Default Remote Config" trong `SKILL.md`.

Vị trí **top/bottom của banner** đến từ `banner_position` trong Remote Config,
không phải từ code.

## Ví dụ (xoá khi điền bảng thật)

| # | `name` | Format | Đặt ở đâu | File | Reload / Preload |
|---|---|---|---|---|---|
| 1 | `home_na` | Native | Home — dưới hàng chip category | màn Home | reload khi chuyển tab |
| 2 | `home_ban` | Banner | Home — đáy màn | ↑ | — |
| 3 | `feed_na`, `feed_na2`, `feed_na3` | Native | Feed — sau mỗi 3 item | màn Feed | preload khi mở Home |
| 4 | `inapp_in` | Inter | chuyển từ Home sang Detail | màn Home | — |
| 5 | `setting_na` | Native | Settings — dưới danh sách | màn Settings | — |

## Chốt gì trước khi gắn

Bảng kịch bản viết bằng tay thì gần như luôn có chỗ mâu thuẫn, và **đoán sai thì
ad vẫn chạy, vẫn có doanh thu, chỉ số liệu về dashboard sai tên trong nhiều tuần**.
Bốn thứ phải soát khi nhận bảng:

1. **Hậu tố tên khớp format chưa** — `_na` là native, `_ban` là banner, `_in` là
   inter. Một dòng ghi type "Native" mà tên là `_ban` là một trong hai cột sai;
   hậu tố sẽ quyết định space nằm ở `ads_native` hay `ads_banner`, nên phải chốt
   chứ không chọn giúp.
2. **Một `name` xuất hiện hai dòng** — hoặc là một điểm bị chép hai lần, hoặc là
   hai khe khác nhau. Hai khe thì phải hai tên: một `name` chỉ hiện được một ad
   tại một thời điểm (luật 2 của `SKILL.md`).
3. **Cột Screen và cột Tracking lệch nhau** — chọn một, và ghi lại chọn cái nào.
   Lệch mà không ghi thì tên Remote Config và tên event khác nhau ở đúng một điểm,
   và sáu tuần sau không ai biết vì sao.
4. **Nhiều ad cùng lúc trên một màn** — đếm lại chiều cao: native 250 + banner 50 +
   nút chính, trên máy nhỏ nhất, còn đủ chỗ cho nội dung không.

Sai chính tả trong tên placement (`creat_` thiếu chữ `e`, chẳng hạn) thì **giữ
nguyên như bảng gốc**. Sửa cho đúng chính tả nghĩa là đổi tên một thứ dashboard đã
chờ.
