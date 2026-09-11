---
name: iap
description: >-
  Mở paywall và gate tính năng premium bằng VTMonetSDK. Dùng khi task nhắc "IAP",
  "paywall", "premium", "subscription", "mua gói", "restore", một tên placement IAP,
  một `screen_code` (`IAP1`, `IAP2`…), hoặc khi phải sửa `iap_placement_config`.
  Cũng dùng khi dựng paywall đầu tiên cho một repo vừa init — KVAppBase không có
  VTMonetSDK sẵn.
---

# IAP bằng VTMonetSDK

SDK sở hữu StoreKit: load sản phẩm, mua, restore, tính trial/savings, bật premium,
và **bắn gần hết event analytics**. Việc của app có ba:

1. **Khai placement** trong Remote Config `iap_placement_config`.
2. **Đăng ký thiết kế** cho mỗi `screen_code`, một lần lúc launch.
3. **Mở paywall** bằng `VTIAPScreenView(placement:)`.

Không có việc thứ tư. Không gọi StoreKit, không tự đếm entitlement, không tự bắn
event mua hàng.

Cài SDK (repo vừa `init-base` thì chưa có): xem **Bước 0** trong skill `ads` —
Podfile, `pod install`, `GoogleService-Info.plist`, `initSDKController`,
`initSplash`. `initSDKController` nhận luôn danh sách sản phẩm:

```swift
MonetSDKController.shared.initSDKController(
    appleAppId: "<app store id>",
    subscriptionPackages: ["com.app.weekly", "com.app.yearly"],
    inAppPackages: [],                       // consumable / non-consumable
    launchOptions: launchOptions
)
```

## Trước khi đọc tiếp: kiểm version trước khi tin `docs/IAP_GUIDE.md`

SDK repo có `docs/IAP_GUIDE.md` dạy `VTMonetIAP.configure(verification:)`,
`VTIAPDelegate`, server verify, `product.activeOffer`, `product.priceInfo`,
`isTrialAvailable`, `fakeDisplayPrice`, `.pendingServerVerification`,
`VTIAPManager.shared.loadPlacements()`.

**Không API nào trong số đó có ở 2.1.1 / 2.1.2-rc** — đã kiểm từng cái trên
`.swiftinterface` của binary. Guide đó mô tả một nhánh khác.

Trước khi viết code theo guide, kiểm bản đang pin:

```bash
grep -c "VTMonetIAP" Pods/VTMonetSDKBinary/AdMob/VTMonetSDK.xcframework/ios-arm64/VTMonetSDK.framework/Modules/VTMonetSDK.swiftmodule/*.swiftinterface
```

`0` nghĩa là bản này **không có server verify, không có `VTIAPDelegate`, không có
`activeOffer`**. Quyền cấp ngay trên máy sau khi StoreKit xác thực; consumable và
credit theo server không có đường nối. Cần chúng thì đó là việc **nâng SDK**.

## Bề mặt thật (2.1.1)

| Việc | API |
|---|---|
| Mở paywall | `VTIAPScreenView(placement:strings:onClose:)` |
| Vẽ màn riêng | `VTIAPScreenRegistry.shared.registerIAPView(screenCode:) { vm in … }` |
| Đóng màn từ trong thiết kế | `@Environment(\.vtIAPScreenOnClose)` |
| Trạng thái + hành động | `VTIAPViewModel`: `state`, `purchaseState`, `products`, `bonusProducts`, `selectedIndex`, `selectedProduct`, `badgeProductID`, `delayCanDismiss`, `showBonus`, `purchaseSelected()`, `purchase(productID:)`, `restore()`, `dismissBonus()`, `trackCloseIAP()` |
| Sản phẩm | `VTIAPProductModel`: `productID`, `isTrial`, `period`, `displayPrice`, `displayPricePerWeek`, `pricePerWeek`, `savingsPercent`, `title`, `introOfferDays`, `rawProduct` |
| Gate premium | `MonetSDKController.shared.isPurchased` (`@Published`) |
| Kiểm placement có thật | `MonetSDKController.shared.hasIAPPlacement(named:)` |

## Ba công thức

### 1 · Mở paywall

```swift
.fullScreenCover(isPresented: $showPaywall) {
    VTIAPScreenView(placement: IAPPlacement.setting) {
        showPaywall = false
    }
}
```

`onClose` là chỗ app đóng màn. Đừng tự bắn event đóng — dùng closure này thì SDK
tự log `close_iap`.

### 2 · Vẽ một thiết kế paywall

```swift
struct PaywallScreen001: View {
    @ObservedObject var viewModel: VTIAPViewModel
    @Environment(\.vtIAPScreenOnClose) private var onClose
    …
}

// Một lần lúc launch:
VTIAPScreenRegistry.shared.registerIAPView(screenCode: VTIAPScreenCode.iap1) { vm in
    PaywallScreen001(viewModel: vm)
}
```

Rồi đặt `screen_code` của placement trong Remote Config. **Đó là cả cách A/B một
thiết kế paywall**: không release, chỉ đổi một chuỗi.

**Đăng ký ở composition root (`App.init`), không phải trong `onAppear` của một
màn.** `VTIAPScreenView` tra registry lúc nó hiện ra, và paywall mở được từ những
chỗ không đi qua luồng startup — deep link, restoration, nút premium ở Settings.
Registry rỗng lúc đó là một paywall **trắng**, không phải crash, nên nó sẽ không lộ
ra trong test.

### 3 · Gate một tính năng

Không đọc `MonetSDKController` từ `Features/`. Đi qua một cổng ở `Domain/Services`
(cùng khuôn `ToastService`), và `Data` hiện thực nó bằng `isPurchased` — như vậy
một màn test được với stub, và luật 3 của `check-arch.sh` vẫn đúng.

## `iap_placement_config` — schema

Một JSON array trong Remote Config, và trong
`<App>/Resources/remote_config_defaults.plist`.

```json
[
  {
    "placement": "iap",
    "screen_code": "IAP1",
    "product_ids": ["com.app.weekly", "com.app.yearly"],
    "default_selected": 1,
    "badge_product_id": "com.app.yearly",
    "delay_can_dismiss": 3000,
    "bonus": {
      "enabled": true,
      "product_ids": ["com.app.weekly", "com.app.monthly"],
      "default_selected": 1
    }
  },
  { "placement": "setting", "funnel": "iap" }
]
```

| Key | Bắt buộc | Thiếu thì |
|---|---|---|
| `placement` | **có** | **cả mảng decode trượt** — mọi paywall của app rỗng |
| `screen_code` | không | `"IAP1"` |
| `product_ids` | không | `[]` → paywall không có gói nào |
| `default_selected` | không | `1` (**1-based**, không phải index) |
| `badge_product_id` | không | gói đang chọn |
| `delay_can_dismiss` | không | `0` — nút X hiện ngay |
| `bonus.enabled` | không | `false` |
| `funnel` | không | = chính placement |
| `fake_price` | không | không có giá gạch ngang (chỉ bản có `priceInfo`) |

`placement` là key duy nhất bắt buộc, và hậu quả không tỉ lệ với lỗi: một entry
thiếu nó làm cả `[VTIAPPlacementConfig]` throw, và app mất **toàn bộ** paywall.

### `funnel` làm hai việc — đọc kỹ chỗ này

`funnel` vừa là **alias trỏ sang config của placement khác**, vừa là `funnel_type`
trong analytics.

```json
{ "placement": "setting", "funnel": "iap" }
```

nghĩa là `setting` dùng gói và `screen_code` của placement `iap`, và gom về funnel
`iap` trên dashboard. Đây là cách đúng khi nhiều điểm mở cùng bán một bộ gói: **đổi
gói là sửa một entry, không phải mười.**

Hệ quả phải nhớ: `funnel` trỏ vào placement **không tồn tại** thì entry giữ config
rỗng của chính nó → paywall trắng, không log gì.
`tools/check-monet-config.sh` kiểm điều này.

### Analytics — SDK tự bắn, một chỗ cần tay

Khác ads (SDK không bắn event ads nào), IAP thì SDK log gần hết:

| Event | Khi nào |
|---|---|
| `show_iap` | paywall load xong và hiện |
| `click_subscription` | user đổi gói đang chọn |
| `click_CTA` | bấm nút mua |
| `close_iap` | đóng paywall mà chưa mua |
| `payment_result_iap` | sau khi payment sheet đóng (`Success`/`Fail`) |
| `view_<placement>` · `pur_success_<placement>` | cho A/B đọc trực tiếp trên Firebase |

Params chung: `placement`, `screen_code`, `funnel_type`.

**Một ngoại lệ:** `close_iap` chỉ tự bắn khi paywall mở bằng
`VTIAPScreenView(placement:onClose:)`. Tự present bằng đường khác thì phải gọi
`viewModel.trackCloseIAP()` khi đóng.

Đừng khai lại event IAP trong bảng analytics của app — sẽ thành hai nguồn cho cùng
một con số.

## Default Remote Config

`iap_placement_config` phải có trong `remote_config_defaults.plist`, cùng lý do như
ads: phiên chưa fetch xong mà không có default thì **paywall trắng ở màn IAP của
luồng startup** — đúng màn có tỉ lệ mua cao nhất.

Ngoại lệ: key Remote Config đã có **fallback local trong code** (ảnh/video paywall
đóng kèm bản build) thì không cần default — phiên chưa fetch vẫn có đúng nội dung.
Key không có fallback thì phải có default.

```bash
./tools/check-monet-config.sh
```

Nó chạy trong `./tools/verify.sh` và kiểm cả `monet_sdk_config` của ads.

## Không tự làm

- **Không dùng API trong `docs/IAP_GUIDE.md`** nếu chưa kiểm version — xem mục
  đầu. Code sẽ trông đúng và không compile.
- **Không tự gọi StoreKit** (`Product.products(for:)`, `Transaction.updates`,
  `purchase()`). SDK đã sở hữu chúng; một listener thứ hai là một giao dịch được
  finish hai lần.
- **Không tự nghĩ product ID.** Gói do PO cấp và phải khớp App Store Connect. Một
  ID sai chỉ là một gói không hiện, trông hệt như paywall lỗi.
- **Không tự bắn event IAP** — SDK đã bắn, trừ `trackCloseIAP()`.
- **Không đặt `default_selected` là 0.** Nó **1-based**; `0` bị SDK kẹp lên `1`,
  nhưng người đọc config sau bạn sẽ tưởng nó là index.
- **Không tự cấp quyền premium** bằng một cờ riêng trong `UserDefaults`. Hai nguồn
  chân lý cho "user đã mua chưa" thì cái sai sẽ là cái bị đọc.

## Thêm một placement IAP

1. PO cấp: mở ở đâu, gói nào, thiết kế nào (`screen_code`), có bonus không.
2. Khai entry trong Remote Config **và** trong `remote_config_defaults.plist`.
   Dùng chung gói với placement khác thì chỉ cần `{"placement": "…", "funnel": "…"}`.
3. Thêm hằng số vào bảng placement của app (một `enum`, một file).
4. Thêm dòng vào `references/placements.md`.
5. Mở bằng `VTIAPScreenView(placement:)`.

## Test sandbox — sáu bước tối thiểu

- [ ] Mua subscription → premium on, `payment_result_iap` = Success
- [ ] Kill app ngay sau khi Apple trừ tiền → mở lại vẫn nhận được gói
- [ ] `restore()` trên máy sạch cùng Apple Account → premium on
- [ ] Đóng paywall không mua → `close_iap` có bắn
- [ ] Cancel giữa lúc mua → bonus sheet hiện (nếu placement có `bonus.enabled`)
- [ ] Đổi storefront (US/VN/JP) → `displayPrice` đúng ký hiệu và dấu phân cách

## Sau khi gắn

```bash
./tools/verify.sh
```
