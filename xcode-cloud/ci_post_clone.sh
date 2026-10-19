#!/bin/sh
#
# Xcode Cloud chạy file này ngay sau khi clone, TRƯỚC khi resolve Swift package và build.
#
# Bản chung cho mọi app cá nhân (team Van Khanh Vu). Nguồn gốc: KVAppKit/xcode-cloud/.
# Đừng sửa riêng ở từng app, để lần sau chép đè bản mới không mất gì. Việc riêng của
# app (lint, sinh file…) đặt trong ci_scripts/app_post_clone.sh, file này sẽ gọi nó.
#
# Tự nhận diện kiểu project, nên cùng một file chạy được cho:
#   - XcodeGen (có project.yml)    → cài xcodegen, sinh .xcodeproj
#   - CocoaPods (có Podfile)       → pod install
#   - .xcodeproj commit sẵn        → không làm gì thêm
#
# Chạy thử ở máy: CI_PRIMARY_REPOSITORY_PATH="$PWD" ci_scripts/ci_post_clone.sh

set -eu

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

# Brew trên Xcode Cloud tự update và dọn dẹp mỗi lần cài, mất vài phút vô ích.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

step() { printf '\n▸ %s\n' "$1"; }
die()  { printf '\n✗ %s\n' "$1" >&2; exit 1; }

step "Xcode Cloud: ${CI_WORKFLOW:-local} · ${CI_XCODEBUILD_ACTION:-?} · ${CI_BRANCH:-${CI_TAG:-${CI_PULL_REQUEST_SOURCE_BRANCH:-?}}}"
xcodebuild -version | head -1

# Xcode 16+ tách compiler `metal` thành component tải riêng. Thiếu nó thì build fail với
# "cannot execute tool 'metal'", không gợi ý gì về nguyên nhân. Chỉ tải (~700MB) khi repo
# thật sự có shader và máy thật sự thiếu.
if git ls-files -- '*.metal' | grep -q .; then
    if ! xcrun -sdk iphoneos metal --version >/dev/null 2>&1; then
        step "Tải Metal Toolchain"
        xcodebuild -downloadComponent MetalToolchain
    fi
fi

if [ -f project.yml ]; then
    step "XcodeGen"
    command -v xcodegen >/dev/null 2>&1 || brew install xcodegen
    xcodegen generate
fi

if [ -f Podfile ]; then
    step "CocoaPods"
    command -v pod >/dev/null 2>&1 || brew install cocoapods
    pod install
fi

# Xcode Cloud build với `-disableAutomaticPackageResolution`: không có Package.resolved
# thì nó KHÔNG tự resolve mà fail, với thông báo khó hiểu. Kiểm ở đây để lỗi nói đúng
# nguyên nhân. Ưu tiên workspace (CocoaPods), rồi tới project.
container="$(ls -d ./*.xcworkspace 2>/dev/null | head -1)"
[ -n "$container" ] || container="$(ls -d ./*.xcodeproj 2>/dev/null | head -1)"
[ -n "$container" ] || die "Không thấy .xcworkspace hay .xcodeproj ở gốc repo."
case "$container" in
    *.xcworkspace) resolved="$container/xcshareddata/swiftpm/Package.resolved" ;;
    *)             resolved="$container/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ;;
esac
if grep -qs XCRemoteSwiftPackageReference ./*.xcodeproj/project.pbxproj; then
    [ -f "$resolved" ] || die "Thiếu $resolved. Mở project trong Xcode cho nó resolve, rồi commit file này (xem .gitignore nếu .xcodeproj bị ignore)."
    step "Package.resolved: $resolved"
fi

if [ -f ci_scripts/app_post_clone.sh ]; then
    step "Việc riêng của app (ci_scripts/app_post_clone.sh)"
    sh ci_scripts/app_post_clone.sh
fi

step "post-clone xong"
