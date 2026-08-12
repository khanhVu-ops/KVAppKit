#!/usr/bin/env bash
#
# Kiểm luật + build + test, một lệnh.
#
# Thứ tự có lý: luật kiến trúc chạy trong một giây, build mất một phút. Fail sớm
# nhất có thể.
#
# Một điều đã học khi viết script này, giữ lại kẻo lặp:
#   `cmd | grep error: && exit 1` KHÔNG chạy dưới `set -o pipefail` — pipefail
#   trả exit code của cmd (khác 0), nên `&&` không bao giờ fire. Phải kiểm exit
#   code tường minh, như run_xcodebuild dưới đây.

set -uo pipefail
cd "$(dirname "$0")/.."

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
DD="${DD:-/tmp/$(basename "$PWD")-dd}"
FILTER='error:|Executed [0-9]+ tests|Test Case .* failed|(BUILD|TEST) (SUCCEEDED|FAILED)'

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n' "$1"; exit 1; }

run_xcodebuild() {
    local description="$1"; shift
    local log="$DD/last-xcodebuild.log"
    mkdir -p "$DD"
    if ! xcodebuild "$@" >"$log" 2>&1; then
        grep -E "$FILTER" "$log" | sort -u | head -30
        die "$description thất bại. Log đầy đủ: $log"
    fi
    grep -E "$FILTER" "$log" | sort -u | head -20
}

step "Luật kiến trúc"
./tools/check-arch.sh || die "Luật kiến trúc bị vi phạm"

step "Self-test cho check-arch"
# Một luật im lặng ngừng khớp còn tệ hơn không có luật, vì dấu tick xanh lúc đó
# chứng nhận điều ngược lại. Rẻ, nên chạy luôn.
./tools/check-arch-selftest.sh || die "check-arch.sh không còn bắt được vi phạm"

step "Sinh lại project (XcodeGen)"
if command -v xcodegen >/dev/null; then
    xcodegen generate --quiet || die "xcodegen generate thất bại"
    echo "  project đã sinh lại"
else
    echo "  xcodegen chưa cài — bỏ qua (brew install xcodegen)"
fi

project="$(ls -d ./*.xcodeproj 2>/dev/null | head -1)"
[ -n "$project" ] || die "Không thấy .xcodeproj — chạy xcodegen generate"
scheme="$(basename "$project" .xcodeproj)"

step "Build + test"
run_xcodebuild "Test" -project "$project" -scheme "$scheme" \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO test

printf '\n\033[32m✓ Tất cả đều xanh.\033[0m\n'
printf '  App: %s\n' "$DD/Build/Products/Debug-iphonesimulator/$scheme.app"
echo "  Bước cuối: mở app trên simulator và xem đúng màn vừa sửa (skill ios-verify)."
