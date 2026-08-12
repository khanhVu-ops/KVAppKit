#!/usr/bin/env bash
#
# A test for the tests: proves each rule in check-arch.sh actually fails when
# violated.
#
# A layering check that quietly stops matching is worse than no check, because
# the green tick then certifies the opposite of what it claims. This introduces
# one real violation per rule, asserts the check fails, and restores the file.
#
# Run it whenever check-arch.sh changes. It is cheap — a few seconds.

set -uo pipefail
cd "$(dirname "$0")/.."

pass_count=0 fail_count=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# probe <rule name> <file> <line to append>
probe() {
    local name="$1" file="$2" line="$3"
    cp "$file" "$tmp/backup"
    printf '\n%s\n' "$line" >> "$file"
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m %s — vi phạm KHÔNG bị bắt\n' "$name"
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m %s\n' "$name"
        pass_count=$((pass_count + 1))
    fi
    cp "$tmp/backup" "$file"
}

# probe_prepend <rule name> <file> <line to prepend>
probe_prepend() {
    local name="$1" file="$2" line="$3"
    cp "$file" "$tmp/backup"
    printf '%s\n%s' "$line" "$(cat "$file")" > "$file"
    if ./tools/check-arch.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m %s — vi phạm KHÔNG bị bắt\n' "$name"
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m %s\n' "$name"
        pass_count=$((pass_count + 1))
    fi
    cp "$tmp/backup" "$file"
}

echo "Kiểm tra check-arch.sh có thật sự bắt được vi phạm:"
echo

# Baseline: phải sạch trước khi thử, nếu không kết quả vô nghĩa.
if ! ./tools/check-arch.sh >/dev/null 2>&1; then
    echo "Repo đang có vi phạm sẵn — sửa trước rồi chạy lại self-test."
    exit 1
fi

probe_prepend "1 · Domain import framework" \
    Domain/Entities/Order.swift "import SwiftUI"

probe "2 · Domain dùng type của Data" \
    Domain/Entities/User.swift "func __probe() { _ = OrderDTO.self }"

probe "3 · Feature dùng type của Data" \
    Features/Order/OrderRoute.swift "func __probe() { _ = OrderRepository.self }"

# Probe phải là code thật, không phải comment — rule 4 cố tình bỏ qua comment.
probe "4 · ViewModel gọi pushView" \
    Features/Order/OrderList/OrderListViewModel.swift \
    "func __probe() { router.pushView { } }"

probe "5 · Transport type lọt ra Feature" \
    Features/Order/OrderRoute.swift "func __probe() -> KVAPIClientError? { nil }"

probe "6 · Color literal trong Feature" \
    Features/Order/OrderList/OrderRows.swift "let __probe = Color(red: 1, green: 0, blue: 0)"

probe "7 · View con giữ ViewModel" \
    Features/Order/OrderList/OrderRows.swift \
    "struct __Probe: View { let viewModel: OrderListViewModel; var body: some View { EmptyView() } }"

probe "8 · Dependency key ngoài DI/" \
    Features/Order/OrderRoute.swift \
    "enum __ProbeKey: KVDependencyKey { static let liveValue = 0 }"

echo
if [ "$fail_count" -gt 0 ]; then
    printf '\033[31m%d/%d luật không bắt được vi phạm.\033[0m\n' "$fail_count" "$((pass_count + fail_count))"
    exit 1
fi
printf '\033[32mCả %d luật đều bắt được vi phạm.\033[0m\n' "$pass_count"
