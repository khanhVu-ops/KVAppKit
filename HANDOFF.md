# Bàn giao — iOS base project + bộ skill

Mở session mới thì đưa file này cho Claude Code trước. Nó chứa **trạng thái**,
**quyết định đã chốt kèm lý do**, và **những cái bẫy đã trả giá để biết** — phần
đắt nhất không phải code, mà là lý do đằng sau nó.

Cập nhật: 2026-08-14.

---

## 1. Hai repo

```
/Users/khanhvu/personal/KVAppBase   template — app chạy được   48fa09c (v1.1.0)
/Users/khanhvu/personal/KVAppKit    kit rule + skill           (xem git log)
```

Tách kit khỏi template theo đúng mô hình starter kit Android của VarMeta
(`/Users/khanhvu/VarMeta/AND-Varmeta/AND-Authenticator`): base tiến hoá độc lập
với skill, nên skill không ôm một bản copy source luôn lạc hậu.

### KVAppBase — 82 file Swift, chạy được

```
Core/           Loadable · AlertState · AppError · AppEnvironment
Domain/         Entities · Repositories(protocol) · Services(port) · UseCases
Data/           DTO · Network/{Endpoints,Interceptors} · Mapping · Local · Repositories · Testing
DI/             mọi KVDependencyKey, và nơi duy nhất
DesignSystem/   Foundation(token) · Components · Modifiers · Toast · Resources/Tokens.xcassets
Features/       Auth/ · Order/        một folder là một luồng, không phải một màn
App/            entry · Navigation · Bootstrap · Session · Resources/<19 lang>.lproj
Tests/          CoreTests · DomainTests · DataTests · FeatureTests
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
30 test. Trạng thái hiện tại (14/08): **tất cả xanh**.

Đăng nhập trong Debug: **email hợp lệ bất kỳ + mật khẩu ≥ 6 ký tự**
(`a@b.com` / `123456`). Debug dùng fixtures qua cờ `USES_STUB_BACKEND`; đặt `NO`
trong `project.yml` ngay khi có API thật.

Đã tag **`v1.1.0`** tại `48fa09c`, và `config/base-template.env` pin đúng tag đó thay
vì `main`: hai người tạo project cách nhau một tuần mà lấy hai cây source khác nhau
thì không ai tái lập được lỗi của ai. `v1.1.0` là bản làm mọi tầng gỡ ra được — nền
cho ba tier ở §4.5.

### KVAppKit — 15 skill, đủ bộ

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
| `ios-project` | `project.yml`: configuration, package, entitlement, scheme |
| `figma-intake` | Figma → token + component, cửa chặn trước khi code màn |
| `figma-spec` | spec → cổng duyệt → test spec → `TASKS.md` có link node |
| `figma-screen` | một node → một màn SwiftUI, ảnh vector vào asset |
| `init-base` | SKILL.md + `tools/init-base.sh`, ba tier |

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
| `installGlobally(swizzlingSessionConfigurations: true)` **crash iOS 26** — `+[NSURLSessionConfiguration canInitWithTask:]: unrecognized selector` | **đã sửa ở KVLoggingKit 1.1.0**, base đã pin. Dưới 1.1.0: tắt cờ và dùng `install(in: configuration)`. Lưu ý cờ đó không phải cửa duy nhất — `LogConsole` mặc định capture `.allSessions`, tức là `LogConsole.install()` trần cũng bật swizzle và cũng crash. Nguyên nhân thật ở §4.4 |
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

### 4.1 ✅ Đủ 15 skill — ba skill Figma đã viết

**Đã viết trong buổi 13/08 (6)** — `ios-l10n` (xem §4.0), và `ios-troubleshoot` (bảng §3 giờ là skill, không
còn nằm một mình trong file này), `ios-endpoint`, `api-intake`, `ios-review`,
`project-overview`. Lệnh quét trong `project-overview` đã chạy thật trên base, không
phải lệnh tưởng tượng; `ios-endpoint` lấy đúng API của `KVMockNetworkSession` và
`perform(_:_:)` trong repo. Còn lại:

**✅ Ba skill Figma — viết xong 14/08.** Câu hỏi AppSpec MCP đã có lời đáp từ người
dùng: **đi đường Figma Dev Mode MCP**, không dùng AppSpec. Chốt rồi thì đừng mở lại.

Hoá ra là **ba** skill chứ không phải hai, vì workflow có một khâu văn bản mà bản
kế hoạch cũ bỏ sót — spec phải qua cổng người duyệt trước khi có test spec:

```
figma-intake  →  figma-spec  →  [người duyệt]  →  test spec + TASKS.md  →  figma-screen
```

- `figma-intake` — token + kiểm kê component, **cửa chặn**: không code màn nào
  trước khi màu có tên. Code trước là rải hex literal vào `Features/`, và luật 6
  fail build vì đúng chuyện đó.
- `figma-spec` — `FEATURE_SPEC.md` → (duyệt) → `FEATURE_TEST_SPEC.md` + `TASKS.md`.
  Bảng task tách **cột Code và cột Test**: gộp một cột thì "xong" luôn có nghĩa là
  "code xong" và test không bao giờ được đòi. Link Figma trỏ **node**, không trỏ
  file.
- `figma-screen` — một node → một màn, ảnh **vector** (`preserves-vector-representation`)
  vào asset catalog, và mọi chuỗi đi qua 19 file `.strings`.

Hai bẫy đã viết sẵn vào skill vì chúng chắc chắn sẽ gặp:

- **Text trong design là bản tiếng Việt của một key, không phải một chuỗi.** Chép
  thẳng `Text("Áp dụng")` từ Figma thì `check-l10n.sh` đỏ — hoặc tệ hơn là lọt qua
  và thành app một ngôn ngữ.
- **Figma đo pixel và cố định pt; app đo point và phải co giãn.** Map typography
  sang *text style* gần nhất chứ đừng map sang số, nếu không Dynamic Type chết.
  Font riêng của brand cần `UIAppFonts` — base không có dòng nào — nên đó là việc
  của `ios-project`.

**Cùng ngày, plugin `figma` chính chủ được cài — và nó đổi phạm vi của cả ba.**
Plugin mang **13 skill `figma:*`**, trong đó `figma:figma-design-to-code` tự tuyên
bố là **prerequisite bắt buộc trước khi gọi `get_design_context`**, và
`figma:figma-swiftui` phủ đúng chiều Figma→SwiftUI. Bản đầu của tôi bảo gọi thẳng
tool — tức là dạy bỏ qua một prerequisite. Đã sửa.

Ranh giới chốt lại, theo đúng cách `ios-review` ủy quyền cho `review-checklist.md`:

| Của plugin | Của kit này |
|---|---|
| tên tool, cách gọi, Figma→SwiftUI | `Tokens.xcassets` + quy ước `AppColor`/`AppFont`, dark mode bắt buộc |
| ghi ngược vào Figma | luật 6/7/11 của `check-arch.sh` |
| Code Connect, motion, FigJam | 19 file `.strings` — text Figma là *key*, không phải chuỗi |
| | cổng duyệt spec → test spec → `TASKS.md` |

Chép lại cơ chế Figma vào kit là tự nhận nợ: plugin do Figma cập nhật, bản chép
lại sẽ lệch trước.

**Chưa nghiệm thu được**, và lý do đã đổi hai lần nên ghi rõ lần cuối: server
Dev Mode **sống** (`GET /mcp` trả 400, `tools/list` ra 6 tool), nhưng nó chỉ phục
vụ khi **tab đang hoạt động trong Figma desktop là file Design/FigJam** —
`The MCP server is only available if your active tab is a design or FigJam file`.
Đó là điều kiện *liên tục*, không phải bật một lần, nên triệu chứng sẽ là "đang
chạy ngon tự nhiên hỏng". Đã vào bảng của `ios-troubleshoot`.

**✅ `ios-project` — viết xong 14/08.** `project.yml`: configuration, giá trị
build-config, package, entitlement, scheme, folder tầng. Ba thứ đáng ghi vì chúng
là lỗi im lặng, không phải lỗi build:

- **Giá trị build-config là một dây ba mắt** — `settings.configs` → `$(KEY)` trong
  `Info.plist` → `AppEnvironment`. Quên mắt giữa thì `Bundle.main.object(...)` trả
  `nil` và code chạy nhánh mặc định: không lỗi build, không lỗi test, chỉ là một cờ
  không bao giờ bật ở Release.
- **Hook `PostToolUse` không cứu ở đây.** Nó chỉ generate khi có file `.swift`
  mới, không nhìn `project.yml` — nên đây là chỗ duy nhất còn phải tự chạy
  `xcodegen generate`.
- **Thêm configuration là bốn chỗ**, và chỗ thứ tư là `fastlane/Fastfile`
  (`STORE_CONFIGURATION`, `WEB_TEST_CONFIGURATION` là hằng số ở đầu file). Config
  mới không có lane trỏ vào thì chỉ là một dòng yaml.

Còn `figma-intake` và `figma-screen` là hai skill duy nhất chưa viết, cả hai đều
chặn ở câu hỏi AppSpec MCP ở trên.

### 4.2 Cân skill — đã cân lần đầu

Lỗ hổng lớn nhất của bộ skill, và 14/08 là lần đầu nó được đo thay vì được tin.

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

`tools/measure-selftest.sh` (7 phép kiểm) chứng minh cái cân phân biệt được đúng ba trường hợp đó,
bằng một `claude` giả trả lời theo kịch bản. Không có nó thì một lỗi parse trong
harness sẽ đọc y như "skill không có tác dụng" — kết luận sai đắt nhất có thể rút ra
ở đây.

## ✅ 14/08: đã cân thật lần đầu

CLI cài bằng `npm i -g @anthropic-ai/claude-code` (2.1.232), login bằng tay một
lần (`claude` → `/login` — CLI có auth **riêng**, không dùng chung phiên với bản
desktop, và không có `ANTHROPIC_API_KEY` trong môi trường).

**Kết quả — 3/10 case chứng minh được skill có tác dụng:**

| case | có skill | không skill |
|---|---|---|
| arch #3 · tách row ra view con | PASS | FAIL — `@ObservedObject var viewModel` |
| kv #2 · router cho ViewModel | PASS | FAIL — `pushView` |
| kv #5 · bật network console | PASS | FAIL — thiếu `install(in:)` |
| 7 case còn lại | PASS | PASS |

Ba chỗ skill đổi được kết quả đều là luật **không suy ra được từ đâu khác**: view
con phải `Equatable` nhận value (luật hiệu năng iOS 16), ViewModel chỉ thấy
`KVRouting`/KVRouterCore, và `install(in:)` thay vì swizzle. Đúng chỗ đáng có skill.

**7 case cả hai cột đều pass là kết quả thật, không phải lỗi** — model tự làm đúng,
prompt đó không chứng minh được gì. Việc còn lại của §4.2 là viết prompt khó hơn
cho 7 case đó, và đó là việc *thiết kế câu hỏi*, không phải sửa skill.

**⚠️ Một lượt chạy chưa đủ tin.** kv #5 lật chiều giữa hai lượt: lượt đầu cột
không-skill thiếu `install(in:)` (FAIL), lượt sau nó tự nhắc tới (PASS). Cùng
prompt, cùng repo. Nên một verdict đơn lẻ là mẫu n=1; muốn chốt thì phải chạy lặp
và đọc theo tỷ lệ.

### Chốt 14/08: đo là regression check, không phải audit định kỳ

Đừng chạy `--all` cho vui. Mỗi lượt là 2 phiên `claude` cho mỗi case, và một buổi
đã chạm `session limit` một lần. Chạy khi **vừa sửa một skill**, và chỉ chạy skill
đó:

```bash
./tools/measure-skill.sh kv-packages --in /path/to/app-repo
```

Đã cân nhắc và **không làm** ba việc sau, vì không việc nào đang chặn cái gì: viết
prompt khó hơn cho 7 case PASS/PASS, chạy lặp 3 lượt để tăng độ tin, và viết case
cho 10 skill chưa đo. Chúng đáng làm khi có thay đổi để mà đo — sửa skill, bump
package, đổi model — chứ không phải như một đợt kiểm kê.

Cũng đã cân nhắc **bỏ bớt skill cho gọn**, và không bỏ cái nào: bằng chứng chỉ phủ
2/12 skill với 5 prompt mỗi cái. Và "gọn" mua được ít hơn tưởng — thứ luôn nằm
trong context là *description*, thân skill chỉ nạp khi được gọi. Nếu có cắt thì cắt
**bên trong**: 7 case không phân biệt được đang chỉ vào những luật model tự biết
(repository pattern, `AlertState`, `Loadable`, hình dạng DI key). Nhưng cả hai cột
pass cũng có thể chỉ vì prompt quá dễ, nên đừng cắt trước khi hỏi khó hơn.

### Bốn lỗi của cái cân, tìm ra bằng chính lần cân đầu

Lượt đo đầu tiên cho **9/10 "CÓ skill mà vẫn sai"** — nghe như bộ skill vô dụng.
Cả 9 đều giả, và mỗi lỗi giờ có một phép kiểm trong `measure-selftest.sh` (7/7):

- **Model đứng lại xin quyền ghi file.** `-p` bỏ qua trust dialog, nên
  `permissions.allow` của repo không có hiệu lực và `Write` không có đường duyệt.
  Output rỗng code → cả hai cột FAIL "thiếu". Cấp quyền cũng hỏng theo hướng
  ngược lại: đo thử với `--permission-mode bypassPermissions` thì model bỏ đi làm
  việc thật, quá 6 phút chưa xong, và trả về "đã thêm vào file X" — cũng không còn
  code để chấm. Cách đúng là **chặn** tool ghi (`--disallowedTools Write Edit
  NotebookEdit`) cộng một câu dặn trả code trong chat, áp y hệt cả hai cột.
- **`reject:` quét cả văn xuôi.** Câu trả lời **đúng** của skill là câu gọi tên
  đúng thứ nó khuyên tránh — "chỉ `import Foundation`, không `Decodable`" trượt
  `reject: Decodable`. Giờ `reject:` chỉ soi trong ` ``` ` fence; `expect:` vẫn soi
  cả output vì một đường dẫn như `Domain/Entities` nằm ở văn xuôi là hợp lệ.
- **Prompt hỏi thứ repo đã có.** Case cũ hỏi về Order — thứ base đã làm sẵn và làm
  đúng — nên model đọc `Features/Order/` rồi trả lời "đã đúng rồi". Cây source dạy
  model thay cho skill, và cả hai cột cùng hưởng. Case giờ nói về **Coupon /
  Warranty**, thứ repo chưa có.
- **Phiên chết vì hạ tầng bị chấm như câu trả lời sai.** Một lượt hết quota giữa
  chừng (`You've hit your session limit`) làm cả 10 cột rỗng, và harness in ra
  *"5 case sai NGAY CẢ KHI có skill — sửa skill, đừng sửa case"*. Giờ nó `exit 2`
  với `phiên claude chết vì hạ tầng, không phải vì skill` — tách "không đo được"
  khỏi "đo được và xấu".

Ba lỗi đầu có chung một hình dạng, và đó là bài học đắt nhất của §4.2: **mọi lỗi
hạ tầng ở đây đều đọc thành "skill vô dụng"**. `measure-selftest.sh` không bắt
được cái nào vì `claude` giả của nó trả lời theo kịch bản — không văn xuôi, không
đụng permission, không hết quota. Một cái cân tự kiểm vẫn có thể sai ở đúng những
chiều mà bài tự kiểm không đi qua.

Chạy lại:

```bash
./tools/measure-skill.sh --all --in /path/to/app-repo
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

### 4.4 ✅ Xong — KVRouterKit 3.4.0 + 3.5.0, KVLoggingKit 1.1.0 (14/08)

Cả bốn việc ở đây đã giao, cộng hai việc lộ ra trong lúc làm. Base đã pin
`KVRouter from: 3.5.0` và `KVLoggingKit from: 1.1.0` trong `project.yml`.

| Việc | Kết quả |
|---|---|
| `KVNavigationTransition` → `Sendable` | 3.4.0 |
| Registry map route → transition | 3.4.0 |
| Doc `kvRoutes` chạy `configure` một lần | 3.4.0 |
| Crash swizzle iOS 26 | KVLoggingKit 1.1.0 |
| Back-swipe `.system` (3.3.0 hứa mà chưa giao) | 3.5.0 |
| Swipe custom dễ vuốt + `interactivePopEdgeWidth` | 3.5.0 |
| CI cho KVLoggingKit | xong, xanh |
| Releases liền mạch | xong |

API mới nằm trong `kv-packages/references/kvrouterkit.md` và `kvloggingkit.md`,
đã cập nhật. Base **chưa dùng** `registerTransition` hay `interactivePopEdgeWidth`
— nó vẫn để mặc định; hai thứ đó là cửa mở cho app thật, không phải nợ của base.

**Chi tiết đáng giữ, vì mỗi cái là một luật đã học:**

- **Blocker của "transition mặc định theo route" là `case zoom(AnyHashable)`.**
  `AnyHashable` không `Sendable`, giữ một cái là mất conformance. Cách gỡ đã có
  sẵn trong chính package (`AnyKVRoute`): giữ existential có ràng buộc, erase
  muộn — id sống trong box `Hashable & Sendable` và chỉ thành `AnyHashable` ở ba
  chỗ chạm registry/SwiftUI. Break hẹp: `zoom(sourceID:)` giờ đòi
  `Hashable & Sendable`.
- **Transition theo route phủ cả những đường không đi qua `push`.** Nó resolve
  qua `transitionOverride(for:)` — chỗ duy nhất mọi push/pop/pop-to đã hỏi — nên
  back swipe, deep link, restored path đều được, miễn phí. Thứ tự: call site →
  route → host.
- **`.system` back swipe chết từ 3.3.0 tới 3.4.0, và 3.3.0 ghi là đã sửa.**
  UIKit tắt `interactivePopGestureRecognizer` chỉ vì delegate *responds to*
  `navigationController(_:animationControllerFor:from:to:)` — trả gì không quan
  trọng. Proxy trả `responds(to:)` true vô điều kiện, nên trên `.system` UIKit
  tưởng delegate cầm transition. Vì thế trả `nil` **không** phải fix, và mọi nỗ
  lực "enable recognizer mạnh hơn" đều vô ích: nó vẫn đang enabled và ngồi im.
  Entry 3.3.0 được đánh dấu là sai chứ không viết lại.
- **Test xanh xuyên qua bug này.** Bảy bridge test khẳng định router vẫn cấp
  animator đều xanh trong suốt thời gian swipe chết. Và
  `UIScreenEdgePanGestureRecognizer` của package **không** driven được bằng
  synthetic touch — im lặng không bao giờ begin — nên automation không phân biệt
  nổi regression thật với điểm mù của chính nó. Đã đọc nhầm ba lần trước khi chạy
  cùng kịch bản trên build không sửa để đối chứng.
- **Swipe custom khó vuốt vì hai nguyên nhân, cái thứ hai mới là cái lạ.** Vùng
  bắt thuộc UIKit khi còn là `UIScreenEdgePan` (không API nào nới được) — giờ là
  pan thường, chặn vùng trong `gestureRecognizerShouldBegin`. Và hướng vuốt suy
  từ **velocity**: một cú kéo chậm gần như không có velocity lúc UIKit hỏi, nên
  bị từ chối thẳng — swipe chỉ ăn cú flick. Giờ hướng suy từ translation.
  `interactivePopEdgeWidth` mặc định 44pt. Đánh đổi có thật: pan thường không
  được UIKit delay touch, content sát mép leading (row cuộn ngang, slider) có
  thể tranh chấp.

**Crash swizzle — nguyên nhân thật, và nghi vấn cũ là sai.**

Ghi ở đây trước đó: nghi `class_getInstanceMethod` leo superclass nên exchange
rơi vào `NSURLSessionConfiguration`. **Sai.** `method_exchangeImplementations`
không có lỗi gì — một exchange với C function đúng kiểu thì sạch, đã kiểm.

Thủ phạm là **thứ thay thế getter**: một `@objc` method của Swift trên
`NetworkLoggingURLProtocol` trả `[AnyClass]?` bridged. Cài xong nó chạy với
`self` bound vào một *configuration*, còn thunk của một Swift `@objc` method
được quyền giả định `self` là instance của class khai nó. Mảng trả về vì thế
hỏng: protocol class không sống sót qua đường về (đọc lại ra
`NSURLSessionConfiguration` — không phải subclass của `URLProtocol`, không trả
lời `+canInitWithTask:` lẫn `+canInitWithRequest:`), và mỗi lần đọc lại chèn
thêm một entry rác nên list phình vô hạn. CFNetwork hỏi từng entry, nên nó bắn
selector đó vào một class configuration.

Bản sửa: free function `@convention(c)` trả `NSArray` ở +0 autoreleased — đúng
contract của một ObjC getter. Install dùng `class_replaceMethod` (thêm method
vào đúng class được đưa khi implementation là thừa kế, nên không bao giờ sửa
superclass toàn process); implementation để chain tới được capture **trước** khi
cài, vì sau đó có một cửa sổ mà getter chỉ trả protocol này và bỏ
`_NSURLHTTPProtocol` — tức là làm hỏng networking chứ không phải log nó.

Hai thứ investigation lòi ra mà bug report không có:

- **Swizzle chưa từng chạy đúng.** Protocol xuất hiện trong `protocolClasses`
  **0 lần**, trên iOS 18 y như trên 26. iOS 26 không làm hỏng một tính năng đang
  chạy — nó biến một cái fail im lặng thành terminate.
- **Bán kính rộng hơn cái cờ.** `LogConsole` mặc định `.allSessions`, mà scope
  đó bật swizzle — nên `LogConsole.install()` trần cũng crash. Ai đọc bug report
  và nghĩ "tôi có bật cờ đâu" là đã bỏ sót đúng nửa số ca.

10 test mới (7 drive bản thay thế qua chain giả — cài thật là process-global,
không undo được; 3 chạy `installGlobally` end-to-end). Đo hai chiều trên
simulator iOS 26.2 **và** 18.6: fail trên implementation cũ, pass trên cái mới.
Package có CHANGELOG đầu tiên, và CI (`.github/workflows/ci.yml`).

### 4.5 ✅ Xong — ba tier cho init-base (14/08)

Template mang sẵn network, đăng nhập và luồng Order mẫu. Phần lớn app không cần
cả ba, và **tầng thừa không nằm im**: nó vào `AGENTS.md`, vào review, vào đầu
người mới đọc repo. `init-base` giờ cắt template về đúng tier.

| Tier | Cờ | Còn gì |
|---|---|---|
| tool | *(không cờ)* | không network, không đăng nhập |
| api | `--with-api` | `Data/`, `APIClientFactory`, KVNetworkit |
| auth | `--with-auth` | thêm sign-in, keychain, `SessionController`, guard |

Cộng `--keep-demo` giữ nguyên luồng Order. `--with-auth` bao hàm `--with-api`.
Mặc định là **tool**: tầng thêm vào dễ hơn gỡ ra. Nhưng đoán thiếu cũng đắt, nên
skill `init-base` và `/init-base` được dặn **hỏi**, không suy từ tên app.

**Nguyên tắc: tier là tập file, không phải nội dung file.** Nhờ vậy bước cắt gần
như chỉ có `rm`. Bốn file không chịu được quy tắc đó — `RootView`, `AppRoutes`,
`MyApp`, `AppDeepLink` — nằm trong `config/overlays/{shared,auth,no-auth}/` và
chép đè sau khi xoá. Mỗi bản copy là một chỗ có thể trôi khỏi base; quá năm sáu
file thì nên tách hẳn repo skeleton chứ đừng vá tiếp bằng overlay.

Để làm được thế, KVAppBase `v1.1.0` phải gỡ ba chỗ tự nhận biết tầng khác:
`AuthGuardMiddleware` giữ `switch` liệt kê `OrderRoute` (giờ route tự khai
`RequiresAuthentication`, đích inject vào), `APIClientFactory` dựng sẵn
interceptor auth (giờ là tham số, vị trí trong chuỗi vẫn cố định), và
`clearTokensOnFirstLaunch` nằm chung file với bootstrap chung.

**Nghiệm thu: cả bốn đường đã chạy thật**, mỗi đường là một repo riêng dựng bằng
`rsync` kit → `init-base.sh` → `verify.sh`:

| | test | ghi chú |
|---|---|---|
| tool | 6 xanh | 2 luật arch skip "app không có tầng tương ứng" |
| api | 8 xanh | |
| auth | 13 xanh | |
| `--keep-demo` | 30 xanh | bằng đúng base — không mất test nào |

Và **mở app thật**, vì test xanh không chứng minh màn hình hiện ra: tier tool ra
`RootView` trống, tier auth ra `SignInView` → đăng nhập `a@b.com`/`123456` → ra
placeholder có nút Sign out. Đúng bước đó bắt được một lỗi không test nào thấy —
nút `.primary` giãn hết chiều ngang mà placeholder không có padding, nên nút chạm
sát hai mép trong khi `SignInView` ngay trước đó có lề `Spacing.l`. Hai màn này
thay nhau ở root nên lệch lề là thấy ngay lúc đăng nhập xong.

`doctor.sh` cũng phải học tier: một path trong doc thuộc tầng app này không có
thì không phải doc sai, và bắt nó đỏ trong mọi repo tool là dạy người ta bỏ qua
màu đỏ. Giờ nó đếm riêng và in vàng. `doctor-selftest.sh` vẫn 10/10.

---

## 5. Bắt đầu session mới thế nào

Câu mở đầu gợi ý:

> Đọc `/Users/khanhvu/personal/KVAppKit/HANDOFF.md`. Tiếp tục từ §4.2: cân đã
> chạy thật, 3/10 case chứng minh được skill có tác dụng, 7 case cả hai cột đều
> pass. Viết prompt khó hơn cho 7 case đó, và chạy lặp vài lượt vì một verdict
> đơn lẻ đã lật chiều một lần.

Việc chưa xong: **nghiệm thu ba skill Figma** (§4.1 — cần nối Dev Mode MCP trước),
và **7 case chưa đo được gì** (§4.2, chỉ làm khi có sửa skill).

Hai điều kiện của bài đo, kiểm trước mỗi lần chạy chứ đừng giả định:

- Repo đo phải dựng bằng `init-base --keep-demo` — case nhắc tới luồng Order, tier
  tool không có `OrderRoute` nào cả.
- Skill phải **thật sự nạp** trong repo đó, và `skillOverrides` phải **thật sự
  tắt** được. Hỏi thẳng `claude -p "liệt kê skill khả dụng"` hai lần, một lần kèm
  `--settings '{"skillOverrides":{"kv-packages":"off"}}'`. Không kiểm bước này thì
  cả hai cột là "không skill" và bảng kết quả vẫn trông bình thường.

Trước khi sửa gì trong KVAppBase, chạy `./tools/verify.sh` để biết điểm xuất phát
là xanh. Sau khi sửa, chạy lại — và **mở app trên simulator xem đúng màn vừa
sửa**, đừng dừng ở test xanh. Ba bug tệ nhất trong buổi dựng (row không bấm được,
hai nguồn chân lý cho "đã đăng nhập", toast in nguyên văn chuỗi hệ thống) đều
không có test nào bắt được — chỉ bấm mới thấy.
