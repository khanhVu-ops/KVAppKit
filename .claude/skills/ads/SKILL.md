---
name: ads
description: >-
  Gắn quảng cáo VTMonetSDK vào app — banner, native, interstitial, rewarded. Dùng
  khi task nhắc "ads", "quảng cáo", "monetize", một tên placement (`*_na`, `*_ban`,
  `*_in`), một dòng trong bảng kịch bản ads, hoặc khi phải preload ad trước một
  màn. Cũng dùng khi cần cài VTMonetSDK vào một repo vừa init — KVAppBase không
  có SDK này sẵn.
---

# Gắn ads bằng VTMonetSDK

SDK lo load, cache, reload định kỳ, fallback giữa format, retry và nhịp hiển thị.
Việc của app chỉ có hai:

1. **Đặt view vào đúng vị trí** kịch bản nói.
2. **Truyền đúng `name`** — tên placement lấy từ `references/placements.md`.

Không có việc thứ ba. Nếu đang định viết logic load, đếm thời gian, thử lại, hay
đổi format khi trượt — dừng lại, SDK đã có.

## Bước 0 · Cài SDK (repo vừa init thì chưa có)

KVAppBase **không** mang VTMonetSDK. Một repo vừa `init-base` không có pod, không
có `remote_config_defaults.plist`, không có lời gọi init nào. Bốn việc:

1. **Podfile** — SDK phát hành dạng binary pod, không phải SPM:

   ```ruby
   platform :ios, '16.0'

   target '<AppTarget>' do
     use_frameworks!
     pod 'VTMonetSDKBinary',
         :git => 'git@github.com:Varmeta-App/IOS-VTMonet-Realease.git',
         :tag => '<version>'

     target '<AppTarget>Tests' do
       inherit! :search_paths
     end
   end
   ```

   Pin bằng `:tag`, không `~>`: SDK này đổi API giữa các minor (`VTNativeAdState`
   từ enum thành `AdSlotState<NativeCoreAd>` ở 2.1, `ignoreShowInterAds` biến mất).
   Version mới nhất xem tag của repo release.

2. **`pod install`, rồi mở `.xcworkspace`** — không phải `.xcodeproj` nữa.

   > **Bẫy của XcodeGen.** Repo này sinh project từ `project.yml`, và mỗi lần
   > `xcodegen` chạy là pod integration bị xoá sạch — build lỗi "module not
   > found" về một pod vẫn đang nằm trong `Pods/`. Sau **mọi** lần regenerate
   > phải `pod install` lại. Đây là lý do có project đã bỏ XcodeGen hẳn khi thêm
   > CocoaPods; nếu app sắp có nhiều pod thì cân nhắc bỏ luôn thay vì trả giá này
   > mỗi ngày.

3. **`GoogleService-Info.plist` + `remote_config_defaults.plist`** vào
   `App/Resources/`, và **thêm cả hai vào target**. SDK tự gọi
   `FirebaseApp.configure()` khi thấy `GoogleService-Info.plist`; thiếu file thì
   nó log warning và bỏ qua, không crash — nên thiếu là im lặng.

4. **Init trong AppDelegate**, một lần:

   ```swift
   MonetSDKController.shared.initSDKController(
       appleAppId: "<app store id, chỉ số>",
       subscriptionPackages: [],
       inAppPackages: [],
       launchOptions: launchOptions
   )
   ```

   Và ở màn splash, chờ Remote Config trước khi vào app:

   ```swift
   MonetSDKController.shared.initSplash { /* điều hướng vào main */ }
   ```

   `initSplash` có timeout riêng (mặc định 20s) và **luôn** gọi callback — kể cả
   khi fetch trượt. Đừng thêm timeout thứ hai bọc ngoài.

**Đừng gọi `FirebaseApp.configure()` ở app.** `initSDKController` đã gọi. Gọi lần
hai là một cảnh báo cộng một `FIRApp` bị thay giữa chừng.

```swift
@preconcurrency import VTMonetSDK
```

`@preconcurrency` là bắt buộc: repo bật `SWIFT_STRICT_CONCURRENCY: complete` và
SDK chưa audit Sendable.

## Bốn công thức

### 1 · Banner

```swift
SwiftUIBannerView(name: "home_ban")
```

Đặt ở đúng chỗ kịch bản ghi (đáy màn, đỉnh màn, trong sheet). Hết.

### 2 · Native

```swift
SwiftUINativeView(name: "home_na")
```

Cỡ native (90pt, 140pt, 250pt, full…) do Remote Config quyết, không phải code.
Đừng truyền chiều cao, đừng bọc trong `.frame(height:)`.

### 3 · Interstitial

```swift
// callback
VTInterstitialAdsManager.shared.tryShowInterstitialOnNavigation(name: "inapp_in") {
    router.push(NextRoute())
}

// async/await
await VTInterstitialAdsManager.shared.tryShowInterstitialOnNavigationAsync(name: "inapp_in")
router.push(NextRoute())
```

`completion` **luôn** chạy — cả khi ad không hiện (chưa tới nhịp, chưa load xong,
user premium). Nên cứ đặt điều hướng vào đó; không cần kiểm tra gì trước.

Bản `async` là `@MainActor`. `name` phải là một space có thật trong
`ads_inter.spaces` — tên mặc định của SDK là `"inapp_in"`.

### 4 · Rewarded

```swift
MonetSDKController.shared.loadAndShowRewardedAd { earned in
    guard earned else { return }
    // mở tính năng
}
```

Một lời gọi làm hết: hiện loading → load → show → gọi lại. Muốn đổi chữ loading
hoặc chạy việc sớm ngay lúc nhận thưởng:

```swift
MonetSDKController.shared.loadAndShowRewardedAd(
    options: VTRewardAdLoadOptions(
        loadingMessage: "Loading ads...",
        onUserEarnedReward: { /* bắn trước khi ad đóng */ }
    )
) { earned in ... }
```

`earned == true` cũng xảy ra khi user đã mua premium — không có ad để xem thì coi
như đủ điều kiện. Đúng cho một cổng mở tính năng, sai nếu đang đếm impression.

## Preload

Kịch bản viết "preload trước màn X", "preload khi click Y" → gọi ở đúng chỗ đó:

```swift
MonetSDKController.shared.loadBanner(name: "home_ban")
MonetSDKController.shared.loadNative(name: "home_na")
MonetSDKController.shared.loadInterstitial()
MonetSDKController.shared.loadRewardedAd()
```

> Hàm preload tên là **`loadBanner` / `loadNative`**, không phải
> `preloadBanner` / `preloadNative` — hai tên sau không tồn tại (đã kiểm tới
> 2.1.2-rc).

Kịch bản **không** nói preload thì không gọi: view tự load khi xuất hiện.

## Reload

Kịch bản viết "reload khi chuyển tab", "reload khi bấm next":

```swift
MonetSDKController.shared.reloadNative(name: "home_na")
MonetSDKController.shared.reloadBanner(name: "home_ban")
```

Gọi từ **View**, tại đúng hành động đó — không gọi trong `ViewModel` (ViewModel ở
kiến trúc này không biết `MonetSDKController`), và không gọi trong `onAppear` (một
màn `onAppear` lại mỗi lần cuộn về hoặc quay lại từ màn sau).

## Bốn luật khi đặt view

### 1 · Ads không che CTA

Nút chính của màn thường dán đáy. Ad đáy phải nằm **cùng `VStack`** với nút, không
phải `.overlay(alignment: .bottom)`.

Màn có **cả** native đáy **và** banner đáy: banner dưới cùng, native trên banner,
nút trên native. Nút không được nằm giữa hai ad.

### 2 · Một `name` = một ad đang sống

SDK cache theo `name`. Hai view cùng một `name` hiện cùng lúc thì chia nhau **một**
ad: cùng creative hai chỗ, và attach/detach của hai view tranh nhau một delegate.

Cần nhiều ad cùng lúc (ads chèn trong danh sách) thì cần **nhiều `name`** —
`feed_na`, `feed_na2`, `feed_na3` — và mỗi tên là một space trong Remote Config.

### 3 · Ads trong sheet làm sheet cao lên

Sheet cao theo nội dung thì thêm native là thêm chiều cao. Kiểm lại sheet còn hiện
đủ nút hay không, trên máy nhỏ nhất.

### 4 · Preview vẫn phải có

Luật preview của repo: mọi `struct … : View` cần `#Preview`. Ad view trong preview
không vẽ gì (không có SDK đã init) — **đó là bình thường, không phải lỗi**, và
không phải lý do bỏ preview. Preview vẫn cho thấy bố cục phần còn lại.

## Không tự làm

- **Không tự thêm điểm ads.** Không có dòng trong `references/placements.md` →
  hỏi, đừng gắn. Một điểm ads không ai duyệt thì gỡ ra khỏi review khó hơn là
  không gắn.
- **Không tự nghĩ ad unit ID** (`ca-app-pub-…`). Placement chuẩn do PO / team ads
  cấp. Một ID gõ sai chỉ là một ad không bao giờ load, trông hệt như code sai.
  Ngoại lệ duy nhất là config test ở mục dưới — dùng nguyên nó, đừng bịa ID mới.
- **Không tự chọn cỡ native** hay vị trí top/bottom của banner — cả hai nằm trong
  Remote Config (`type`, `banner_position`), team ads đổi được mà không cần build.
- **Không tự viết** fallback native→banner, retry, timer reload. SDK làm hết theo
  cấu hình.

## Default Remote Config — bắt buộc, không phải tuỳ chọn

`<App>/Resources/remote_config_defaults.plist` là **giá trị dùng khi chưa fetch
được Remote Config**: lần mở app đầu tiên, máy mất mạng, fetch timeout, hoặc
Firebase chưa activate xong. SDK nạp nó qua
`setDefaults(fromPlist: "remote_config_defaults")`.

Placement chỉ có trên Firebase mà không có trong plist thì **mọi phiên chưa fetch
xong đều không có ad ở điểm đó**. Đây là loại lỗi không ai thấy khi test: máy dev
luôn có mạng, và `minimumFetchInterval = 0` nên fetch gần như luôn thành công.
Người dùng thật ở mạng chậm mất doanh thu nguyên phiên đầu — phiên có tỉ lệ xem ad
cao nhất.

**Tên file không được đổi**: `setDefaults(fromPlist:)` tìm đúng chuỗi
`remote_config_defaults`. Không phải `default_remote_config.plist`.

### Sửa thế nào

Giá trị `monet_sdk_config` là **một chuỗi JSON** trong plist. Sửa bằng text editor,
đừng mở bằng property-list editor của Xcode — Xcode nén JSON thành một dòng và cả
file thành một diff không đọc được.

Thêm một native space:

```json
{
  "type": "360x140_cta_bot",
  "name": "home_na",
  "admob_id_1": "ca-app-pub-…",
  "admob_id_2": "ca-app-pub-…",
  "admob_id_3": "ca-app-pub-…",
  "is_enable": true,
  "time_auto_reload": 15000
}
```

Thêm một banner space:

```json
{
  "type": "banner_adaptive",
  "name": "home_ban",
  "banner_position": "bottom",
  "admob_id_1": "ca-app-pub-…",
  "admob_id_2": "ca-app-pub-…",
  "admob_id_3": "ca-app-pub-…",
  "is_enable": true,
  "time_auto_reload": 10000
}
```

Thêm một space interstitial (`ads_inter.spaces` — chỉ tên + cờ bật, ad unit dùng
chung ở cấp `ads_inter`):

```json
{ "name": "inapp_in", "is_enable": true }
```

Giá trị hợp lệ cho `type`:

- native: `360x90_cta_right` · `360x140_cta_bot` · `360x176_cta_right` ·
  `360x230_cta_bot` · `360x250_cta_bot` · `360x360_cta_bot` · `full` ·
  `native_collapsible_360x140` · `native_collapsible_360x176` ·
  `native_collapsible_close_360x360`
- banner: `banner_adaptive` · `banner_inline` · `banner_collapsible_top` ·
  `banner_collapsible_bottom`
- `banner_position`: `top` · `bottom` (thiếu thì `bottom`)

Cỡ native `360x90` và `360x140` **không có media** (ảnh/video) — chúng là
text + icon + CTA. Đó là cỡ dùng ở đáy màn có nút; cỡ có media thì để ở khe rộng.

### Config test để chạy trên máy

`tools/ads-test-config.json` là một `monet_sdk_config` chạy được, toàn
bộ dùng **ad unit test công khai của Google**, gồm các điểm intro của SDK (splash ·
language · onboarding) cộng vài điểm mẫu trong app.

```bash
tools/ads-test-config.sh
```

```bash
tools/ads-test-config.sh --restore
```

Script tự tìm `remote_config_defaults.plist` trong repo, ghi vào đó và để lại
`.plist.bak`.

**Đừng commit kết quả lên nhánh release.** Một build mang ID test chạy hoàn toàn
bình thường — ad hiện, layout đúng, không lỗi nào — và không có doanh thu. Nó
không tự báo, nên chỉ lộ ra ở báo cáo cuối tháng.

Thêm điểm của app vào file test bằng đúng khuôn ở trên; ID test giữ nguyên.

### Kiểm lại sau khi sửa

Thiếu một dấu phẩy thì `monet_sdk_config` **parse trượt toàn bộ** — không phải mất
một placement, mà mất cả cấu hình ads, và không có log nào ở tầng app.

```bash
tools/check-monet-config.sh
```

## Tracking impression

SDK **không** log event Firebase cho ads — ad revenue chỉ đi sang AppsFlyer. Cột
"Tracking" trong bảng kịch bản vì thế là việc của app. Cần thì lấy qua callback có
sẵn của view:

```swift
SwiftUINativeView(name: "home_na") { state in
    guard state.hasImpressed else { return }
    analytics.log(.init("home_na"))
}
```

Tên placement nên hợp luật Firebase (`[a-z][a-z0-9_]{0,39}`) để tên event = tên
placement, không phải dịch qua một bảng thứ hai. Chỉ gắn khi kịch bản yêu cầu —
mặc định là không gắn.

## Thêm một placement mới

Bốn bước, không đảo thứ tự:

1. Team ads khai space trong Remote Config `monet_sdk_config` và cấp ad unit ID.
2. **Thêm đúng space đó vào `remote_config_defaults.plist`.** Bắt buộc, không phải
   bước dọn dẹp để sau.
3. Thêm dòng vào `references/placements.md`.
4. Đặt view với `name` đó.

View có `name` chưa khai ở đâu cả thì SDK log `Config not found - name: …` và
không hiện gì — không crash, không cảnh báo lúc build.

## Sau khi gắn

```bash
./tools/verify.sh
```
