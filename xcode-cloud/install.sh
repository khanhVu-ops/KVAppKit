#!/usr/bin/env bash
#
# Cài Xcode Cloud vào một repo app cá nhân (team Van Khanh Vu, W3274W2Y83).
#
#   xcode-cloud/install.sh [THƯ_MỤC_APP] [--remove-fastlane] [--dry-run]
#
# Làm phần chép file. Phần bấm trong Xcode/App Store Connect (tạo workflow, cấp quyền
# GitHub) không làm bằng script được — script in checklist ở cuối, chi tiết trong
# xcode-cloud/README.md.
#
# Chạy lại bao nhiêu lần cũng được: hai script chung luôn bị chép đè bằng bản mới
# nhất, còn app_post_clone.sh (việc riêng của app) đã có thì không bao giờ bị đụng.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEAM_ID="W3274W2Y83"
TEAM_NAME="Van Khanh Vu"

app_dir=""
remove_fastlane=false
dry_run=false
for arg in "$@"; do
    case "$arg" in
        --remove-fastlane) remove_fastlane=true ;;
        --dry-run)         dry_run=true ;;
        -h|--help)         sed -n 2,12p "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)                echo "Không hiểu tuỳ chọn: $arg" >&2; exit 2 ;;
        *)                 app_dir="$arg" ;;
    esac
done
app_dir="$(cd "${app_dir:-.}" && pwd)"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; warnings=$((warnings + 1)); }
die()  { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }
run()  { if $dry_run; then printf '    (dry-run) %s\n' "$*"; else "$@"; fi; }
warnings=0

git -C "$app_dir" rev-parse --show-toplevel >/dev/null 2>&1 || die "$app_dir không phải repo git."
repo_root="$(git -C "$app_dir" rev-parse --show-toplevel)"
# Chính repo kit (còn init-base.sh + config/) thì không cài. Repo app vừa init từ kit vẫn
# chứa xcode-cloud/ nhưng hai thứ kia đã bị init-base xoá, nên được phép.
if [ -f "$repo_root/tools/init-base.sh" ] && [ -f "$repo_root/config/base-template.env" ]; then
    die "Đang trỏ vào chính KVAppKit. Truyền đường dẫn repo app."
fi

# Xcode Cloud tìm ci_scripts/ CẠNH .xcodeproj/.xcworkspace, không phải ở gốc repo.
# Lấy thư mục nông nhất có project.yml, .xcworkspace hoặc .xcodeproj (bỏ Pods, package).
project_dir="$(cd "$repo_root" && find . -maxdepth 3 \
    \( -name Pods -o -name Packages -o -name .build -o -name 'node_modules' -o -name '.*' -not -name . \) -prune -o \
    \( -name project.yml -o -name '*.xcworkspace' -o -name '*.xcodeproj' \) -print 2>/dev/null \
    | grep -v '\.xcodeproj/' | awk -F/ '{ print NF, $0 }' | sort -n | head -1 | cut -d' ' -f2- | xargs -I{} dirname {})"
[ -n "$project_dir" ] || die "Không tìm thấy .xcodeproj, .xcworkspace hay project.yml trong $repo_root."
project_dir="$(cd "$repo_root/$project_dir" && pwd)"
ci_dir="$project_dir/ci_scripts"
# Đường dẫn tương đối với gốc repo, để in ra và để đưa cho git.
rel() { case "$1" in "$repo_root") echo . ;; "$repo_root"/*) echo "${1#"$repo_root"/}" ;; *) echo "$1" ;; esac; }

printf '\n\033[1mXcode Cloud → %s (%s)\033[0m\n' "$(basename "$repo_root")" "$(rel "$project_dir")"

# 1. Hai script chung.
run mkdir -p "$ci_dir"
for f in ci_post_clone.sh ci_post_xcodebuild.sh; do
    run cp "$KIT_DIR/$f" "$ci_dir/$f"
    run chmod +x "$ci_dir/$f"
done
ok "ci_scripts/ci_post_clone.sh, ci_post_xcodebuild.sh (bản chung, chép đè)"

# 2. Hook riêng của app: chỉ tạo khi chưa có. Repo dựng từ KVAppBase có sẵn bộ luật
#    trong tools/, nên chạy chúng sớm ở Xcode Cloud như verify.sh chạy ở máy.
if [ -f "$ci_dir/app_post_clone.sh" ]; then
    ok "ci_scripts/app_post_clone.sh đã có, giữ nguyên"
else
    checks=""
    for t in check-arch.sh check-arch-selftest.sh check-l10n.sh check-l10n-selftest.sh; do
        [ -x "$project_dir/tools/$t" ] && checks="$checks./tools/$t"$'\n'
    done
    if ! $dry_run; then
        {
            echo '#!/bin/sh'
            echo '#'
            echo '# Việc riêng của app, chạy từ ci_post_clone.sh trên Xcode Cloud (cwd = thư mục project).'
            echo '# Đặt ở đây những kiểm tra chạy trong vài giây (lint, luật kiến trúc, localization),'
            echo '# để Xcode Cloud dừng trước khi tốn phút build. Exit khác 0 là dừng cả workflow.'
            echo
            echo 'set -eu'
            echo
            if [ -n "$checks" ]; then printf '%s' "$checks"; else echo '# ./tools/check-something.sh'; fi
        } >"$ci_dir/app_post_clone.sh"
        chmod +x "$ci_dir/app_post_clone.sh"
    fi
    ok "ci_scripts/app_post_clone.sh mới tạo${checks:+ (gọi $(printf '%s' "$checks" | wc -l | tr -d ' ') script trong tools/)}"
fi

# 2b. Repo dựng từ KVAppBase: luật "README khớp thư mục tầng" của check-arch.sh coi mọi
#     thư mục ở gốc là một tầng, nên ci_scripts/ mới làm nó đỏ ngay ở Xcode Cloud.
#     Thêm ci_scripts và TestFlight vào danh sách bỏ qua, cạnh fastlane và build.
arch="$project_dir/tools/check-arch.sh"
if [ -f "$arch" ] && grep -q "\-not -name 'build'" "$arch" && ! grep -q "\-not -name 'ci_scripts'" "$arch"; then
    $dry_run || perl -pi -e "s/-not -name 'build'/-not -name 'ci_scripts' -not -name 'TestFlight' -not -name 'build'/" "$arch"
    ok "tools/check-arch.sh: bỏ qua ci_scripts/ và TestFlight/ ở luật thư mục tầng"
fi

# 3. Ghi chú TestFlight do ci_post_xcodebuild.sh sinh ra trên cloud: đừng commit nhầm.
gitignore="$repo_root/.gitignore"
if grep -qxF 'TestFlight/' "$gitignore" 2>/dev/null; then
    ok ".gitignore đã có TestFlight/"
else
    $dry_run || printf '\n# Ghi chú TestFlight do ci_scripts/ci_post_xcodebuild.sh sinh trên Xcode Cloud.\nTestFlight/\n' >>"$gitignore"
    ok ".gitignore thêm TestFlight/"
fi

# 4. Package.resolved. Xcode Cloud không tự resolve package: file này phải nằm trong git.
xcodeproj="$(ls -d "$project_dir"/*.xcodeproj 2>/dev/null | head -1 || true)"
workspace="$(ls -d "$project_dir"/*.xcworkspace 2>/dev/null | head -1 || true)"
if [ -n "$workspace" ]; then
    resolved="$workspace/xcshareddata/swiftpm/Package.resolved"
elif [ -n "$xcodeproj" ]; then
    resolved="$xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
else
    resolved=""
    warn "Chưa có .xcodeproj (XcodeGen?). Chạy xcodegen generate, mở Xcode cho nó resolve, rồi chạy lại script này."
fi
if [ -n "$resolved" ] && grep -qs XCRemoteSwiftPackageReference "$xcodeproj/project.pbxproj"; then
    rel_resolved="$(rel "$resolved")"
    if git -C "$repo_root" ls-files --error-unmatch "$rel_resolved" >/dev/null 2>&1; then
        ok "Package.resolved đã nằm trong git"
    elif git -C "$repo_root" check-ignore -q "$rel_resolved"; then
        # Trường hợp XcodeGen: cả .xcodeproj bị ignore. Thay dòng ignore thư mục bằng
        # ignore nội dung, vì git không mở lại được file nằm trong thư mục đã bị ignore.
        if grep -qxF '*.xcodeproj' "$gitignore"; then
            if ! $dry_run; then
                perl -0pi -e 's{^\*\.xcodeproj\n}{# .xcodeproj do XcodeGen sinh ra nên bị ignore, TRỪ Package.resolved: Xcode Cloud\n# không tự resolve package. Ignore nội dung (`dir/*`), không ignore cả thư mục.\n*.xcodeproj/*\n!*.xcodeproj/project.xcworkspace/\n*.xcodeproj/project.xcworkspace/*\n!*.xcodeproj/project.xcworkspace/xcshareddata/\n*.xcodeproj/project.xcworkspace/xcshareddata/*\n!*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/\n*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/*\n!*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved\n}m' "$gitignore"
            fi
            if $dry_run || ! git -C "$repo_root" check-ignore -q "$rel_resolved"; then
                ok ".gitignore mở cho Package.resolved (nhớ git add $rel_resolved)"
            else
                warn "Đã sửa dòng *.xcodeproj nhưng $rel_resolved vẫn bị ignore — xem git check-ignore -v \"$rel_resolved\"."
            fi
        else
            warn "$rel_resolved đang bị ignore: $(git -C "$repo_root" check-ignore -v "$rel_resolved"). Sửa .gitignore rồi commit file này."
        fi
    elif [ -f "$resolved" ]; then
        ok "Package.resolved có, chưa commit (nhớ git add $rel_resolved)"
    else
        warn "Chưa có $rel_resolved. Mở project trong Xcode cho nó resolve package rồi commit file đó."
    fi
fi

# 5. Team ký phải là team cá nhân, không phải team công ty.
team_found="$(cat "$project_dir/project.yml" "$xcodeproj/project.pbxproj" 2>/dev/null \
    | grep -oE 'DEVELOPMENT_TEAM[ :=]+"?[A-Z0-9]{10}' | grep -oE '[A-Z0-9]{10}$' | sort -u | tr '\n' ' ' || true)"
if [ -z "$team_found" ] && [ -n "$xcodeproj" ] && [ ! -f "$project_dir/project.yml" ] \
    && grep -q 'CODE_SIGN_STYLE = Automatic;' "$xcodeproj/project.pbxproj"; then
    # Project commit sẵn, chưa chọn team nào: điền team cá nhân cạnh mọi CODE_SIGN_STYLE.
    # Có team khác (công ty) thì không đè, chỉ cảnh báo ở dưới.
    if ! $dry_run; then
        perl -pi -e 's/^(\s*)CODE_SIGN_STYLE = Automatic;\n/$1CODE_SIGN_STYLE = Automatic;\n$1DEVELOPMENT_TEAM = '"$TEAM_ID"';\n/' "$xcodeproj/project.pbxproj"
        plutil -lint -s "$xcodeproj/project.pbxproj" || die "project.pbxproj hỏng sau khi điền team — git checkout file đó."
    fi
    ok "DEVELOPMENT_TEAM = $TEAM_ID ($TEAM_NAME) đã điền vào $(rel "$xcodeproj")"
    team_found="filled"
fi
if [ "$team_found" = "filled" ]; then
    :
elif [ "$team_found" = "$TEAM_ID " ]; then
    ok "DEVELOPMENT_TEAM = $TEAM_ID ($TEAM_NAME)"
else
    warn "DEVELOPMENT_TEAM ${team_found:+đang là $team_found}${team_found:-chưa đặt}. Đặt $TEAM_ID ($TEAM_NAME) cho mọi target (project.yml hoặc Signing & Capabilities) để build ở máy ký cùng team với Xcode Cloud."
fi
if grep -qs 'CODE_SIGN_STYLE[ :=]*"\{0,1\}Manual' "$project_dir/project.yml" "$xcodeproj/project.pbxproj"; then
    warn "Có target ký Manual. Xcode Cloud cần Automatic signing để tự quản chứng chỉ."
fi

# 6. Dọn CI cũ (fastlane công ty, runner self-hosted).
old=()
[ -d "$project_dir/fastlane" ] && old+=("$(rel "$project_dir/fastlane")")
[ -f "$project_dir/Gemfile" ] && grep -qs fastlane "$project_dir/Gemfile" && old+=("$(rel "$project_dir/Gemfile")")
while IFS= read -r wf; do
    [ -n "$wf" ] && old+=("$(rel "$wf")")
done < <(grep -lsE 'fastlane|self-hosted' "$repo_root"/.github/workflows/*.yml "$repo_root"/.github/workflows/*.yaml 2>/dev/null || true)
if [ "${#old[@]}" -eq 0 ]; then
    ok "Không còn fastlane hay workflow self-hosted"
elif $remove_fastlane; then
    for p in "${old[@]}"; do
        run git -C "$repo_root" rm -rq --ignore-unmatch -- "$p"
        [ -e "$repo_root/$p" ] && run rm -rf "${repo_root:?}/$p"
        ok "Đã xoá $p"
    done
    # Docs của KVAppBase mô tả fastlane ở hai chỗ cố định. Khớp đúng mốc thì thay bằng
    # mô tả Xcode Cloud; repo khác template thì chỉ cảnh báo, không đoán.
    readme="$repo_root/README.md"; agents="$repo_root/AGENTS.md"
    if [ -f "$readme" ] && grep -q '^## CI/CD$' "$readme"; then
        $dry_run || SNIP="$(cat "$KIT_DIR/snippets/README-ci.md")" \
            perl -0pi -e 's/^## CI\/CD\n.*?(?=^## )/$ENV{SNIP}\n\n/ms' "$readme"
        ok "README.md: mục CI/CD viết lại cho Xcode Cloud"
    fi
    if [ -f "$agents" ] && grep -q '^fastlane ios ' "$agents"; then
        if ! $dry_run; then
            SNIP="$(cat "$KIT_DIR/snippets/AGENTS-ci.md")" perl -0pi -e '
                s/\n(?:fastlane ios [^\n]*\n)+//g;
                s/^`verify\.sh` runs in CI on every push and PR.*?\n\n/$ENV{SNIP}\n/ms;
                s/The build number is never edited:\n.*?\n\n/The build number is never edited: Xcode Cloud assigns it when archiving.\n\n/ms;
            ' "$agents"
        fi
        ok "AGENTS.md: bỏ lệnh fastlane, mô tả Xcode Cloud"
    fi
    # Bỏ qua chính câu mô tả Xcode Cloud vừa chép vào và dòng exclude của check-arch.
    left="$(grep -rnI --exclude-dir=.git --exclude-dir=xcode-cloud --exclude-dir=ci_scripts \
            --include='*.md' --include='*.sh' --include='*.yml' -e fastlane -e self-hosted "$repo_root" 2>/dev/null \
        | grep -vF -e "-not -name 'fastlane'" \
        | grep -vFf <(sed 's/^ *//' "$KIT_DIR"/snippets/*.md | grep -e fastlane -e self-hosted) \
        | cut -d: -f1 | sort -u || true)"
    if [ -n "$left" ] && ! $dry_run; then
        warn "Còn nhắc fastlane/self-hosted, sửa tay: $(echo "$left" | while read -r f; do rel "$f"; done | tr '\n' ' ')"
    fi
else
    for p in "${old[@]}"; do warn "CI cũ còn đó: $p (chạy lại với --remove-fastlane để xoá)"; done
fi

cat <<EOF

Việc còn lại trong Xcode (chi tiết: KVAppKit/xcode-cloud/README.md):
  1. git add $(rel "$ci_dir") .gitignore${resolved:+ $(rel "$resolved")} && commit && push
  2. Xcode → Report navigator (⌘9) → Cloud → Create Workflow, chọn app, team $TEAM_NAME
  3. Workflow Verify: Start = Branch main + Pull Request · Action = Test (scheme có test)
  4. Workflow Release: Start = Tag v* (hoặc chỉ bấm tay) · Action = Archive, TestFlight & App Store
     · Post-action = TestFlight Internal Testing
  5. App Store Connect → app → Xcode Cloud → Settings → Build Number: số lớn hơn build cao nhất đã upload
EOF
[ "$warnings" -eq 0 ] || printf '\n\033[33m%d cảnh báo ở trên cần xem.\033[0m\n' "$warnings"
