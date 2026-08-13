#!/usr/bin/env bash
#
# Kiểm sức khoẻ của kit: rule và skill có còn nói đúng sự thật không.
#
# Mọi phép kiểm dưới đây tương ứng một lỗi đã xảy ra thật, không phải một lỗi
# tưởng tượng ra:
#
#   1  symlink `.agents/skills` không được git track — global gitignore ăn mất,
#      nên mọi clone thiếu nó trong khi ba file doc khẳng định nó có.
#   2  `ios-verify/scripts/` giữ bản copy của tools/*.sh, lạc hậu hai luật.
#   3  skill có `name:` khác tên folder thì runtime không load được như doc nói.
#   4  AGENTS.md nói KVRouterKit 3.1, bảng nói 3.2.0, project.yml pin 3.2.1.
#   5  subagent chỉ vào `FeatureOrder/OrderList/`, folder đã bỏ từ lâu.
#   6  hook xcodegen không tới được repo app vì init-base exclude cả `.claude`.
#   7  bảng skill trong doc nhắc một skill không tồn tại — và chiều ngược lại, một
#      skill viết ra rồi mà không bảng nào nhắc, nên không ai biết để gọi.
#
# `HANDOFF.md` được miễn luật 4 và 5: nó là sổ ghi lịch sử, việc nó nhắc một version
# cũ hay một file đã xoá ("`DI/UnhostedRouter.swift` không còn tồn tại") là đúng chức
# năng của nó, không phải drift.
#
# Luật 4 và 5 cần cây source thật để đối chiếu. Thứ tự tìm: repo hiện tại (nếu đã
# init-base) → --against DIR → ../KVAppBase. Không thấy thì BỎ QUA và nói rõ là bỏ
# qua — im lặng ở đây sẽ đọc như "đã kiểm và ổn".
#
# Usage:  ./tools/doctor.sh [--against /path/to/app-or-base-repo]

set -uo pipefail
cd "$(dirname "$0")/.."

failures=0 skipped=0

fail() { printf '\033[31m✗\033[0m %s\n' "$1"; shift; [ "$#" -gt 0 ] && printf '    %s\n' "$@"; failures=$((failures + 1)); }
pass() { printf '\033[32m✓\033[0m %s\n' "$1"; }
skip() { printf '\033[33m–\033[0m %s\n' "$1"; skipped=$((skipped + 1)); }

against=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --against) against="${2:-}"; shift 2 ;;
        *) echo "tham số lạ: $1"; exit 2 ;;
    esac
done

source_root=""
for candidate in "$PWD" "$against" "../KVAppBase"; do
    [ -n "$candidate" ] && [ -f "$candidate/project.yml" ] && { source_root="$candidate"; break; }
done

# ---------------------------------------------------------------------------
# 1. Symlink một-nguồn cho Codex, và nó phải nằm trong git.
# ---------------------------------------------------------------------------
if [ ! -L .agents/skills ]; then
    fail ".agents/skills không phải symlink" "restore: ln -s ../.claude/skills .agents/skills"
elif [ ! -d .agents/skills ]; then
    fail ".agents/skills là symlink chết" "trỏ tới: $(readlink .agents/skills)"
elif ! git rev-parse --git-dir >/dev/null 2>&1; then
    # Chưa `git init` thì chưa track được gì — nói là bỏ qua, đừng báo lỗi cho một
    # thứ chưa thể đúng hay sai.
    pass ".agents/skills là symlink và sống"
    skip "symlink có trong git — thư mục này chưa là git repo"
elif [ "$(git ls-files .agents/skills 2>/dev/null)" != ".agents/skills" ]; then
    fail ".agents/skills không được git track" \
        "clone sẽ thiếu nó — git add -f .agents/skills"
else
    pass ".agents/skills là symlink, sống, và có trong git"
fi

# ---------------------------------------------------------------------------
# 2. Không có bản copy nào của script trong .claude/.
# ---------------------------------------------------------------------------
dups=$(find .claude -name '*.sh' -type f 2>/dev/null)
if [ -n "$dups" ]; then
    fail "có script trong .claude/ — script thuộc tools/ của repo app" "$dups"
else
    pass "không có bản copy script trong .claude/"
fi

# ---------------------------------------------------------------------------
# 3. Mỗi skill có SKILL.md, và `name:` khớp tên folder.
# ---------------------------------------------------------------------------
bad_skills=""
for dir in .claude/skills/*/; do
    name="$(basename "$dir")"
    if [ ! -f "$dir/SKILL.md" ]; then
        bad_skills="$bad_skills$name: thiếu SKILL.md"$'\n'
        continue
    fi
    declared=$(sed -n 's/^name:[[:space:]]*//p' "$dir/SKILL.md" | head -1 | tr -d '"'"'"' \r')
    [ "$declared" = "$name" ] || bad_skills="$bad_skills$name: name: là '$declared'"$'\n'
    grep -q '^description:' "$dir/SKILL.md" \
        || bad_skills="$bad_skills$name: thiếu description:"$'\n'
done
if [ -n "$bad_skills" ]; then
    fail "SKILL.md không khớp folder" "$bad_skills"
else
    pass "mọi skill có SKILL.md với name khớp folder ($(ls -d .claude/skills/*/ | wc -l | tr -d ' ') skill)"
fi

# ---------------------------------------------------------------------------
# 4. Version trong doc khớp version project.yml pin.
#    Chỉ soi dòng có nhắc tên package, nên "iOS 16.0" hay "Swift 6" không bị lôi vào.
# ---------------------------------------------------------------------------
if [ -z "$source_root" ]; then
    skip "version doc vs project.yml — không thấy project.yml (dùng --against DIR)"
else
    wrong=""
    packages=$(perl -0ne 'print "$1 $2\n" while /^  (KV\w+):\n(?:.*\n)*?    from: ([\d.]+)/gm' \
        "$source_root/project.yml")
    while read -r pkg pinned; do
        [ -n "$pkg" ] || continue
        # Mỗi dòng doc nhắc "<Package><gì đó> <số>.<số>": số đó phải là chính version
        # pin, hoặc một tiền tố của nó — "KVRouterKit 3.2" là cách nói đúng cho 3.2.1,
        # còn "3.1" thì không.
        while IFS= read -r hit; do
            [ -n "$hit" ] || continue
            claimed=$(printf '%s' "$hit" | grep -oE "$pkg[A-Za-z]* [0-9]+(\.[0-9]+)+" \
                      | head -1 | grep -oE '[0-9]+(\.[0-9]+)+')
            case "$pinned" in
                "$claimed"|"$claimed".*) ;;
                *) wrong="$wrong${hit%%:*}: nói $claimed, project.yml pin $pinned"$'\n' ;;
            esac
        done < <(grep -rnE "$pkg[A-Za-z]* [0-9]+\.[0-9]+" --include='*.md' \
                    --exclude=HANDOFF.md . || true)
    done <<< "$packages"
    if [ -n "$wrong" ]; then
        fail "version trong doc lệch project.yml" "$wrong"
    else
        pass "version trong doc khớp project.yml"
    fi
fi

# ---------------------------------------------------------------------------
# 5. Mọi path repo mà doc nhắc tới phải tồn tại thật.
#    Bỏ path có placeholder (`<X>`) hoặc glob (`*`) — chúng là mẫu, không phải path.
# ---------------------------------------------------------------------------
if [ -z "$source_root" ]; then
    skip "path trong doc — không thấy project.yml (dùng --against DIR)"
else
    missing=""
    while read -r ref; do
        [ -n "$ref" ] || continue
        file="${ref%%|*}"; path="${ref#*|}"
        # Hai gốc: doc của kit nhắc path của kit (`tools/init-base.sh`) lẫn path của
        # app (`Features/Order/...`), và cả hai đều đúng.
        [ -e "$source_root/$path" ] || [ -e "$path" ] \
            || missing="$missing$file → $path"$'\n'
    done < <(grep -rnoE '`(Core|Domain|Data|DI|DesignSystem|Features|App|Tests|tools)/[A-Za-z0-9_./+-]*`' \
                --include='*.md' --exclude=HANDOFF.md . \
             | sed -E 's/^([^:]+):[0-9]+:`(.*)`$/\1|\2/' | sort -u)
    if [ -n "$missing" ]; then
        fail "doc trỏ vào path không tồn tại" "$missing"
    else
        pass "mọi path repo trong doc đều tồn tại"
    fi
fi

# ---------------------------------------------------------------------------
# 6. Hook xcodegen tới được repo app: init-base không được exclude cả .claude.
# ---------------------------------------------------------------------------
if grep -qE "^\s*--exclude '\.claude'" tools/init-base.sh; then
    fail "init-base exclude cả .claude" \
        "settings.json của base (hook xcodegen) sẽ không tới repo app"
elif [ -n "$source_root" ] && [ ! -f "$source_root/.claude/settings.json" ]; then
    fail "base không có .claude/settings.json" "hook xcodegen chưa được khai ở đâu"
else
    pass "hook xcodegen đi được từ base sang repo app"
fi

# ---------------------------------------------------------------------------
# 7. Bảng skill trong doc chỉ nhắc skill có thật.
# ---------------------------------------------------------------------------
ghosts=""
for named in $(grep -rhoE '`(ios|kv|api|figma|project)-[a-z-]+`|`init-base`' AGENTS.md README.md CLAUDE.md \
               | tr -d '`' | sort -u); do
    [ -d ".claude/skills/$named" ] && continue
    grep -qE "^- \`$named\`" HANDOFF.md && continue   # đã ghi là chưa viết
    ghosts="$ghosts$named"$'\n'
done
if [ -n "$ghosts" ]; then
    fail "doc nhắc skill không tồn tại" "$ghosts"
else
    pass "mọi skill được doc nhắc đều tồn tại"
fi

# Và chiều ngược lại. Một skill không được bảng nào nhắc thì người và agent đều không
# biết nó có — công viết ra nằm đó không ai gọi, đúng nửa còn lại của cùng một lỗi.
unadvertised=""
for dir in .claude/skills/*/; do
    named="$(basename "$dir")"
    grep -qE "\`$named\`" AGENTS.md README.md || unadvertised="$unadvertised$named"$'\n'
done
if [ -n "$unadvertised" ]; then
    fail "skill có nhưng không doc nào nhắc" "$unadvertised" \
        "thêm vào bảng skill trong AGENTS.md và README.md"
else
    pass "mọi skill đều được doc nhắc tới"
fi

echo
[ "$skipped" -gt 0 ] && printf '%d phép kiểm bị bỏ qua — xem dòng vàng ở trên.\n' "$skipped"
if [ "$failures" -gt 0 ]; then
    printf '\033[31m%d vấn đề.\033[0m\n' "$failures"
    exit 1
fi
printf '\033[32mKit khoẻ.\033[0m\n'
