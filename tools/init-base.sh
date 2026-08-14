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

  --with-api     App có gọi backend. Giữ Data/, APIClientFactory, KVNetworkit.
  --with-auth    App có đăng nhập. Bao hàm --with-api, thêm keychain + session.
  --keep-demo    Giữ nguyên màn Order/SignIn của template (để đọc, không để ship).

  --source URL   Repository KVAppBase khác.
  --ref REF      Branch hoặc tag khác.
  --verify       Chạy tools/verify.sh sau khi khởi tạo.
  --help

Không cờ nào = app tool: không network, không đăng nhập. Đó là mặc định vì nó là
thứ dễ thêm vào nhất và khó gỡ ra nhất — một app tool mang sẵn tầng auth thì
tầng đó sẽ ở lại mãi.
EOF
}

fail() { printf 'init-base: %s\n' "$*" >&2; exit 1; }

kit_root="$(cd "$(dirname "$0")/.." && pwd)"
config="$kit_root/config/base-template.env"
[[ -f "$config" ]] || fail "thiếu config/base-template.env"
# shellcheck disable=SC1090
source "$config"

app_name=""; bundle_id=""; verify=false
with_api=false; with_auth=false; keep_demo=false
source_repo="${KVAPP_BASE_REPOSITORY:-}"; base_ref="${KVAPP_BASE_REF:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)      app_name="${2:-}"; shift 2 ;;
    --bundle-id) bundle_id="${2:-}"; shift 2 ;;
    --with-api)  with_api=true; shift ;;
    --with-auth) with_auth=true; shift ;;
    --keep-demo) keep_demo=true; shift ;;
    --source)    source_repo="${2:-}"; shift 2 ;;
    --ref)       base_ref="${2:-}"; shift 2 ;;
    --verify)    verify=true; shift ;;
    --help)      usage; exit 0 ;;
    *)           fail "tham số lạ: $1" ;;
  esac
done

# Đăng nhập mà không có API là tổ hợp không tồn tại — token lấy từ đâu.
$with_auth && with_api=true
# Demo *là* bản đầy đủ: nó đang chứng minh cả hai tầng còn chạy.
if $keep_demo; then with_api=true; with_auth=true; fi

if $with_auth;  then tier="auth"
elif $with_api; then tier="api"
else                 tier="tool"
fi

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

# `cp -R KVAppKit/. .` copy cả `.git` của kit đè lên `.git` vừa `git init` — repo app
# thừa hưởng nguyên lịch sử VÀ remote của kit, nên `git push` đầu tiên bắn vào
# KVAppKit. Đo được: clone thử theo đúng hướng dẫn cũ thì `git log` ra commit của kit
# và `origin` là KVAppKit.git. Chặn ở đây vì lúc này repo chưa có gì để mất.
if git -C "$kit_root" remote get-url origin 2>/dev/null | grep -q 'KVAppKit'; then
  fail "origin đang trỏ về KVAppKit — repo này đang mang lịch sử git của kit.
  Sửa:  rm -rf .git && git init && git remote add origin <repo app của bạn>
  Lần sau copy kit bằng:  rsync -a --exclude .git --exclude .DS_Store /path/KVAppKit/ ."
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'Kéo %s @ %s\n' "$source_repo" "$base_ref"
# `advice.detachedHead=false`: clone theo tag luôn ra detached HEAD, và git in ra sáu
# dòng khuyên nhủ đọc y như một lỗi. Repo tạm này bị xoá ngay sau đó, không ai commit
# vào nó cả.
git clone --quiet --depth 1 -c advice.detachedHead=false --branch "$base_ref" \
  "$source_repo" "$tmp/base" 2>/dev/null \
  || fail "clone thất bại — kiểm tra --source / --ref (đang dùng: $source_repo @ $base_ref)"
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

# ---------------------------------------------------------------------------
# Cắt template về đúng tier.
#
# Nguyên tắc: **tier là tập file, không phải nội dung file.** Gần như mọi khác
# biệt giữa ba tier là một file có mặt hay không, nên ở đây chỉ có `rm`. Bốn file
# không chịu được quy tắc đó — mọi tier đều cần chúng, với nội dung khác nhau — nên
# chúng sống trong config/overlays/ và được chép đè sau khi xoá:
#
#   shared/    AppDeepLink            — mọi tier
#   auth/      RootView · AppRoutes   — tier auth
#   no-auth/   RootView · AppRoutes · MyApp — tier tool và api
#
# Mỗi bản copy trong overlay là một chỗ có thể trôi khỏi base. Bốn thì còn canh
# bằng mắt được; nếu con số này bò lên quá năm sáu, đó là dấu hiệu nên tách hẳn
# một repo skeleton chứ không vá bằng overlay nữa.
# ---------------------------------------------------------------------------
strip() {
  local path
  for path in "$@"; do rm -rf "$kit_root/$path"; done
}

if ! $keep_demo; then
  printf 'Tier: %s\n' "$tier"

  # Demo là **luồng Order** — màn hình mẫu và mọi thứ chỉ tồn tại để phục vụ nó.
  # Luồng Auth thì không: nó ở lại cùng tier auth, vì một màn đăng nhập đã nối
  # sẵn use case, keychain và SessionController thì sửa cho khớp backend rẻ hơn
  # nhiều so với dựng lại từ đầu.
  strip Features/Order \
        Domain/Entities/Order.swift Domain/Entities/Order+Samples.swift \
        Domain/Repositories/OrderRepositoryProtocol.swift \
        Data/DTO/OrderDTO.swift Data/Repositories/OrderRepository.swift \
        Data/Network/Endpoints/OrderEndpoint.swift Data/Testing/OrderStubs.swift \
        DI/Dependencies+Order.swift \
        Tests/DataTests/OrderRepositoryTests.swift \
        Tests/FeatureTests/OrderDetailViewModelTests.swift \
        Tests/FeatureTests/OrderListViewModelTests.swift

  # Auth: màn đăng nhập, keychain, session, guard, refresh token.
  if ! $with_auth; then
    strip Features/Auth \
          App/Session App/Bootstrap/AppBootstrap+Tokens.swift \
          App/Navigation/Middlewares/AuthGuardMiddleware.swift \
          Domain/Entities Domain/UseCases Domain/Repositories \
          Domain/Services/TokenStoring.swift \
          Data/Local Data/Network/Interceptors \
          Data/DTO Data/Repositories Data/Testing Data/Network/Endpoints \
          DI/Dependencies+Auth.swift DI/Dependencies+Session.swift \
          Tests/DomainTests Tests/FeatureTests
  fi

  # API: cả tầng Data biến mất, và KVNetworkit không còn được link.
  if ! $with_api; then
    strip Data DI/Dependencies+Network.swift Tests/DataTests
  fi

  rsync -a "$kit_root/config/overlays/shared/" "$kit_root/"
  if $with_auth; then
    rsync -a "$kit_root/config/overlays/auth/" "$kit_root/"
  else
    rsync -a "$kit_root/config/overlays/no-auth/" "$kit_root/"
  fi

  # Luật 9 của check-arch: folder rỗng là một lời khai về kiến trúc không còn
  # đúng. `-delete` chạy depth-first, nên folder cha rỗng đi vì con vừa bị xoá
  # cũng bị dọn trong cùng một lượt.
  find "$kit_root"/{Core,Domain,Data,DI,DesignSystem,Features,App,Tests} \
    -type d -empty -delete 2>/dev/null || true

  # project.yml: chỉ tier tool phải sửa — nó là tier duy nhất không link
  # KVNetworkit và không còn folder Data/ để khai trong `sources`.
  if ! $with_api; then
    perl -0pi -e 's/^  KVNetworkit:\n(?:    .*\n)+//m'          "$kit_root/project.yml"
    perl -0pi -e 's/^      - package: KVNetworkit\n        product: KVNetworkit\n//mg' "$kit_root/project.yml"
    perl -0pi -e 's/^      - path: Data\n//m'                   "$kit_root/project.yml"
  fi

  # README: luật 10 so *tên folder* đầu dòng với đĩa, nên dòng Data/ phải đi khi
  # folder đi. Phần mô tả thì luật không đọc — nhưng một README kể về `Order/`
  # trong repo không có `Order/` dạy sai đúng cái mà luật 10 sinh ra để chặn.
  readme="$kit_root/README.md"
  perl -pi -e 's|^Features/.*|Features/       một folder là một luồng, không phải một màn|' "$readme"
  perl -pi -e 's|^App/.*|App/            entry · Navigation · Bootstrap · Resources|'                         "$readme"
  domain_line='Domain/         Services (port) — protocol mà app định nghĩa, Data đi hiện thực'
  if $with_auth; then
    perl -pi -e 's|^App/.*|App/            entry · Navigation · Bootstrap · Session · Resources|'  "$readme"
    perl -pi -e 's|^Tests/.*|Tests/          CoreTests · DomainTests · DataTests · FeatureTests|'  "$readme"
    perl -pi -e 's|^Data/.*|Data/           DTO · Network/{Endpoints,Interceptors} · Mapping · Local · Repositories · Testing|' "$readme"
    perl -pi -e 's|^Features/.*|Features/       Auth/          một folder là một luồng, không phải một màn|' "$readme"
    domain_line='Domain/         Entities · Repository protocol · Services (port) · UseCase'
  elif $with_api; then
    perl -pi -e 's|^Tests/.*|Tests/          CoreTests · DataTests|' "$readme"
    perl -pi -e 's|^Data/.*|Data/           Network · Mapping|'      "$readme"
  else
    domain_line='Domain/         Services (port) — protocol thuần, không framework'
    perl -pi -e 's|^Tests/.*|Tests/          CoreTests|' "$readme"
    perl -0pi -e 's|^Data/.*\n||m'                       "$readme"
  fi
  DOMAIN_LINE="$domain_line" perl -pi -e 's|^Domain/.*|$ENV{DOMAIN_LINE}|' "$readme"

  # Mục "Có gì trong này" của base kể về slice demo. Trong repo app nó vừa sai vừa
  # là thứ người ta đọc đầu tiên — và `doctor.sh` bắt được nó, vì nó nhắc
  # `Features/Order` bằng backtick.
  # Heredoc có delimiter trong nháy đơn: nội dung không bị shell diễn giải. Bản
  # đầu dùng chuỗi nháy kép và backtick trong đó thành command substitution —
  # shell đi *chạy* `App/RootView.swift`, `set -e` giết script giữa chừng, và
  # bước dọn cuối cùng không bao giờ tới. Triệu chứng là repo app còn nguyên
  # `config/` và `HANDOFF.md` của kit, cách xa nguyên nhân.
  blurb="$(cat <<'BLURB_COMMON'
## Có gì trong này

- **`Core`** + **`DesignSystem`** — `Loadable`, `AlertState`, `AppError`, và bộ
  modifier/component dùng chung: `onFirstAppear`, `alert(_:onDismiss:)`,
  `cardStyle`, `dismissKeyboardOnTap`, `LoadableContent`, `RemoteImage`.
- **19 ngôn ngữ** đã dựng sẵn, đổi được ngay trong app.
- **11 luật kiến trúc** + `./tools/verify.sh` (self-test → build → test).
BLURB_COMMON
)"

  case "$tier" in
    tool) blurb="$blurb$(cat <<'BLURB_TOOL'


Chưa có màn nào. `App/RootView.swift` là chỗ bắt đầu.
BLURB_TOOL
)" ;;
    api) blurb="$blurb$(cat <<'BLURB_API'
- **`Data`** — `APIClientFactory` (interceptor có thứ tự), và map lỗi transport
  về `AppError` ở đúng một chỗ.

Chưa có màn nào. `App/RootView.swift` là chỗ bắt đầu.
BLURB_API
)" ;;
    auth) blurb="$blurb$(cat <<'BLURB_AUTH'
- **`Data`** — `APIClientFactory`, refresh token, keychain, map lỗi về `AppError`.
- **`Features/Auth`** — sign-in đã nối use case, keychain và `SessionController`;
  sửa endpoint và DTO cho khớp backend là chạy được.

Màn sau khi đăng nhập là chỗ trống có chủ đích — xem `App/RootView.swift`.
BLURB_AUTH
)" ;;
  esac

  BLURB="$blurb" perl -CSD -0pi -e 's/^## Có gì trong này\n.*?(?=^## )/$ENV{BLURB}\n/ms' "$readme"

  # .strings: key của demo không vi phạm luật nào — check-l10n đi từ code sang
  # bảng, không ngược lại — nhưng để lại 38 key cho một app chưa có màn nào là
  # giao rác. Chỉ xoá key không còn file .swift nào nhắc tới: một key còn được
  # nhắc ở bất kỳ đâu đều được giữ, nên bước này không bao giờ làm app mất chữ.
  dead=""
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    grep -rqF "$key" --include='*.swift' "$kit_root" 2>/dev/null || dead="$dead$key"$'\n'
  done < <(perl -ne 'print "$1\n" if /^"(.+?)" = /' "$kit_root/App/Resources/en.lproj/Localizable.strings")

  if [[ -n "$dead" ]]; then
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      # Xoá dòng key, kèm dòng comment ngay trên nó nếu có.
      KEY="$key" perl -CSD -0pi -e '
        my $k = quotemeta $ENV{KEY};
        s{(?:^/\*[^\n]*\*/\n)?^"$k" = "(?:[^"\\]|\\.)*";\n}{}m;
        s/\n{3,}/\n\n/g;
      ' "$kit_root"/App/Resources/*.lproj/Localizable.strings
    done <<< "$dead"
    printf 'Đã xoá %s key l10n không còn code nào dùng (× 19 ngôn ngữ)\n' \
      "$(grep -c . <<< "$dead")"
  fi
fi

# Base tự giới thiệu là template trong một khối có marker; repo mới thì không phải.
perl -0pi -e 's/<!-- template-only:start -->.*?<!-- template-only:end -->\n\n?//s' "$kit_root/README.md"
perl -pi -e "s/^# KVAppBase$/# $app_name/" "$kit_root/README.md"

# Cùng cơ chế cho AGENTS.md: khối "Initialise first" nói về việc vừa làm xong, và
# nó trỏ vào `tools/init-base.sh` — file bị xoá ở cuối script này.
perl -0pi -e 's/<!-- kit-only:start -->.*?<!-- kit-only:end -->\n\n?//s' "$kit_root/AGENTS.md"

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

# Dọn thứ chỉ có nghĩa trong kit. `HANDOFF.md` là sổ ghi lịch sử của kit — nó vừa bị
# lần đổi tên ở trên viết vào (nó là `.md`), nên trong repo app nó là một văn bản nói
# về `DemoAppTests` trong một câu chuyện chưa từng xảy ra ở đây. `config/` và
# `init-base.sh` là công cụ *tạo* project, vô nghĩa trong project đã tạo — và script
# này sẽ tự từ chối chạy lần hai.
rm -f  "$kit_root/HANDOFF.md" "$kit_root/.DS_Store" "$kit_root/tools/init-base.sh"
rm -rf "$kit_root/config"

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
