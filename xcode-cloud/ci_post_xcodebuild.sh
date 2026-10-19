#!/bin/sh
#
# Xcode Cloud chạy file này sau mỗi lệnh xcodebuild (build, test, archive).
#
# Bản chung cho mọi app cá nhân. Nguồn gốc: KVAppKit/xcode-cloud/. Đừng sửa riêng ở app.
#
# Việc duy nhất: viết ghi chú "What to Test" cho TestFlight. Xcode Cloud đọc
# TestFlight/WhatToTest.<locale>.txt ở gốc repo khi đẩy bản lên TestFlight.
#   - Repo có commit sẵn TestFlight/WhatToTest.en-US.txt → dùng nguyên file đó.
#   - Không có → lấy tiêu đề 10 commit gần nhất, để tester biết bản này đổi gì.

set -eu

[ "${CI_XCODEBUILD_ACTION:-}" = "archive" ] || exit 0
[ "${CI_XCODEBUILD_EXIT_CODE:-1}" = "0" ] || exit 0

cd "${CI_PRIMARY_REPOSITORY_PATH:?}"

notes="TestFlight/WhatToTest.en-US.txt"
if [ -f "$notes" ] && git ls-files --error-unmatch "$notes" >/dev/null 2>&1; then
    echo "▸ What to Test: dùng $notes đã commit"
    exit 0
fi

mkdir -p TestFlight
# Xcode Cloud clone nông, nên phải đào thêm lịch sử mới có đủ commit để liệt kê.
git fetch --deepen 10 >/dev/null 2>&1 || true
{
    printf 'Build %s · %s · %s\n\n' "${CI_BUILD_NUMBER:-?}" \
        "${CI_BRANCH:-${CI_TAG:-?}}" "$(git rev-parse --short HEAD)"
    git log -10 --no-merges --pretty='• %s'
} | head -c 3900 >"$notes"

echo "▸ What to Test (sinh từ git log):"
cat "$notes"
