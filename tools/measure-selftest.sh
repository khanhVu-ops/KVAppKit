#!/usr/bin/env bash
#
# Test cho cái cân: chứng minh measure-skill.sh phân biệt được ba kết quả, bằng một
# `claude` giả trả lời theo kịch bản.
#
# Không có file này thì lần đầu chạy đo thật, một lỗi parse trong harness sẽ đọc y
# như "skill không có tác dụng" — và đó là kết luận sai đắt nhất có thể rút ra ở đây.

set -uo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pass_count=0 fail_count=0

# `claude` giả: có --settings nghĩa là "đã tắt skill" → trả lời $STUB_WITHOUT.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/claude" <<'STUB'
#!/usr/bin/env bash
for arg in "$@"; do
    [ "$arg" = "--settings" ] && { printf '%s\n' "${STUB_WITHOUT:-}"; exit 0; }
done
printf '%s\n' "${STUB_WITH:-}"
STUB
chmod +x "$tmp/bin/claude"

# Repo app giả, đủ để qua các guard.
mkdir -p "$tmp/app/.claude/skills/probe"
touch "$tmp/app/project.yml"

printf 'prompt: một prompt\nexpect: KVRouterKit\nreject: import KVRouter$\n---\n' > "$tmp/probe.cases"

# check <tên> <STUB_WITH> <STUB_WITHOUT> <exit code mong đợi> <chuỗi phải thấy>
check() {
    local name="$1" with="$2" without="$3" want_exit="$4" want_text="$5" out code
    out=$(PATH="$tmp/bin:$PATH" STUB_WITH="$with" STUB_WITHOUT="$without" \
          MEASURE_LOG_DIR="$tmp/log" ./tools/measure-skill.sh "$tmp/probe.cases" --in "$tmp/app" 2>&1)
    code=$?
    if [ "$code" = "$want_exit" ] && grep -q "$want_text" <<< "$out"; then
        printf '\033[32m✓\033[0m %s\n' "$name"
        pass_count=$((pass_count + 1))
    else
        printf '\033[31m✗\033[0m %s — exit %s (mong %s), không thấy "%s"\n' \
            "$name" "$code" "$want_exit" "$want_text"
        printf '%s\n' "$out" | sed 's/^/      /'
        fail_count=$((fail_count + 1))
    fi
}

echo "Kiểm measure-skill.sh có phân biệt đúng ba kết quả:"
echo

check "1 · skill có tác dụng (có: đúng, không: sai)" \
    "dùng KVRouterKit nhé" "import KVRouter" 0 "skill có tác dụng"

check "2 · prompt không đo được gì (cả hai đúng)" \
    "dùng KVRouterKit nhé" "cũng KVRouterKit" 1 "không đo được gì"

check "3 · có skill mà vẫn sai" \
    "import KVRouter" "import KVRouter" 1 "CÓ skill mà vẫn sai"

# Guard: thiếu --in, hoặc target không phải repo app, phải chết rõ ràng chứ không
# âm thầm đo trong repo kit.
out=$(PATH="$tmp/bin:$PATH" ./tools/measure-skill.sh "$tmp/probe.cases" 2>&1); code=$?
if [ "$code" = 2 ] && grep -q 'cần --in' <<< "$out"; then
    printf '\033[32m✓\033[0m 4 · thiếu --in thì dừng, không đo bừa\n'
    pass_count=$((pass_count + 1))
else
    printf '\033[31m✗\033[0m 4 · thiếu --in mà vẫn chạy (exit %s)\n' "$code"
    fail_count=$((fail_count + 1))
fi

echo
if [ "$fail_count" -gt 0 ]; then
    printf '\033[31m%d/%d phép kiểm sai.\033[0m\n' "$fail_count" "$((pass_count + fail_count))"
    exit 1
fi
printf '\033[32mCả %d phép kiểm đúng — cái cân dùng được.\033[0m\n' "$pass_count"
