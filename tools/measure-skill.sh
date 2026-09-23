#!/usr/bin/env bash
#
# Đo một skill có thật sự tác dụng: chạy cùng một prompt hai lần — một lần có skill,
# một lần tắt skill — rồi assert bằng regex.
#
# Vì sao cần: cả bộ skill này được viết với niềm tin rằng nó có tác dụng, và niềm
# tin đó **chưa từng được chứng minh**. Đúng loại niềm tin đã sai một lần rồi:
# `check-arch.sh` có một luật pass rỗng từ lúc ra đời, và nó chỉ lộ ra khi có
# self-test. Một skill vô tác dụng còn tệ hơn không có skill, vì nó chiếm context
# mọi lượt và làm người ta tin là đã có bảo hiểm.
#
# Kết quả đáng đọc là **cột "không skill"**: nó fail thì skill mới có việc để làm.
# Cả hai cột pass nghĩa là model tự làm đúng — prompt đó không đo được gì, đổi prompt
# khó hơn hoặc bỏ nó đi.
#
# Usage:
#   ./tools/measure-skill.sh kv-packages --in /path/to/app-repo
#   ./tools/measure-skill.sh --all --in /path/to/app-repo
#
# Case nằm ở tools/measure/<skill>.cases, format mỗi block:
#
#   prompt: <câu người dùng sẽ gõ>
#   expect: <regex phải có trong output>
#   reject: <regex không được có>
#   ---
#
# Yêu cầu: `claude` CLI trên PATH, và --in trỏ vào một repo app đã init-base (có
# .claude/skills + một .xcodeproj). Đo trong repo kit thì vô nghĩa: không có source để
# model bắt chước.

set -uo pipefail
cd "$(dirname "$0")/.."

fail() { printf 'measure-skill: %s\n' "$*" >&2; exit 2; }

skill=""; all=false; target=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --all) all=true; shift ;;
        --in)  target="${2:-}"; shift 2 ;;
        -*)    fail "tham số lạ: $1" ;;
        *)     skill="$1"; shift ;;
    esac
done

command -v claude >/dev/null || fail "cần \`claude\` CLI trên PATH"
[ -n "$target" ] || fail "cần --in <repo app đã init-base>"
[ -d "$target/.claude/skills" ] || fail "$target không có .claude/skills — chưa init-base?"
compgen -G "$target/*.xcodeproj" >/dev/null || fail "$target không có .xcodeproj — không phải repo app"

cases=()
if $all; then
    for f in tools/measure/*.cases; do cases+=("$f"); done
elif [ -f "$skill" ]; then
    # Nhận thẳng đường dẫn file case — self-test dùng cửa này để khỏi phải nhét file
    # tạm vào tools/measure/.
    cases=("$skill")
else
    [ -n "$skill" ] || fail "cần tên skill, hoặc --all"
    [ -f "tools/measure/$skill.cases" ] || fail "không có tools/measure/$skill.cases"
    cases=("tools/measure/$skill.cases")
fi

# Tắt skill bằng chính cơ chế của harness, không phải bằng cách xoá file: xoá file
# thì lần đo sau chạy trên một repo khác cây source, và so sánh mất ý nghĩa.
disabled_settings() {
    local name="$1"
    printf '{"skillOverrides":{"%s":"off"}}' "$name"
}

# Bài đo chấm **câu trả lời**, nên nó phải là một câu trả lời chứ không phải một
# phiên agent đi sửa repo. Hai chốt, áp y hệt cho cả hai cột nên không lệch cột nào:
#
#   - chặn tool ghi. Đo lần đầu (14/08) không chặn, và `-p` thì trust dialog bị bỏ
#     qua nên `permissions.allow` của repo không có hiệu lực: model đứng lại xin
#     quyền ghi, output rỗng code, cả hai cột FAIL vì "thiếu" — đọc y như skill vô
#     dụng. Cấp quyền ghi cũng hỏng, theo hướng ngược lại: model ghi file rồi trả
#     lời "đã thêm vào X", cũng không còn code để chấm.
#   - dặn thẳng là trả code trong chat.
NO_WRITE_TOOLS=(--disallowedTools Write Edit NotebookEdit)
ANSWER_INLINE=$'\n\n(Trả lời bằng code trong chat. Đừng ghi file, đừng chạy lệnh.)'

run_claude() {
    local prompt="$1$ANSWER_INLINE" settings="${2:-}"
    if [ -n "$settings" ]; then
        (cd "$target" && claude -p "$prompt" "${NO_WRITE_TOOLS[@]}" --settings "$settings" 2>&1)
    else
        (cd "$target" && claude -p "$prompt" "${NO_WRITE_TOOLS[@]}" 2>&1)
    fi
}

# Một phiên chết vì hạ tầng — hết quota, mất login, CLI lỗi — trả về output không
# có code, và bài đo chấm nó y hệt một câu trả lời sai: "CÓ skill mà vẫn sai, sửa
# skill đừng sửa case". Đã xảy ra thật (14/08): cả 10 cột rỗng vì `You've hit your
# session limit`, và bảng kết quả đọc như một bản án cho skill.
#
# Nên đây phải là exit 2 — "không đo được", khác hẳn exit 1 — "đo được và xấu".
infra_failure() {
    grep -qiE "hit your session limit|rate limit|Not logged in|Invalid API key|usage limit|Credit balance" <<< "$1"
}

# Chỉ phần trong ``` fence. `reject:` phải soi ở đây, không soi cả output: một câu
# trả lời **đúng** thì gọi tên đúng cái nó khuyên tránh — "chỉ import Foundation,
# không Decodable" là câu chuẩn của skill, và nó trượt `reject: Decodable` nếu đem
# regex quét văn xuôi. Lần đo đầu mất 4 case vì đúng chuyện này.
code_blocks() {
    perl -ne 'if (/^\s*```/) { $in = !$in; next } print if $in'
}

# assert <output> <expect-list> <reject-list> → in "PASS" hoặc lý do fail
#
# `expect:` soi cả output (một đường dẫn như `Domain/Entities` nằm ở văn xuôi là
# hợp lệ), `reject:` chỉ soi code — xem `code_blocks`.
assert_output() {
    local out="$1" expects="$2" rejects="$3" problems="" code
    code="$(code_blocks <<< "$out")"
    while IFS= read -r re; do
        [ -n "$re" ] || continue
        grep -qE "$re" <<< "$out" || problems="$problems thiếu:/$re/"
    done <<< "$expects"
    while IFS= read -r re; do
        [ -n "$re" ] || continue
        grep -qE "$re" <<< "$code" && problems="$problems có:/$re/"
    done <<< "$rejects"
    # Không có code block nào thì không có gì để chấm. Im lặng cho qua ở đây sẽ
    # đọc thành "skill làm đúng", nên nó phải là một fail có tên riêng.
    [ -z "$code" ] && problems="$problems không-có-code-block"
    [ -z "$problems" ] && echo "PASS" || echo "FAIL —$problems"
}

log_dir="${MEASURE_LOG_DIR:-/tmp/measure-skill}"
mkdir -p "$log_dir"
verdicts=0 useless=0 broken=0

for case_file in "${cases[@]}"; do
    name="$(basename "$case_file" .cases)"
    printf '\n\033[1m▸ %s\033[0m  (%s)\n' "$name" "$case_file"

    prompt=""; expects=""; rejects=""; index=0
    process_block() {
        [ -n "$prompt" ] || return 0
        index=$((index + 1))
        local with without v_with v_without
        with="$(run_claude "$prompt")"
        without="$(run_claude "$prompt" "$(disabled_settings "$name")")"
        printf '%s\n' "$with"    > "$log_dir/$name-$index-with.txt"
        printf '%s\n' "$without" > "$log_dir/$name-$index-without.txt"

        # Dừng ngay, đừng chấm. Chấm tiếp là in ra một bảng kết quả trông như đo
        # thật trong khi không có phiên nào chạy được.
        if infra_failure "$with$without"; then
            printf '\033[31m✗ phiên claude chết vì hạ tầng, không phải vì skill:\033[0m\n'
            grep -ioE "hit your session limit.*|rate limit.*|Not logged in.*|Invalid API key.*|usage limit.*|Credit balance.*" \
                <<< "$with$without" | head -2 | sed 's/^/    /'
            printf '    log: %s/%s-%s-*.txt\n' "$log_dir" "$name" "$index"
            exit 2
        fi

        v_with="$(assert_output "$with" "$expects" "$rejects")"
        v_without="$(assert_output "$without" "$expects" "$rejects")"

        printf '  %d. %s\n' "$index" "$(printf '%.70s' "$prompt")"
        printf '     có skill    : %s\n' "$v_with"
        printf '     không skill : %s\n' "$v_without"
        verdicts=$((verdicts + 1))
        case "$v_with:$v_without" in
            PASS:PASS)   printf '     \033[33m→ prompt này không đo được gì: model tự đúng\033[0m\n'; useless=$((useless + 1)) ;;
            PASS:FAIL*)  printf '     \033[32m→ skill có tác dụng ở đây\033[0m\n' ;;
            FAIL*:*)     printf '     \033[31m→ CÓ skill mà vẫn sai: skill chưa nói đủ rõ\033[0m\n'; broken=$((broken + 1)) ;;
        esac
        prompt=""; expects=""; rejects=""
    }

    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            \#*|"")     ;;
            ---*)       process_block ;;
            prompt:*)   prompt="${line#prompt:}"; prompt="${prompt# }" ;;
            expect:*)   expects="$expects${line#expect: }"$'\n' ;;
            reject:*)   rejects="$rejects${line#reject: }"$'\n' ;;
        esac
    done < "$case_file"
    process_block
done

printf '\n%d case. log: %s\n' "$verdicts" "$log_dir"
if [ "$broken" -gt 0 ]; then
    printf '\033[31m%d case sai NGAY CẢ KHI có skill — sửa skill, đừng sửa case.\033[0m\n' "$broken"
    exit 1
fi
if [ "$useless" -gt 0 ]; then
    printf '\033[33m%d case cả hai cột đều pass — chưa chứng minh được gì, cần prompt khó hơn.\033[0m\n' "$useless"
    exit 1
fi
printf '\033[32mMọi case: có skill pass, không skill fail. Skill có tác dụng.\033[0m\n'
