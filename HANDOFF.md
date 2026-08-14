# Bàn giao — iOS base project + bộ skill

Mở session mới thì đưa file này cho Claude Code trước. Nó chứa **trạng thái**,
**quyết định đã chốt kèm lý do**, và **những cái bẫy đã trả giá để biết** — phần
đắt nhất không phải code, mà là lý do đằng sau nó.

Cập nhật: 2026-08-14.

---

## 1. Hai repo

```
/Users/khanhvu/personal/KVAppBase   template — app chạy được   73a5c56
/Users/khanhvu/personal/KVAppKit    kit rule + skill           (xem git log)
```

Tách kit khỏi template theo đúng mô hình starter kit Android của VarMeta
(`/Users/khanhvu/VarMeta/AND-Varmeta/AND-Authenticator`): base tiến hoá độc lập
với skill, nên skill không ôm một bản copy source luôn lạc hậu.

### KVAppBase — 74 file Swift, chạy được

```
Core/           Loadable · AlertState · AppError · AppEnvironment
Domain/         Entities · Repositories(protocol) · Services(port) · UseCases
Data/           DTO · Network/{Endpoints,Interceptors} · Mapping · Local · Repositories · Testing
DI/             mọi KVDependencyKey, và nơi duy nhất
DesignSystem/   Foundation(token) · Components · Modifiers · Toast · Resources/Tokens.xcassets
Features/       Auth/ · Order/        một folder là một luồng, không phải một màn
App/            entry · Navigation · Bootstrap · Session · Resources/<19 lang>.lproj
Tests/          DomainTests · DataTests · FeatureTests
tools/          check-arch{,-selftest}.sh · check-l10n{,-selftest}.sh · verify.sh · xcodegen-if-needed.sh
fastlane/       build_only · beta · web_test · release
.github/        verify.yml (push + PR) · release.yml (bấm tay)
```

**Một app target, phân tầng bằng folder.** Không có SPM package (đã từng có, đã
gộp bỏ theo yêu cầu).

Kiểm mọi thứ bằng một lệnh:

```bash
cd /Users/khanhvu/personal/KVAppBase && ./tools/verify.sh
```

Nó chạy: 11 luật kiến trúc → 12 self-test cho chính các luật đó → `check-l10n.sh`
(38 key × 19 ngôn ngữ, baseline **còn 0**) → self-test cho nó → xcodegen → build +
22 test. Trạng thái hiện tại (14/08): **tất cả xanh**.

Đăng nhập trong Debug: **email hợp lệ bất kỳ + mật khẩu ≥ 6 ký tự**
(`a@b.com` / `123456`). Debug dùng fixtures qua cờ `USES_STUB_BACKEND`; đặt `NO`
trong `project.yml` ngay khi có API thật.

Đã tag **`v1.0.0`** tại `73a5c56`, và `config/base-template.env` pin đúng tag đó thay
vì `main`: hai người tạo project cách nhau một tuần mà lấy hai cây source khác nhau
thì không ai tái lập được lỗi của ai.

### KVAppKit — 11/14 skill

| Có | Nội dung |
|---|---|
| `ios-architecture` | SKILL.md + 7 reference (layers, state-action, navigation, di, errors, ios16, review-checklist) |
| `kv-packages` | SKILL.md + 5 reference, một file mỗi package, đã đối chiếu source |
| `ios-feature` | SKILL.md + template feature-spec |
| `ios-l10n` | 19 ngôn ngữ, `LocalizedStringResource`, plural, RTL, đổi ngôn ngữ trong app |
| `ios-endpoint` | một lát mỏng trong `Data`: DTO → path → map lỗi → test |
| `api-intake` | spec OpenAPI/Postman → `docs/API_INVENTORY.md` |
| `ios-verify` | build + test + luật + chạy thật trên simulator (không giữ bản copy script) |
| `ios-troubleshoot` | bảng triệu chứng → nguyên nhân của §3 |
| `ios-review` | quy trình review; luật lấy từ `review-checklist.md` |
| `project-overview` | quét source sinh `PROJECT_OVERVIEW.md` |
| `init-base` | SKILL.md + `tools/init-base.sh` |

Cộng subagent `swiftui-screen`, command `/init-base`, `AGENTS.md` (canonical),
`CLAUDE.md` (chỉ `@AGENTS.md`), `.agents/skills` là **symlink** tới
`.claude/skills` để Codex và Claude Code không thể lệch nhau.

`./tools/doctor.sh` — **9 phép kiểm**, xanh. Luật 8 là mới: doctor so số phép kiểm
README hứa với số kết quả nó thật sự in ra. Nó ra đời vì README nói 7 trong khi
script đã chạy 8, tức là doctor bắt drift của mọi doc khác trừ dòng doc mô tả chính
nó — đúng bài học đã phải thêm luật 10b vào `check-arch.sh` mới bắt được.

---

## 2. Quyết định đã chốt — và vì sao

Đừng mở lại những cái này nếu không có lý do mới. Phần "vì sao" mới là thứ tốn
công dựng lại.

**iOS 16 tối thiểu, một đường `ObservableObject`.** Không thể cho một ViewModel
vừa `@Observable` (17) vừa `ObservableObject` (16): `@Observable` là macro gắn
conformance vào protocol `@available(iOS 17)`, nên class buộc phải
`@available(iOS 17, *)` và không khởi tạo được trên 16. Cách duy nhất là tự viết
lại machinery của macro — hợp lý cho một class hạ tầng của package, không hợp lý
nhân lên 40 ViewModel. Lên iOS 17 là **diff theo file**, kiến trúc không đổi:
xem `ios-architecture/references/ios16.md`.

**Hệ quả iOS 16 — luật hiệu năng, không phải thẩm mỹ.** `ObservableObject` phát
tín hiệu theo *object*, không theo property. Tách `State` thành nhiều
`@Published` **không giúp gì**. Cách duy nhất hiệu quả là chẻ **view con** nhận
value + closure và cho `Equatable` (`nonisolated static func ==`). Text đang gõ
giữ ở `@State` cục bộ, commit có debounce bằng `.task(id:)`.

**State/Action/send, alert là state.** Một `State` struct `Equatable` +
`enum Action` + `send(_:)` là cửa duy nhất state đổi. Không có kênh `ViewEffect`
như MVI Android: toast là fire-and-forget, điều hướng là command, alert là
*trạng thái màn hình đang ở* nên nó sống qua rebuild và test assert được.

**ViewModel đẩy route, View đẩy view.** VM chỉ thấy `KVRouting` (KVRouterCore,
không SwiftUI) nên `pushView` là bất khả. View dùng `@Environment(\.router)` →
`KVViewRouting` và `pushView { DetailView(order: order) }` khi đã có object.
Route **chỉ** cho màn addressable: deep link, notification, restoration, auth
guard. Ranh giới: `pushView` trong cùng feature, `push(route)` khi xuyên feature.

**Một target, không SPM package.** Đánh đổi có ý thức: bỏ 246 dòng `public`,
nhưng compiler không còn chặn vi phạm phân tầng (file cùng module thấy nhau
không cần `import`). `check-arch.sh` thay thế bằng cách **suy luật từ source** —
đọc tên type khai báo dưới `Data/` rồi tìm chúng ở nơi không được biết.

**`check-arch-selftest.sh` là phần quan trọng nhất.** Nó tạo một vi phạm thật cho
từng luật rồi kiểm script có fail. Viết xong chạy lần đầu là lòi ra luật 4 khớp
`pushView(` mà không khớp `pushView { }` — dạng người ta thật sự viết — tức là
luật đó **pass rỗng** từ lúc ra đời. Một luật im lặng ngừng khớp còn tệ hơn không
có luật, vì dấu tick xanh lúc đó chứng nhận điều ngược lại.

---

## 3. Cạm bẫy đã trả giá

Tất cả đều đã gặp thật trong quá trình dựng. Đừng gặp lại.

| Bẫy | Xử |
|---|---|
| `installGlobally(swizzlingSessionConfigurations: true)` **crash iOS 26** — `+[NSURLSessionConfiguration canInitWithTask:]: unrecognized selector` | dùng `install(in: configuration)` trên configuration của chính client; `installGlobally()` không cờ vẫn an toàn |
| `log show` không hiện os_log mức info/debug | phải có `--info --debug`, nếu không sẽ tưởng code không chạy |
| Test bundle không host thì không link được symbol app | `TEST_HOST` phải trỏ app; `App.init` bỏ qua bootstrap khi `AppEnvironment.isRunningTests` |
| Thêm file mới ở **bất kỳ** folder nào mà chưa `xcodegen generate` | compiler báo "không tìm thấy" dù code có đó |
| Bump version package rồi symbol mới "không tìm thấy" | swiftmodule cũ trong DerivedData — xoá DerivedData **trước khi** tin thông báo lỗi |
| Xoá DerivedData vô cớ | SPM resolve lại từ đầu, build mất nhiều phút. Chỉ xoá khi thật sự nghi cache bẩn |
| `git checkout <file>` để undo thí nghiệm | index có thể còn nội dung **trước** một lần sửa hàng loạt → mất sạch. Backup bằng `cp` |
| `cmd \| grep error: && exit 1` | không bao giờ fire dưới `set -o pipefail` — pipefail trả exit code của `cmd`. Kiểm exit code tường minh |
| Keychain trả `-34018` (`errSecMissingEntitlement`) | build simulator không ký **luôn** trả lỗi này. Report, đừng trap — bản đầu tiên trap và crash lúc đăng nhập |
| `Button` + `.buttonStyle(.plain)` trong `List` | mất vùng chạm cả-ô; cần `.contentShape(Rectangle())`, nếu không row như chết |
| Toạ độ tap trên simulator | là **device point** (402×874), không phải pixel ảnh screenshot (~918×1900). Chia ~2.28 ngang, ~2.17 dọc |
| `cp -R KVAppKit/. .` để dựng repo app | copy cả `.git` của kit đè lên `.git` vừa tạo → repo app mang lịch sử và `origin` của kit, `git push` đầu tiên bắn vào KVAppKit. Dùng `rsync -a --exclude .git` |

---

## 4. Còn phải làm

### 4.0 Đã sửa trong buổi audit 13/08 (đã commit và push)

Tất cả đã chạy lại và xanh. Ghi ra đây vì mỗi cái là một luật đã học.

- **`init-base.sh` chưa từng chạy được end-to-end.** Ba lỗi cùng lúc: repo mới giữ
  README của *kit* (rsync exclude nó) nên luật 10 fail ngay `verify.sh` đầu tiên;
  đổi tên chỉ quét `App/` + `project.yml` nên `@testable import MyApp` ở `Tests/`
  ở lại và test target không compile; `\bMyApp\b` không khớp `MyAppTests` nên
  target test giữ tên template. Giờ: README lấy của base (base có khối
  `<!-- template-only -->` để cắt), quét cả repo kể cả `.md`, dùng `\bMyApp`, và
  `App/MyApp.swift` được rename theo module. **Đã nghiệm thu thật**: init vào một
  repo trống với base local → `verify.sh` xanh, build ra `DemoApp.app`.
- **Luật 10 tính cả `.claude`, `.agents`, `config` là folder tầng** — đó là vì sao
  repo mới fail. Giờ bỏ dot-dir + `tools`/`config`/`docs`.
- **README của base nói "8 luật" khi đã có 10**, và luật 10 vẫn xanh xuyên qua đó
  vì nó chỉ so danh sách folder. Đã sửa số, **và** thêm phép kiểm số luật vào
  chính luật 10 (README hứa bao nhiêu phải bằng số luật script có), kèm probe
  `10b` trong self-test. Cùng bài học của `check-arch-selftest`: kiểm một nửa câu
  thì nửa còn lại được chứng nhận miễn phí.
- **`verify.sh` đỏ giả** vì simulator chết trước khi test runner nối được
  (`Early unexpected exit … signal kill`). Giờ `simctl bootstatus -b` trước, và
  retry **đúng một lần, đúng chữ ký đó** — test fail thật không bao giờ được retry.
- **Ba script trong `ios-verify/scripts/` là bản copy đã lạc hậu** đúng hai luật
  (9, 10) và không ai gọi tới — skill vẫn trỏ `./tools/*.sh`. Đã xoá; SKILL.md nói
  rõ vì sao không giữ copy.
- **`KVAppBase` giờ có `CLAUDE.md` riêng** (trỏ sang kit). Trước đó sửa chính
  template là chạy không rule nào — và drift đã xảy ra thật: subagent
  `swiftui-screen` vẫn nói `FeatureOrder/OrderList/`, layout đã bỏ từ lâu.
- **Version lệch**: `AGENTS.md`/`kv-packages` nói 3.1, bảng nói 3.2.0, project pin
  3.2.1. Đã đồng bộ. Và ⚠️ trong `kvrouterkit.md` về `KVUnhostedRouter.init()`
  chưa `nonisolated` là **sai từ 3.2.1** — nó đã `nonisolated`, base dùng thẳng,
  còn `DI/UnhostedRouter.swift` mà reference dặn viết thì không tồn tại (`di.md`
  cũng trỏ vào file đó; doctor.sh tìm ra chỗ thứ hai này, tôi thì không).
- **Hook `xcodegen`** (base: `tools/xcodegen-if-needed.sh` + `.claude/settings.json`):
  `PostToolUse` trên Write|Edit, generate khi có file `.swift` **mới**, im lặng khi
  chỉ sửa file cũ (kiểm bằng cách grep basename trong `project.pbxproj`). Bẫy số 1
  và số 4 của bảng §3 giờ là hạ tầng, không còn là việc phải nhớ. `init-base` vì thế
  chỉ exclude `.claude/{skills,agents,commands}` chứ không exclude cả `.claude`, để
  hook đi được sang repo app mà không phải nhân bản sang kit.
- **19 ngôn ngữ + skill `ios-l10n`** (base: `Localizable.xcstrings`, `check-l10n.sh`,
  `l10n-baseline.txt`, `check-l10n-selftest.sh`): XcodeGen suy `knownRegions` **từ chính
  catalog**, nên catalog là nguồn duy nhất và build ra 19 `.lproj`. Chốt với người dùng:
  base **không** dịch sẵn, nhưng text **mới** phải đủ 19 bản dịch ngay lúc thêm — nợ cũ
  nằm trong baseline (17 chuỗi) và chỉ được co lại. Text của `Core`/`Domain` thì đã trả:
  `AppError`, `AlertState`, `SignInUseCase` dùng `String(localized:)` (Foundation, nên
  luật 1 nguyên vẹn), 8 chuỗi × 19 ngôn ngữ. Luật `return "..."` phải qua
  `String(localized:)` được **đo trên source trước khi viết**: 9 hit, 8 là text người
  dùng, 0 literal hạ tầng. Nghiệm thu bằng cách mở app `-AppleLanguages (ja)` và thấy
  validate của Domain ra tiếng Nhật; `(ar)` thì layout lật RTL đúng vì DesignSystem chỉ
  dùng leading/trailing.
- **`tools/doctor.sh` + `doctor-selftest.sh`** (kit): 7 phép kiểm, mỗi cái ứng với
  một lỗi đã xảy ra thật trong buổi này, và 8 probe chứng minh chúng còn bắt được.
  Chạy ngay lần đầu là ra hai lỗi thật (`di.md` trỏ file đã xoá, version lệch) và
  hai lỗi trong chính doctor. Từ giờ những drift ở §4.0 là việc của script.

### 4.0b Buổi 14/08 — nghiệm thu init-base lần hai, và cái nó lộ ra

`init-base` đã được nghiệm thu **end-to-end trên base hiện tại** (base đã đổi rất
nhiều từ lần trước: `.strings` thay catalog, CI + 4 lane fastlane, đổi ngôn ngữ
trong app, luật `#Preview`). Đường đi đã chạy thật: `rsync` kit → `init-base.sh`
→ `doctor.sh` → `verify.sh` → `DemoApp.app` build được, 22 test xanh.

Nghiệm thu đó lộ ra bốn thứ, cả bốn đã sửa. Không cái nào làm fail build — đó là
lý do chúng sống được lâu đến vậy:

- **Hướng dẫn tạo project kéo theo cả `.git` của kit.** `git init my-app && cp -R
  KVAppKit/. .` copy `.git` của kit **đè lên** `.git` vừa tạo, nên repo app thừa
  hưởng nguyên lịch sử **và** `origin` của kit — `git push` đầu tiên bắn thẳng vào
  KVAppKit. Đo được, không phải suy luận: chạy đúng hướng dẫn thì `git log` ra
  commit của kit và `git remote -v` ra `KVAppKit.git`. Giờ README dùng
  `rsync -a --exclude .git`, và `init-base.sh` **từ chối chạy** khi thấy origin trỏ
  về KVAppKit — chặn lúc repo còn trống là lúc rẻ nhất.
- **Repo app mang theo rác của kit.** `HANDOFF.md` (file này) đi sang, rồi bị chính
  bước đổi tên viết vào — thành một văn bản nói về `DemoAppTests` trong một câu
  chuyện chưa từng xảy ra ở repo đó. Cộng `config/` và `tools/init-base.sh`, hai
  công cụ *tạo* project nằm trong project đã tạo. `init-base.sh` giờ tự dọn, kể cả
  tự xoá chính nó.
- **`AGENTS.md` dặn chạy một file không còn tồn tại.** Khối "Initialise first" nói
  về việc vừa làm xong và trỏ vào `tools/init-base.sh`. Giờ nó nằm giữa marker
  `<!-- kit-only -->` và bị cắt đúng như khối `template-only` của README.
- **`doctor.sh` báo đỏ trong mọi repo app vừa init.** Luật 1 đòi symlink phải được
  git track, nhưng repo vừa `git init` thì chưa `git add` gì cả — không có gì để
  track. Một phép kiểm báo đỏ cho trạng thái *đúng* sẽ dạy người ta bỏ qua màu đỏ,
  nên nó chuyển thành skip có giải thích. Cùng lý do, luật 8 (số phép kiểm README
  hứa) chỉ áp dụng trong repo kit: README của repo app đến từ KVAppBase và mô tả
  app, bắt nó nói về doctor là bắt sai file.

### 4.1 Ba skill chưa viết

**Đã viết trong buổi 13/08 (6)** — `ios-l10n` (xem §4.0), và `ios-troubleshoot` (bảng §3 giờ là skill, không
còn nằm một mình trong file này), `ios-endpoint`, `api-intake`, `ios-review`,
`project-overview`. Lệnh quét trong `project-overview` đã chạy thật trên base, không
phải lệnh tưởng tượng; `ios-endpoint` lấy đúng API của `KVMockNetworkSession` và
`perform(_:_:)` trong repo. Còn lại:

**Bị chặn (2)** — cùng một câu hỏi chưa có lời đáp:

> Base Android dùng **AppSpec MCP** nội bộ (`get_screen_flow`,
> `get_design_context`, `download_figma_images`), nhưng câu trả lời cho iOS là
> **Figma Dev Mode MCP**. Hai cái khác nhau cả tool lẫn dữ liệu: AppSpec cho *đồ
> thị điều hướng* (thứ làm `PLAN.md` bên Android hay), Dev Mode cho *Figma
> Variables* (token thật). **Cần biết AppSpec MCP có dùng được cho iOS không.**

- `figma-intake` — Figma → design token + `DESIGN_TOKENS.md`
- `figma-screen` — một node Figma → SwiftUI View

**Không bị chặn (1)** — làm được ngay:

- `ios-project` — sửa `project.yml`: thêm configuration, Info.plist key,
  entitlement, scheme, package. Hiện chỉ có một dòng `xcodegen generate` trong
  `ios-verify`.

### 4.2 Skill vẫn chưa được nghiệm thu — nhưng giờ có cân

Vẫn là lỗ hổng lớn nhất, và nói cho chính xác: **cân đã có, chưa cân lần nào.**

`tools/measure-skill.sh` chạy cùng một prompt hai lần trên cùng một repo app — một
lần bình thường, một lần với `--settings '{"skillOverrides":{"<skill>":"off"}}'` —
rồi assert bằng regex `expect:`/`reject:`. Case nằm ở `tools/measure/*.cases`: đã
viết 5 case cho `kv-packages` (gồm đúng prompt hero-zoom ghi ở đây trước đây) và 5
cho `ios-architecture`, cố tình chọn những câu nghe *nhỏ* — "thêm một field", "tách
row ra view con" — vì đó là lúc người ta bỏ qua skill nhiều nhất.

Ba kết quả, và chỉ một cái là tin tốt:

| có skill | không skill | nghĩa là |
|---|---|---|
| PASS | FAIL | skill có tác dụng — đây là thứ cần chứng minh |
| PASS | PASS | prompt không đo được gì, model tự đúng. Đổi prompt khó hơn hoặc bỏ |
| FAIL | — | skill chưa nói đủ rõ. Sửa **skill**, đừng sửa case cho vừa |

`tools/measure-selftest.sh` chứng minh cái cân phân biệt được đúng ba trường hợp đó,
bằng một `claude` giả trả lời theo kịch bản. Không có nó thì một lỗi parse trong
harness sẽ đọc y như "skill không có tác dụng" — kết luận sai đắt nhất có thể rút ra
ở đây.

**14/08: cân đã được kiểm, vẫn chưa cân được.**

```bash
./tools/measure-selftest.sh    # ✓ 4/4 — cái cân phân biệt đúng ba trường hợp trên
```

Nhưng `measure-skill.sh` thì dừng ngay ở guard đầu tiên: `cần claude CLI trên PATH`.
Máy này chạy Claude Code **bản desktop**, và bản desktop không cài CLI —
`npm ls -g` không có `@anthropic-ai/claude-code`, `which claude` không ra gì. Đây là
cùng một chỗ tắc của buổi trước nhưng vì lý do khác, nên nói cho rõ để lần sau không
mất công tìm lại:

```bash
npm i -g @anthropic-ai/claude-code                          # thứ còn thiếu
./tools/measure-skill.sh --all --in /path/to/app-repo       # rồi cân thật
```

`--in` phải là một repo **đã init-base** (có `.claude/skills` + `project.yml`): đo
trong repo kit thì model không có cây source nào để bắt chước, và kết quả vô nghĩa.
Repo dùng để nghiệm thu 14/08 dựng đúng cách đó, và dựng lại mất 2 phút.

Đừng thay bằng cách gọi subagent trong một session Claude Code: cột đáng đọc là cột
**không skill**, mà `skillOverrides` chỉ tắt được qua `--settings` của CLI. Không có
cột đó thì bài đo mất đúng thứ nó sinh ra để chứng minh.

### 4.3 Skill chưa được cài ở đâu

`~/.claude/skills/` trống. `KVAppBase` giờ có `CLAUDE.md` trỏ sang kit (13/08),
nhưng vẫn không có `.claude/skills/` — nên trong repo template, skill phải được đọc
thủ công theo đường dẫn, không tự load. Muốn nghiệm thu thì phải nạp trước:

```bash
# tạm thời, để đo — symlink chứ không copy
mkdir -p ~/.claude && ln -s /Users/khanhvu/personal/KVAppKit/.claude/skills ~/.claude/skills
```

Cách chính thức là kit đi cùng repo app:

```bash
git init my-app && cd my-app
rsync -a --exclude .git --exclude .DS_Store /Users/khanhvu/personal/KVAppKit/ .
# rồi trong Claude Code:  /init-base "My App" com.company.myapp
```

**Không** `cp -R KVAppKit/. .` — xem §4.0b: nó copy cả `.git` của kit, và repo app
thừa hưởng lịch sử lẫn `origin` của kit.

### 4.4 Ba việc nhỏ trong KVRouterKit (không gấp)

- `KVNavigationTransition` vẫn `@MainActor`, chưa `Sendable` → không nhét được
  vào type `Sendable`, và vì thế chưa làm được transition mặc định theo route.
- Registry chưa map route → transition; hiện chỉ map route → view.
- `kvRoutes` chạy `configure` **một lần**: destination không được capture state
  thay đổi được. Đáng thêm một dòng cảnh báo vào doc của package.

Và một bug đã báo: `swizzlingSessionConfigurations: true` của KVLoggingKit crash
trên iOS 26 — là API public có tài liệu. Cơ chế chưa xác minh (nghi
`class_getInstanceMethod` leo lên superclass nên exchange rơi vào
`NSURLSessionConfiguration` thay vì subclass private), nhưng bật thì crash, tắt
thì không.

---

## 5. Bắt đầu session mới thế nào

Câu mở đầu gợi ý:

> Đọc `/Users/khanhvu/personal/KVAppKit/HANDOFF.md`. Tiếp tục từ §4.2: cài
> `@anthropic-ai/claude-code`, dựng một repo app bằng `init-base`, rồi chạy
> `measure-skill.sh --all` để cân `kv-packages` và `ios-architecture`. Xong thì
> viết skill `ios-project` (§4.1).

Việc chưa xong, theo thứ tự: **cân skill** (§4.2 — cần CLI) → **skill `ios-project`**
(§4.1, không bị chặn) → **hai skill Figma** (§4.1, chặn ở câu hỏi AppSpec MCP).

Trước khi sửa gì trong KVAppBase, chạy `./tools/verify.sh` để biết điểm xuất phát
là xanh. Sau khi sửa, chạy lại — và **mở app trên simulator xem đúng màn vừa
sửa**, đừng dừng ở test xanh. Ba bug tệ nhất trong buổi dựng (row không bấm được,
hai nguồn chân lý cho "đã đăng nhập", toast in nguyên văn chuỗi hệ thống) đều
không có test nào bắt được — chỉ bấm mới thấy.
