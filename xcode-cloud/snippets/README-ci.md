## CI/CD — Xcode Cloud

Build, test và đẩy TestFlight chạy trên **Xcode Cloud** của team cá nhân **Van Khanh Vu
(`W3274W2Y83`)**. Không có fastlane, GitHub Actions hay runner self-hosted: Xcode Cloud tự
quản chứng chỉ phân phối và profile, nên không có `.p12` hay API key nào phải giữ trên máy.

| Workflow (đặt trong Xcode) | Khi nào | Làm gì |
|---|---|---|
| **Verify** | push `main`, mọi PR | `ci_scripts/ci_post_clone.sh` (luật nhanh trong `app_post_clone.sh`) → Test |
| **Release** | bấm *Start Build*, hoặc push tag `v*` | Archive (Release) → TestFlight, nhóm tester nội bộ. Không tự submit review |

`ci_post_clone.sh` và `ci_post_xcodebuild.sh` là bản chung của mọi app cá nhân (nguồn:
KVAppKit `xcode-cloud/`), đừng sửa riêng ở đây; việc riêng của app đặt trong
`ci_scripts/app_post_clone.sh`. "What to Test" trên TestFlight tự lấy từ 10 commit gần
nhất, trừ khi commit `TestFlight/WhatToTest.en-US.txt` (`git add -f`).

**Version.** Marketing version (`1.0`, `1.1`…) sửa tay ở target → General → Version, rồi
commit. **Build number do Xcode Cloud tự đánh** khi archive; số tiếp theo đặt ở App Store
Connect → Xcode Cloud → Settings → Build Number. Số trong project chỉ dùng cho build local.

**Package.** Xcode Cloud không tự resolve Swift package: đổi dependency thì commit
`Package.resolved` cùng commit đó.

