#!/usr/bin/env bash
#
# Test cho test: chứng minh mỗi phép kiểm trong doctor.sh thật sự fail khi bị vi phạm.
#
# Bài học đã trả giá ở KVAppBase: `check-arch.sh` có một luật khớp `pushView(` mà
# không khớp `pushView { }` — dạng người ta thật sự viết — nên nó **pass rỗng** từ
# lúc ra đời. Một luật im lặng ngừng khớp còn tệ hơn không có luật, vì dấu tick
# xanh lúc đó chứng nhận điều ngược lại.
#
# Chạy mỗi khi doctor.sh đổi. Vài giây.

set -uo pipefail
cd "$(dirname "$0")/.."

pass_count=0 fail_count=0
tmp="$(mktemp -d)"

# Probe nào cũng phải trả repo về nguyên trạng, kể cả khi script bị Ctrl-C giữa đường.
restore_all() {
    [ -f "$tmp/README.md" ] && cp "$tmp/README.md" README.md
    [ -f "$tmp/init-base.sh" ] && cp "$tmp/init-base.sh" tools/init-base.sh
    [ -f "$tmp/di.md" ] && cp "$tmp/di.md" .claude/skills/ios-architecture/references/di.md
    [ -f "$tmp/skillmd" ] && cp "$tmp/skillmd" .claude/skills/ios-verify/SKILL.md
    rm -rf .claude/skills/__probe .claude/skills/ios-verify/scripts
    if [ -L .agents/skills.bak ]; then
        rm -f .agents/skills; mv .agents/skills.bak .agents/skills
    fi
    [ -d .agents/skills ] || ln -s ../.claude/skills .agents/skills
    git add -f .agents/skills >/dev/null 2>&1
    rm -rf "$tmp"
}
trap restore_all EXIT

check() {
    local name="$1"
    if ./tools/doctor.sh >/dev/null 2>&1; then
        printf '\033[31m✗\033[0m %s — vi phạm KHÔNG bị bắt\n' "$name"
        fail_count=$((fail_count + 1))
    else
        printf '\033[32m✓\033[0m %s\n' "$name"
        pass_count=$((pass_count + 1))
    fi
}

echo "Kiểm tra doctor.sh có thật sự bắt được vi phạm:"
echo

if ! ./tools/doctor.sh >/dev/null 2>&1; then
    echo "Kit đang có vấn đề sẵn — chạy ./tools/doctor.sh và sửa trước."
    exit 1
fi

cp README.md "$tmp/README.md"
cp tools/init-base.sh "$tmp/init-base.sh"
cp .claude/skills/ios-architecture/references/di.md "$tmp/di.md"

# 1a · symlink thành directory thật (dấu hiệu ai đó copy thay vì symlink)
mv .agents/skills .agents/skills.bak && mkdir .agents/skills
check "1a · .agents/skills là directory thật"
rm -rf .agents/skills && mv .agents/skills.bak .agents/skills

# 1b · symlink còn đó nhưng rơi khỏi git — đúng lỗi đã xảy ra thật
git rm --cached -q .agents/skills
check "1b · symlink không được git track"
git add -f .agents/skills >/dev/null

# 2 · bản copy script trong .claude/
mkdir -p .claude/skills/ios-verify/scripts && echo '#!/bin/sh' > .claude/skills/ios-verify/scripts/check-arch.sh
check "2 · có bản copy script trong .claude/"
rm -rf .claude/skills/ios-verify/scripts

# 3 · SKILL.md khai name khác tên folder.
#     Sửa một skill có thật, không tạo folder mới: một folder mới cũng vi phạm luật
#     "skill nào cũng phải được doc nhắc", nên probe sẽ đỏ vì hai lý do và không còn
#     chứng minh được luật nào.
cp .claude/skills/ios-verify/SKILL.md "$tmp/skillmd"
perl -pi -e 's/^name: ios-verify$/name: nham-ten/' .claude/skills/ios-verify/SKILL.md
check "3 · name: khác tên folder"
cp "$tmp/skillmd" .claude/skills/ios-verify/SKILL.md

# 4 · doc nói một version khác cái project.yml pin
printf '\nKVRouterKit 3.1 là version đang dùng.\n' >> .claude/skills/ios-architecture/references/di.md
check "4 · version trong doc lệch project.yml"
cp "$tmp/di.md" .claude/skills/ios-architecture/references/di.md

# 5 · doc trỏ vào path không tồn tại
printf '\nXem `Features/Nope/Missing.swift`.\n' >> .claude/skills/ios-architecture/references/di.md
check "5 · path trong doc không tồn tại"
cp "$tmp/di.md" .claude/skills/ios-architecture/references/di.md

# 6 · init-base exclude cả .claude, chặn hook xcodegen tới repo app
perl -pi -e "s|^(\s*)--exclude '\.claude/skills'.*|\$1--exclude '.claude' \\\\|" tools/init-base.sh
check "6 · init-base exclude cả .claude"
cp "$tmp/init-base.sh" tools/init-base.sh

# 7 · doc quảng cáo một skill không tồn tại
printf '\nDùng skill `ios-ghost` khi cần.\n' >> README.md
check "7a · doc nhắc skill không tồn tại"
cp "$tmp/README.md" README.md

# 7b · chiều ngược lại: skill hợp lệ nhưng không bảng nào nhắc tới
mkdir -p .claude/skills/__probe
printf -- '---\nname: __probe\ndescription: probe cho doctor-selftest\n---\n' > .claude/skills/__probe/SKILL.md
check "7b · skill có mà không doc nào nhắc"
rm -rf .claude/skills/__probe

echo
if [ "$fail_count" -gt 0 ]; then
    printf '\033[31m%d/%d phép kiểm không bắt được vi phạm.\033[0m\n' "$fail_count" "$((pass_count + fail_count))"
    exit 1
fi
printf '\033[32mCả %d phép kiểm đều bắt được vi phạm.\033[0m\n' "$pass_count"
