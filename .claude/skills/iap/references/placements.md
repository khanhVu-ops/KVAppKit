# Placement IAP — mẫu

**File này là mẫu.** Điền từ danh sách PO cấp, và xoá phần "Ví dụ".

Cột `placement` là chuỗi truyền vào `VTIAPScreenView(placement:)`, và là `placement`
trong Remote Config `iap_placement_config`. Cột `screen_code` quyết định thiết kế
nào được vẽ — đổi nó trên Firebase là A/B một paywall mà không cần release.

| `placement` | Hằng số | Kiểu | Mở ở đâu | `screen_code` |
|---|---|---|---|---|
| | | | | |

Mọi entry phải có mặt **ở hai chỗ**: Firebase Remote Config **và**
`<App>/Resources/remote_config_defaults.plist`. Xem `SKILL.md`.

## Ví dụ (xoá khi điền bảng thật)

| `placement` | Hằng số | Kiểu | Mở ở đâu | `screen_code` |
|---|---|---|---|---|
| `open` | `IAPPlacement.open` | đầy đủ | màn IAP của startup, phiên 1 | `IAP1` |
| `reopen` | `IAPPlacement.reopen` | đầy đủ | màn IAP của startup, phiên ≥ 2 | `IAP1` |
| `iap` | `IAPPlacement.iap` | đầy đủ | **không mở trực tiếp** — đích của alias | `IAP1` |
| `setting` | `IAPPlacement.setting` | alias → `iap` | hàng premium ở Settings | *(theo `iap`)* |
| `icon_app` | `IAPPlacement.iconApp` | alias → `iap` | chip Get Pro ở Home | *(theo `iap`)* |

Ba kiểu entry, và phân biệt được chúng là phân biệt được chỗ sửa khi đổi gói:

| Kiểu | JSON | Khi nào |
|---|---|---|
| **đầy đủ** | `screen_code` + `product_ids` (+ `bonus`) | điểm mở có bộ gói riêng |
| **alias** | `placement` + `funnel` trỏ sang entry đầy đủ | nhiều điểm mở bán cùng bộ gói |
| **đích của alias** | entry đầy đủ mà không ai present trực tiếp | nơi duy nhất khai gói dùng chung |

## Chốt gì khi nhận danh sách

1. **Mỗi điểm mở là một `placement` riêng, kể cả khi bán cùng gói.** Gộp hai điểm
   vào một tên thì `show_iap` và `pur_success_<placement>` của chúng cộng vào nhau,
   và không ai trả lời được paywall nào bán được hàng. Dùng alias `funnel`, đừng
   dùng lại tên.
2. **Bộ gói dùng chung nằm ở đúng một entry.** Nếu năm điểm mở khai lại cùng
   `product_ids` thì đổi gói là năm chỗ sửa, và chỗ thứ năm sẽ bị quên.
3. **`delay_can_dismiss` chỉ đặt ở paywall của luồng startup**, không đặt ở paywall
   mở từ trong app: người dùng bấm vào nút premium rồi không đóng được màn trong ba
   giây là một lượt uninstall, không phải một lượt mua.
4. **`screen_code` phải có view đã đăng ký.** Code chưa đăng ký → paywall trắng,
   không crash, không log — `tools/check-monet-config.sh` là thứ bắt được.
5. **Placement chưa có điểm mở thì cứ giữ** nếu kịch bản còn dở. Xoá đi thì lúc làm
   tới phải khai lại cả hai đầu; script in chúng ở dòng `ℹ️`, không fail.
