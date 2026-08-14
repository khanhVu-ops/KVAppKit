# Checklist review

Chạy `./tools/verify.sh` trước. Nó lo build + test + `check-arch.sh`. Phần dưới
là những thứ script không kiểm được.

## Phân tầng
- [ ] File mới nằm đúng tầng theo bảng quyết định trong SKILL.md
- [ ] `Domain` không có import mới nào ngoài Foundation
- [ ] Lỗi mới được map trong `AppError+Network.swift`, không lọt thô ra ngoài
- [ ] Use case mới thật sự có logic; nếu chỉ forward, đã bỏ đi

## State
- [ ] `State` là `Equatable`, derived là computed, không có field lưu song song
- [ ] `send(_:)` là đường duy nhất `state` đổi; `state` là `private(set)`
- [ ] Alert/sheet là state, không phải effect
- [ ] `.cancelled` không hiện gì; `.unauthorized` không xử lý tại màn
- [ ] Màn có nội dung thì lỗi refresh ra toast/alert, không thay bằng trang lỗi

## iOS 16
- [ ] View con nhận value + closure, không nhận ViewModel
- [ ] View con nhiều property đã `Equatable` với `nonisolated static func ==`
- [ ] TextField không bind thẳng qua `send` từng ký tự
- [ ] Không có `ObservableObject` nào bị nhiều màn cùng observe

## Navigation
- [ ] Màn mới chỉ có route nếu thật sự cần addressable
- [ ] ViewModel không `import KVRouterKit`, không gọi `pushView`
- [ ] Route mới đã register trong `AppRoutes.swift`
- [ ] Destination không capture state thay đổi được
- [ ] Route mới cần deep link thì đã có trong `AppDeepLink` **và** `stack(for:)`

## Preview
- [ ] Mỗi `struct … : View` mới có `#Preview` (luật 11, `check-arch.sh` fail nếu thiếu)
- [ ] Preview dùng mock từ `Fixtures.swift`, không gọi mạng
- [ ] Màn có nhiều trạng thái thì có nhiều preview: rỗng, lỗi, đang tải
- [ ] Ít nhất một preview cho trạng thái khó dựng bằng tay (ngôn ngữ khác, tên dài, dark)

## Text
- [ ] Chuỗi user-facing mới có trong **cả 19** `<lang>.lproj/Localizable.strings`
- [ ] Key là chuỗi English, không phải identifier; có `comment`
- [ ] Text sinh ngoài View mang `LocalizedStringResource`, **không** `String(localized:)`
- [ ] Đếm số dùng plural variant, không nối `"\(n) orders"`
- [ ] Số/ngày/tiền qua `Text(value, format:)`, **không** `.formatted(...)`
- [ ] Chuỗi không dịch (mã đơn, số) khai `Text(verbatim:)`
- [ ] Có xoá dòng tương ứng trong `tools/l10n-baseline.txt` nếu vừa trả một nợ

## Logging & privacy
- [ ] Dữ liệu nhạy cảm ở `metadata` với `.private`, không nội suy vào message
- [ ] Key metadata mới đã thêm vào allowlist của `PrivacyProcessor` nếu cần giữ
- [ ] Không log associated value của route trong middleware

## Test
- [ ] Tối thiểu: 1 repository, 1 VM happy, 1 VM error
- [ ] Có ít nhất một assert **phủ định** (không điều hướng / không toast)
- [ ] Không `Task.sleep` để chờ state — dùng `waitForLoad()` hoặc spy đồng bộ
- [ ] `testValue` đã khai cho key mới

## Trước khi nói "xong"
- [ ] Đã chạy `./tools/verify.sh` và nó pass
- [ ] Đã chạy app thật xem màn đó (skill `ios-verify`), không chỉ test xanh
