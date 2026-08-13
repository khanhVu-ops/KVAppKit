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
# .claude/skills + project.yml). Đo trong repo kit thì vô nghĩa: không có source để
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
[ -f "$target/project.yml" ] || fail "$target không có project.yml — không phải repo app"

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

run_claude() {
    local prompt="$1" settings="${2:-}"
    if [ -n "$settings" ]; then
        (cd "$target" && claude -p "$prompt" --settings "$settings" 2>&1)
    else
        (cd "$target" && claude -p "$prompt" 2>&1)
    fi
}

# assert <output> <expect-list> <reject-list> → in "PASS" hoặc lý do fail
assert_output() {
    local out="$1" expects="$2" rejects="$3" problems=""
    while IFS= read -r re; do
        [ -n "$re" ] || continue
        grep -qE "$re" <<< "$out" || problems="$problems thiếu:/$re/"
    done <<< "$expects"
    while IFS= read -r re; do
        [ -n "$re" ] || continue
        grep -qE "$re" <<< "$out" && problems="$problems có:/$re/"
    done <<< "$rejects"
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
