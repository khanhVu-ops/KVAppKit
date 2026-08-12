#!/usr/bin/env bash
#
# Build + test + kiểm luật kiến trúc. Copy vào tools/ của repo app.
#
# Thứ tự: luật (1 giây) → build module → test → build app. Fail sớm nhất có thể.
#
# Hai điều đã học được khi viết script này, giữ lại kẻo lặp lại:
#  * scheme `AppModules-Package` chỉ tồn tại khi xcodebuild chạy TRONG
#    Packages/AppModules. Chạy ở root thì nó bắt MyApp.xcodeproj và không thấy.
#  * `cmd | grep error: && exit 1` KHÔNG chạy dưới `set -o pipefail`: pipefail
#    trả exit code của cmd (khác 0), nên `&&` không bao giờ fire. Phải kiểm exit
#    code tường minh.

set -uo pipefail
cd "$(dirname "$0")/.."

ROOT="$PWD"
PKG="$ROOT/Packages/AppModules"
SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
DD="${DD:-/tmp/$(basename "$ROOT")-dd}"
FILTER='error:|warning: .*deprecated|Executed [0-9]+ tests|Test Case .* failed|(BUILD|TEST) (SUCCEEDED|FAILED)'

step() { printf '\n\033[1m▸ %s\033[0m\n' "$1"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n' "$1"; exit 1; }

# Runs xcodebuild, shows only the interesting lines, and fails on its real exit
# code rather than on whether grep happened to match.
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

step "Sinh lại project (XcodeGen)"
if command -v xcodegen >/dev/null; then
    xcodegen generate --quiet || die "xcodegen generate thất bại"
    echo "  project đã sinh lại"
else
    echo "  xcodegen chưa cài — bỏ qua (brew install xcodegen)"
fi

step "Build module (iOS, không cần simulator)"
cd "$PKG"
run_xcodebuild "Build module" -quiet -scheme AppModules-Package \
    -destination 'generic/platform=iOS' -derivedDataPath "$DD" build

step "Test"
run_xcodebuild "Test" -scheme AppModules-Package \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DD" test

step "Build app"
cd "$ROOT"
project="$(ls -d ./*.xcodeproj 2>/dev/null | head -1)"
[ -n "$project" ] || die "Không thấy .xcodeproj — chạy xcodegen generate"
scheme="$(basename "$project" .xcodeproj)"
run_xcodebuild "Build app" -quiet -project "$project" -scheme "$scheme" \
    -destination "platform=iOS Simulator,name=$SIMULATOR" \
    -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build

printf '\n\033[32m✓ Tất cả đều xanh.\033[0m\n'
printf '  App: %s\n' "$DD/Build/Products/Debug-iphonesimulator/$scheme.app"
echo "  Bước cuối: mở app trên simulator và xem đúng màn vừa sửa (skill ios-verify)."
