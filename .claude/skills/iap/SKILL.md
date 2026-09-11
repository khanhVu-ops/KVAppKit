---
name: iap
description: >-
  Gắn luồng IAP của VTMonetSDK vào app: mở paywall, hiển thị gói/giá/trial, gate
  tính năng premium, và khi app có backend thì verify giao dịch để cấp token hoặc
  credit. Dùng khi task nhắc "IAP", "paywall", "premium", "subscription",
  "consumable", "mua gói", "restore", "trial", "giá fake", "verify giao dịch",
  "entitlement", một tên placement IAP, một `screen_code` (`IAP1`, `IAP2`…), hoặc
  khi phải sửa `iap_placement_config`. Cũng dùng khi dựng paywall đầu tiên cho một
  repo vừa init — KVAppBase không có VTMonetSDK sẵn.
---

# IAP bằng VTMonetSDK

SDK sở hữu StoreKit: load sản phẩm, mua, restore, tính eligibility trial, cấp và
thu hồi entitlement, retry giao dịch dở dang, bắn gần hết event analytics.

Chọn một trong hai case, rồi chỉ làm đúng phần của case đó:

| | **`.local`** | **`.server`** |
|---|---|---|
| Khi nào | app không có backend, bán subscription / unlock | app có API verify riêng, cấp token hoặc credit theo gói |
| Cấp quyền | ngay trên máy sau khi StoreKit xác thực | sau khi server verify với Apple và ghi nhận |
| App phải viết | **3 việc** (§1) | 3 việc đó **+ `configure`** (§2) |

Cài SDK (repo vừa `init-base` thì chưa có): **Bước 0** trong skill `ads` — Podfile,
`pod install`, `GoogleService-Info.plist`, `initSDKController`, và màn đầu là
`VTSplashScreenView`. Hai tham số `subscriptionPackages:` / `inAppPackages:` của
`initSDKController` SDK không đọc — truyền `[]`; danh sách gói thật nằm ở
`product_ids` trong config.

## Cổng version

`.server`, `VTIAPDelegate`, `activeOffer`, `priceInfo`, `fake_price`,
`.pendingServerVerification` chỉ có trên nhánh **`dev_iap`** của SDK, và nhánh đó
chưa merge vào `dev`/`release`. Số version không nói lên điều gì (tag tới `2.0.2`,
file version ghi `1.3.6`, doc ghi "1.4.0") — kiểm bằng symbol:

```bash
find Pods/VTMonetSDKBinary -name '*.swiftinterface' -exec grep -l 'enum VTMonetIAP' {} +
```

Không ra gì thì binary đang pin chỉ làm được §1, và `isTrial` ở bản đó nghĩa là
"**sản phẩm** có trial" chứ không phải "**user** còn được trial" — đó là bug "hết
trial vẫn hiện Free Trial", và nó chỉ sửa được bằng nâng SDK.

## §1 · Ba việc cho mọi app

Đây là toàn bộ phần `.local`. **Không gọi `VTMonetIAP.configure` thì SDK chạy
`.local`** — không cần khai gì thêm: không delegate, không `userID`, không verify,
không tự gọi `syncEntitlement()` (SDK đã chạy lúc init và mỗi lần foreground).

Ngoại lệ duy nhất: `.local` mà **bán consumable** thì vẫn cần một delegate để cộng
credit trong `iapDidDeliverConsumable`, và app **tự chống trùng** bằng cách lưu các
`transactionID` đã xử lý — StoreKit gửi lại transaction là chuyện bình thường.
Cách khai delegate xem §2.2.

### 1.1 Khai placement

`iap_placement_config` — một JSON array, phải có **cả** trên Firebase Remote Config
**và** trong `<App>/Resources/remote_config_defaults.plist`. Phiên đầu chưa fetch
xong mà thiếu default thì paywall của luồng startup rỗng — đúng màn bán được nhiều
nhất. Plist là đường **duy nhất** để có default (`registerDefaults` của SDK không
gọi được từ app).

```json
[
  {
    "placement": "iap_ob",
    "screen_code": "IAP1",
    "product_ids": ["com.app.weekly", "com.app.yearly"],
    "default_selected": 1,
    "badge_product_id": "com.app.yearly",
    "delay_can_dismiss": 3000,
    "fake_price": { "com.app.yearly": { "multiplier": 2.5, "rounding": "pretty" } },
    "bonus": { "enabled": true, "product_ids": ["com.app.weekly"], "default_selected": 1 }
  },
  { "placement": "setting", "funnel": "iap_ob" }
]
```

| Key | Bắt buộc | Thiếu thì |
|---|---|---|
| `placement` | **có** | **cả mảng decode trượt** — mọi paywall của app rỗng |
| `screen_code` | không | `"IAP1"` |
| `product_ids` | không | `[]` → paywall không có gói nào |
| `default_selected` | không | `1` (**1-based**, không phải index; `0` bị kẹp lên `1`) |
| `badge_product_id` | không | gói đang chọn |
| `delay_can_dismiss` | không | `0` — nút X hiện ngay |
| `fake_price` | không | không có giá gạch ngang |
| `bonus.enabled` | không | `false` |
| `funnel` | không | = chính placement |

`funnel` làm hai việc: **alias trỏ sang config của placement khác**, và
`funnel_type` trong analytics. `{"placement": "setting", "funnel": "iap_ob"}` nghĩa
là `setting` dùng gói + `screen_code` của `iap_ob` và gom về funnel `iap_ob`. Đây
là cách đúng khi nhiều điểm mở bán cùng bộ gói: **đổi gói là sửa một entry, không
phải mười.** Trỏ vào placement không tồn tại thì SDK lặng lẽ giữ config của chính
entry đó — thiết kế vẫn vẽ ra, không có gói nào để mua.

### 1.2 Đăng ký thiết kế cho `screen_code`

```swift
struct PaywallScreen001: View {
    @ObservedObject var viewModel: VTIAPViewModel
    @Environment(\.vtIAPScreenOnClose) private var onClose
    …
}

// App.init — composition root:
VTIAPScreenRegistry.shared.registerIAPView(screenCode: VTIAPScreenCode.iap1) { vm in
    PaywallScreen001(viewModel: vm)
}
```

Đổi `screen_code` trên Firebase là **A/B một thiết kế paywall** mà không release.

**Đăng ký ở `App.init`, không phải `onAppear` của một màn** — kể cả khi app demo
của SDK làm thế. `VTIAPScreenView` tra registry lúc nó hiện ra, và paywall mở được
từ deep link, restoration, nút premium ở Settings. Registry rỗng lúc đó là một
`ProgressView` quay mãi, không phải crash, nên test không bắt được.

### 1.3 Mở paywall và gate premium

```swift
.fullScreenCover(isPresented: $showPaywall) {
    VTIAPScreenView(placement: IAPPlacement.setting) {
        showPaywall = false
    }
}
```

`onClose` là chỗ app đóng màn. SDK bọc closure này lại nên `close_iap` **tự bắn**,
và tự bỏ qua khi user đã mua hoặc đã restore — app không gọi gì thêm. Truyền `nil`
thì thiết kế đọc `\.vtIAPScreenOnClose` ra `nil` và hiểu là "màn này không có nút
đóng". Tham số `strings:` hiện bị SDK bỏ qua — copy đi vào thiết kế.

Gate: **không đọc `MonetSDKController` từ `Features/`.** Đi qua một cổng ở
`Domain/Services` (cùng khuôn `ToastService`), `Data` hiện thực bằng
`MonetSDKController.shared.isPurchased` (`@Published`) — như vậy màn test được với
stub, và luật 3 của `check-arch.sh` vẫn đúng. Cần biết lúc nó đổi ngoài binding thì
nghe `Notification.Name.vtPremiumStatusDidChange`, đừng poll.

### Bề mặt gọi được ở §1

| Việc | API |
|---|---|
| Mở paywall | `VTIAPScreenView(placement:onClose:)` |
| Đăng ký thiết kế | `VTIAPScreenRegistry.shared.registerIAPView(screenCode:) { vm in … }` |
| Đóng từ trong thiết kế | `@Environment(\.vtIAPScreenOnClose)` |
| Trạng thái + hành động | `VTIAPViewModel`: `state`, `purchaseState`, `products`, `bonusProducts`, `selectedIndex`, `selectedProduct`, `selectedBonusIndex`, `badgeProductID`, `delayCanDismiss`, `showBonus`, `hasBonus`, `purchaseSelected()`, `purchase(productID:)`, `restore()`, `dismissBonus()`, `trackCloseIAP()` |
| Sản phẩm | `VTIAPProductModel`: `productID`, `period`, `displayPrice`, `priceInfo`, `activeOffer`, `isTrialAvailable`, `fakeDisplayPrice`, `pricePerWeek`, `displayPricePerWeek`, `savingsPercent`, `title`, `rawProduct` |
| Gate premium | `MonetSDKController.shared.isPurchased`, `.hasIAPPlacement(named:)`, `Notification.Name.vtPremiumStatusDidChange` |

## §2 · Thêm gì khi app có backend (`.server`)

Chỉ làm phần này khi server thật sự cần biết giao dịch — cấp token theo gói, giữ
số dư consumable, hoặc chống gian lận. Bán subscription thuần thì `.local` là đủ,
và thêm `.server` chỉ thêm một đường hỏng.

### 2.1 `configure` — sớm, một lần, main actor

`VTMonetIAP` là `@MainActor`. Gọi trong `App.init` / `didFinishLaunching`, **trước
khi UI hiện**: StoreKit trả transaction ngay lúc mở app (renew qua đêm, giao dịch
dở dang, Ask to Buy vừa duyệt) và SDK phải biết trước cái nào cần verify.

```swift
VTMonetIAP.configure(
    verification: .server { payload in
        try await MyAPI.verifyIAP(
            transactionID: payload.transactionID,
            environment:   payload.environment      // "Sandbox" | "Production"
        )
        return true
    },
    userID: UUID(uuidString: currentUser.uuid),     // → appAccountToken
    delegate: iapHandler
)

// Sau login đổi user:
VTMonetIAP.setUserID(UUID(uuidString: newUser.uuid))
```

**Ba nhánh của closure — đây là chỗ sai đắt nhất:**

| Closure | SDK làm gì |
|---|---|
| `return true` | cấp quyền, `finish()` |
| `return false` | `finish()` nhưng **không** cấp quyền — giao dịch coi như không hợp lệ |
| `throw` | **không** `finish()` → StoreKit gửi lại, SDK verify lại lúc foreground |

Mạng lỗi mà `return false` là user trả tiền xong rồi mất gói vĩnh viễn. Lỗi tạm
phải `throw`. Và vì `throw` dẫn tới gửi lại, **server phải idempotent theo
`transactionID`**.

Chỉ verify một phần: `.server(shouldVerify: { $0.productType == .consumable }) { … }`
— gói còn lại chạy như `.local`.

`userID` được gắn vào purchase làm `appAccountToken` và nằm trong dữ liệu Apple ký,
nên server đọc được nó cả trong App Store Server Notifications — đó là cách sạch
nhất map renew/refund về user.

### 2.2 Delegate

Không bắt buộc (mọi method có default rỗng), và SDK giữ **weak** — phải có một
object sống bằng vòng đời app giữ nó, không phải một ViewModel.

```swift
final class IAPHandler: VTIAPDelegate {
    func iapDidDeliverConsumable(productID: String, transactionID: String) {
        Task { await MyAPI.syncCredits() }      // server đã credit → fetch lại
    }
    func iapDidRevokeEntitlement(productID: String, transactionID: String) {
        Task { await MyAPI.syncCredits() }      // refund
    }
    func iapEntitlementDidChange(_ e: VTIAPEntitlement) { … }
    func iapDidReceiveGrantToken(_ token: String, for productID: String) { … }
}
```

`VTMonetIAP.currentGrantToken` **không sống qua lần mở app sau** — app tự persist.

`VTIAPEntitlement`: `isPremium`, `premiumProductID`, `expirationDate`,
`isInGracePeriod` (**vẫn premium** — Apple đang retry thanh toán), `willAutoRenew`
(`false` = churn, gói còn sống tới `expirationDate`). Đọc qua
`VTMonetIAP.entitlement` (không phải `@Published`), ép sync sau màn restore của
app hoặc sau push từ server: `await VTMonetIAP.syncEntitlement()`.

### 2.3 Hai state phải xử ở UI

| State | Có ở | UI |
|---|---|---|
| `.pending` | cả hai case | Ask to Buy, chờ phụ huynh duyệt — **không phải lỗi**; quyền về sau qua hệ thống |
| `.pendingServerVerification` | chỉ `.server` | **đã trừ tiền**, server chưa ack — "Đang xác nhận giao dịch…"; SDK tự retry khi foreground |

Hiện hai case này thành "Thanh toán thất bại" là cách nhanh nhất nhận một ticket
hoàn tiền cho giao dịch đã thành công.

Còn lại SDK lo: renew, refund, expired, grace period, app chết giữa lúc trả tiền.

## Hiển thị giá — UI chỉ đọc `activeOffer`

`activeOffer` đã nhân sẵn "sản phẩm có offer" × "user này còn được hưởng":

| Trạng thái user | `activeOffer` | UI |
|---|---|---|
| Chưa sub, gói có free trial | `.freeTrial` | "3-day free trial", CTA "Start Free Trial" |
| Chưa sub, gói có offer trả phí | `.payUpFront` / `.payAsYouGo` | "Tuần đầu 19.000đ, sau đó 49.000đ/tuần" |
| Đã dùng trial rồi cancel | `nil` | giá thường, CTA "Continue" |

```swift
if let offer = product.activeOffer {
    switch offer.paymentMode {
    case .freeTrial:
        Text("\(offer.totalDays)-day free trial, then \(product.displayPrice)")
    case .payUpFront, .payAsYouGo:
        Text("First week \(offer.displayPrice), then \(product.displayPrice)")
    }
} else {
    Text(product.displayPrice)
}
Text(product.isTrialAvailable ? "Start Free Trial" : "Continue")
```

`introOffer` / `isEligibleForIntroOffer` là dữ liệu thô — dựng UI trên chúng là
đường dẫn thẳng tới "hết trial vẫn hiện Free Trial".

Giá custom đi qua `product.priceInfo` để đúng **currency + locale của storefront**
(không phải locale máy): `format(_:)`, `formatFake(multiplier:rounding:)`. Có
`fake_price` trong config thì đọc `product.fakeDisplayPrice` — đừng nhân giá trong
View, đó là con số không đổi được từ xa.

## Analytics

SDK tự bắn `show_iap`, `click_subscription`, `click_CTA`, `close_iap`,
`payment_result_iap`, và `view_<placement>` / `view_<placement>_bonus` /
`pur_success_<placement>` cho A/B. Params chung: `placement`, `screen_code`,
`funnel_type`.

`close_iap` đi theo `onClose` của `VTIAPScreenView`, nên nó chỉ hụt khi paywall
đóng mà không qua closure đó: app tự host `VTIAPViewModel` thay vì dùng
`VTIAPScreenView`, hoặc paywall nằm trong `.sheet` và user gạt xuống để đóng. Đúng
hai trường hợp đó mới gọi `viewModel.trackCloseIAP()` — nó tự bỏ qua khi đã mua,
nên không sợ bắn trùng.

Một chỗ hụt, chỉ ảnh hưởng `.server`: `payment_result_iap` chỉ bắn trong luồng mua
tại chỗ, nên giao dịch được ack **về sau** không có Success nào. Tỉ lệ thành công
trên Firebase sẽ thấp hơn doanh thu thật — lấy số từ server, đừng bắn thêm một
event trùng tên.

Cần mirror event sang chỗ khác thì `VTEventTracker.addObserver { name, params in }`
(chạy sau emitter, không chặn được event). Đừng thay `VTEventTracker.emitter` —
đó là chỗ của unit test, thay là mất Firebase.

## Không tự làm

- **Không tự gọi StoreKit** (`Product.products(for:)`, `Transaction.updates`,
  `purchase()`). SDK đã sở hữu chúng; listener thứ hai là một giao dịch bị finish
  hai lần.
- **Không gọi `VTIAPManager` / `VTIAPService`** — hai type đó `internal`, không
  thấy từ app dù member khai `public`. Mua qua `VTIAPViewModel`; `loadPlacements`
  thì `VTSplashScreenView` đã gọi hộ (qua `initSplash`).
- **Không tự cấp quyền premium** bằng một cờ riêng trong `UserDefaults`. Hai nguồn
  chân lý cho "user đã mua chưa" thì cái sai sẽ là cái bị đọc.
- **Không tự nghĩ product ID.** Gói do PO cấp và phải khớp App Store Connect — ID
  sai chỉ là một gói không hiện, trông hệt paywall lỗi.
- **Không khai gói ở hai chỗ.** `product_ids` trong config là nguồn duy nhất.
- **Không `return false` cho lỗi mạng** trong closure verify.
- **Không giữ delegate bằng một ViewModel** — SDK giữ weak.
- **Không coi `currentGrantToken` là chỗ lưu token.**
- **Không tự bắn event IAP.** SDK đã bắn hết, kể cả `close_iap`.

## Thêm một placement

1. PO cấp: mở ở đâu, gói nào, thiết kế nào (`screen_code`), có bonus không.
2. Khai entry trong Remote Config **và** `remote_config_defaults.plist`. Dùng chung
   gói thì chỉ cần `{"placement": "…", "funnel": "…"}`.
3. Thêm hằng số vào bảng placement của app (một `enum`, một file) — SDK **không**
   có sẵn `VTIAPPlacement`, đó là type của app.
4. Thêm dòng vào `references/placements.md`.
5. Mở bằng `VTIAPScreenView(placement:)`.

Tên placement gõ sai **không** báo lỗi: SDK rơi về placement **đầu tiên** trong
mảng, nên paywall vẫn hiện, bán sai gói và log sai funnel. `screen_code` chưa đăng
ký thì ra spinner quay mãi. Cả hai do `./tools/check-monet-config.sh` bắt, và nó
chạy trong `./tools/verify.sh`.

## Test sandbox

Mọi app:

- [ ] Mua subscription → premium on, `payment_result_iap` Success
- [ ] Kill app ngay sau khi Apple trừ tiền → mở lại vẫn nhận được gói
- [ ] `restore()` trên máy sạch cùng Apple Account → premium on
- [ ] Account đã dùng trial → paywall hiện **giá thường**, `activeOffer == nil`
- [ ] Đóng paywall không mua → `close_iap` có bắn
- [ ] Cancel giữa lúc mua → bonus sheet hiện (nếu có `bonus.enabled`)
- [ ] Đổi storefront (US/VN/JP) → giá đúng ký hiệu và dấu phân cách

Thêm khi `.server`:

- [ ] Tắt mạng ngay sau khi thanh toán → `.pendingServerVerification`; bật mạng,
      background rồi mở lại → quyền được cấp
- [ ] Gọi verify 2 lần cùng `transactionID` → server chỉ credit 1 lần
- [ ] Mua consumable → `iapDidDeliverConsumable` đúng 1 lần; mua lại → cộng tiếp
- [ ] Refund → `iapDidRevokeEntitlement` + premium off
- [ ] Ask to Buy (sandbox family) → `.pending`; duyệt → nhận gói

## Sau khi gắn

```bash
./tools/verify.sh
```
