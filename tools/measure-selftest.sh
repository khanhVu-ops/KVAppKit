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
mkdir -p "$tmp/app/Probe.xcodeproj"

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

ok=$'```swift\nimport KVRouterKit\n```'
bad=$'```swift\nimport KVRouter\n```'

check "1 · skill có tác dụng (có: đúng, không: sai)" \
    "$ok" "$bad" 0 "skill có tác dụng"

check "2 · prompt không đo được gì (cả hai đúng)" \
    "$ok" "$ok" 1 "không đo được gì"

check "3 · có skill mà vẫn sai" \
    "$bad" "$bad" 1 "CÓ skill mà vẫn sai"

# Đây là phép kiểm sinh ra từ lần đo thật đầu tiên (14/08), nơi 4/10 case fail giả
# vì `reject:` quét cả văn xuôi: câu trả lời **đúng** của skill là câu gọi tên đúng
# thứ nó khuyên tránh ("chỉ import Foundation, không Decodable"). Regex không phân
# biệt được lời khuyên với vi phạm; code block thì phân biệt được.
check "4 · reject: nằm ở văn xuôi thì không tính là vi phạm" \
    $'Đừng viết `import KVRouter` — tên module đó là của v1.\n\n'"$ok" \
    "$bad" 0 "skill có tác dụng"

# Và chiều ngược lại: output không có code block nào thì không có gì để chấm. Im
# lặng cho qua sẽ đọc thành "skill làm đúng" — đúng cách một phiên bị chặn quyền
# ghi file đã đọc thành "skill vô dụng" ở lần đo đầu.
check "5 · không có code block thì fail có tên, không pass ngầm" \
    "dùng KVRouterKit nhé, không có code đâu" "$bad" 1 "không-có-code-block"

# Phiên chết vì hạ tầng phải là exit 2 ("không đo được"), không phải exit 1 ("đo
# được và xấu"). Xảy ra thật 14/08: hết quota giữa chừng, cả 10 cột rỗng, và bảng
# kết quả kết án skill bằng đúng câu "sửa skill, đừng sửa case".
check "6 · hết quota thì dừng, không chấm" \
    "You've hit your session limit · resets 12:40am" "$bad" 2 "chết vì hạ tầng"

# Guard: thiếu --in, hoặc target không phải repo app, phải chết rõ ràng chứ không
# âm thầm đo trong repo kit.
out=$(PATH="$tmp/bin:$PATH" ./tools/measure-skill.sh "$tmp/probe.cases" 2>&1); code=$?
if [ "$code" = 2 ] && grep -q 'cần --in' <<< "$out"; then
    printf '\033[32m✓\033[0m 7 · thiếu --in thì dừng, không đo bừa\n'
    pass_count=$((pass_count + 1))
else
    printf '\033[31m✗\033[0m 7 · thiếu --in mà vẫn chạy (exit %s)\n' "$code"
    fail_count=$((fail_count + 1))
fi

echo
if [ "$fail_count" -gt 0 ]; then
    printf '\033[31m%d/%d phép kiểm sai.\033[0m\n' "$fail_count" "$((pass_count + fail_count))"
    exit 1
fi
printf '\033[32mCả %d phép kiểm đúng — cái cân dùng được.\033[0m\n' "$pass_count"
