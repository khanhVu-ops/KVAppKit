#!/usr/bin/env bash
#
# Kéo KVAppBase theo một ref xác định vào repository trống, rồi đổi danh tính app.
#
# Kit và template tách nhau có lý: base tiến hoá độc lập với skill, nên skill
# không phải ôm một bản copy source luôn lạc hậu.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./tools/init-base.sh --name "App Name" --bundle-id com.company.app [options]

  --source URL   Repository KVAppBase khác.
  --ref REF      Branch hoặc tag khác.
  --verify       Chạy tools/verify.sh sau khi khởi tạo.
  --help
EOF
}

fail() { printf 'init-base: %s\n' "$*" >&2; exit 1; }

kit_root="$(cd "$(dirname "$0")/.." && pwd)"
config="$kit_root/config/base-template.env"
[[ -f "$config" ]] || fail "thiếu config/base-template.env"
# shellcheck disable=SC1090
source "$config"

app_name=""; bundle_id=""; verify=false
source_repo="${KVAPP_BASE_REPOSITORY:-}"; base_ref="${KVAPP_BASE_REF:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)      app_name="${2:-}"; shift 2 ;;
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --source)    source_repo="${2:-}"; shift 2 ;;
    --ref)       base_ref="${2:-}"; shift 2 ;;
    --verify)    verify=true; shift ;;
    --help)      usage; exit 0 ;;
    *)           fail "tham số lạ: $1" ;;
  esac
done

[[ -n "$app_name" ]]  || fail "--name là bắt buộc"
[[ -n "$bundle_id" ]] || fail "--bundle-id là bắt buộc"
[[ "$bundle_id" =~ ^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*){1,}$ ]] \
  || fail "bundle id không hợp lệ: $bundle_id"

for cmd in git rsync perl; do
  command -v "$cmd" >/dev/null || fail "thiếu lệnh: $cmd"
done

# Từ chối chạy trên repo đã có source — mất code tệ hơn là phải chạy lại lệnh.
for guard in App Packages project.yml; do
  [[ -e "$kit_root/$guard" ]] && fail "đã có '$guard' — init-base chỉ dùng cho repo mới"
done
compgen -G "$kit_root/*.xcodeproj" >/dev/null && fail "đã có .xcodeproj — init-base chỉ dùng cho repo mới"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'Kéo %s @ %s\n' "$source_repo" "$base_ref"
git clone --quiet --depth 1 --branch "$base_ref" "$source_repo" "$tmp/base" \
  || fail "clone thất bại — kiểm tra --source / --ref"
resolved_sha="$(git -C "$tmp/base" rev-parse --short HEAD)"
rm -rf "$tmp/base/.git"

# Kit sở hữu rule và skill; template không được ghi đè chúng.
#
# README.md thì ngược lại: **lấy của base**. README của kit nói cách tạo project,
# vô dụng trong repo đã tạo — mà luật 10 của check-arch.sh lại đọc README để so
# với cây source, nên giữ README của kit là fail ngay ./tools/verify.sh đầu tiên.
#
# `.claude` không bị exclude cả cụm: kit sở hữu skill/agent/command, còn base sở
# hữu `.claude/settings.json` (hook xcodegen). Cấm cả `.claude` thì hook không bao
# giờ tới được repo app, mà copy hook sang kit là lại có hai bản để lệch nhau.
rsync -a \
  --exclude 'AGENTS.md' --exclude 'CLAUDE.md' \
  --exclude '.claude/skills' --exclude '.claude/agents' --exclude '.claude/commands' \
  --exclude '.agents' --exclude 'config' \
  --exclude 'tools/init-base.sh' \
  "$tmp/base/" "$kit_root/"

# Base tự giới thiệu là template trong một khối có marker; repo mới thì không phải.
perl -0pi -e 's/<!-- template-only:start -->.*?<!-- template-only:end -->\n\n?//s' "$kit_root/README.md"
perl -pi -e "s/^# KVAppBase$/# $app_name/" "$kit_root/README.md"

# Đổi danh tính. Tên module Swift phải là identifier hợp lệ.
module_name="$(printf '%s' "$app_name" | perl -pe 's/[^A-Za-z0-9]//g')"
[[ -n "$module_name" ]] || fail "--name phải chứa ít nhất một chữ hoặc số"

# Quét cả repo, không chỉ App/ + project.yml. Bản đầu chỉ đổi hai chỗ đó, nên
# `@testable import MyApp` trong Tests/ ở lại và test target của repo mới không
# compile. AGENTS.md và skill cũng nhắc `MyApp.xcodeproj` — rule mô tả sai cây
# source là cách base project trước đó đã trôi.
#
# `\bMyApp` không có \b ở cuối là có ý: để `MyAppTests` thành `<Module>Tests`.
find "$kit_root" \
  \( -name '.git' -o -name '*.xcodeproj' \) -prune -o \
  -type f \( -name '*.swift' -o -name '*.yml' -o -name '*.plist' -o -name '*.md' \
             -o -name 'Appfile' -o -name 'Fastfile' \) -print0 \
  | xargs -0 perl -pi -e "s/\bMyApp/$module_name/g; s/\bcom\.example\.myapp\b/$bundle_id/g; s/\bcom\.example\b/${bundle_id%.*}/g"

perl -pi -e "s/^name: .*/name: $module_name/" "$kit_root/project.yml"
perl -pi -e "s|<string>$module_name</string>|<string>$app_name</string>|" "$kit_root/App/Resources/Info.plist"

# File entry point mang tên struct; struct vừa đổi thì file phải đi theo.
if [[ -f "$kit_root/App/MyApp.swift" ]]; then
  mv "$kit_root/App/MyApp.swift" "$kit_root/App/$module_name.swift"
fi

command -v xcodegen >/dev/null && (cd "$kit_root" && xcodegen generate --quiet) \
  || echo "xcodegen chưa cài — chạy 'brew install xcodegen' rồi 'xcodegen generate'"

cat <<EOF

Đã khởi tạo.
  KVAppBase   : $source_repo @ $base_ref ($resolved_sha)
  App         : $app_name
  Module/target: $module_name
  Bundle id   : $bundle_id

Việc tiếp theo:
  1. ./tools/verify.sh
  2. Cập nhật AGENTS.md — mục App Features và bảng module, để rule khớp source thật.
  3. Sửa API_BASE_URL cho từng configuration trong project.yml.
EOF

$verify && (cd "$kit_root" && ./tools/verify.sh)
