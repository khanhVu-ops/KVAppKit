# KVAppKit — iOS starter kit

Rule + skill cho Codex và Claude Code, cộng một script kéo [KVAppBase](https://github.com/khanhVu-ops/KVAppBase)
theo version xác định để tạo app mới.

Kit và template tách nhau có lý: base tiến hoá độc lập với skill, nên skill không
phải ôm một bản copy source luôn lạc hậu.

## Dùng cho project mới

```bash
git init my-app && cd my-app
cp -R /path/to/KVAppKit/. .
```

Rồi trong Claude Code:

```text
/init-base "My App" com.company.myapp
```

Hoặc chạy thẳng:

```bash
./tools/init-base.sh --name "My App" --bundle-id com.company.myapp --verify
```

Script sẽ: kéo KVAppBase theo ref đã pin → copy source vào → đổi tên module,
bundle id, tên app → giữ nguyên `AGENTS.md`, `CLAUDE.md` và toàn bộ skill của kit
→ báo rõ source/ref đã dùng.

Chỉ dùng cho repo mới. Nó từ chối chạy nếu đã có `App/`, `Packages/`,
`project.yml` hay `.xcodeproj`, để không ghi đè mất code.

## Chọn version KVAppBase

`config/base-template.env`. Khi KVAppBase có release ổn định, pin theo tag thay vì
`main`:

```bash
./tools/init-base.sh --name "My App" --bundle-id com.company.myapp --ref v1.0.0
```

## Skill

| Skill | Khi nào |
|---|---|
| `ios-architecture` | trước khi tạo/sửa bất kỳ file Swift nào |
| `kv-packages` | khi chạm bất kỳ symbol `KV*` |
| `ios-feature` | một feature trọn vẹn, 12 bước |
| `ios-endpoint` | một endpoint: DTO → cachePolicy → map lỗi → test |
| `api-intake` | có spec OpenAPI/Postman, cần `API_INVENTORY.md` |
| `ios-verify` | build + test + luật + chạy thật trên simulator |
| `ios-troubleshoot` | một lệnh vừa fail, hoặc app cư xử lạ |
| `ios-review` | review diff theo luật của repo |
| `project-overview` | quét repo, sinh `PROJECT_OVERVIEW.md` |
| `init-base` | repo mới |

Cộng subagent `swiftui-screen` cho việc scaffold một màn (model rẻ, tool giới hạn).

## Cấu trúc

```
AGENTS.md              rule chung, canonical — Codex đọc trực tiếp
CLAUDE.md              @AGENTS.md + trỏ skill
.claude/skills/        skill (nguồn duy nhất)
.agents/skills         → symlink tới .claude/skills
.claude/commands/      slash command
.claude/agents/        subagent profile
tools/init-base.sh     script khởi tạo
tools/doctor.sh        kiểm rule/skill còn nói đúng sự thật
config/                repository + version KVAppBase
```

## Kiểm sức khoẻ của kit

```bash
./tools/doctor.sh          # 7 phép kiểm; --against DIR nếu repo app nằm chỗ khác
./tools/doctor-selftest.sh # chứng minh 7 phép kiểm đó còn bắt được vi phạm
```

## Đo skill có thật sự tác dụng

```bash
./tools/measure-selftest.sh                    # cái cân còn đúng không
./tools/measure-skill.sh --all --in ../my-app  # cân thật, trên repo đã init-base
```

Cùng một prompt chạy hai lần — một lần có skill, một lần `skillOverrides: off` — rồi
assert bằng regex. Cột đáng đọc là **"không skill"**: nó fail thì skill mới có việc.
Cả hai cột pass nghĩa là prompt đó không chứng minh được gì. Xem `tools/measure/`.

Mỗi phép kiểm ứng với một lỗi đã xảy ra thật: symlink rơi khỏi git, bản copy script
lạc hậu trong skill, `name:` lệch tên folder, version trong doc lệch `project.yml`,
doc trỏ vào file đã xoá, `init-base` chặn hook, doc quảng cáo skill không tồn tại.
Chạy nó sau mỗi lần sửa skill — drift ở đây dạy sai cả người lẫn agent trước khi họ
kịp mở source ra xem.

`.agents/skills` là **symlink**, không phải bản copy — sửa một chỗ, cả hai runtime
thấy. Nếu nó thành directory thật thì symlink đã bị hỏng; restore nó thay vì
maintain hai bản.

Khi đổi rule chung, sửa `AGENTS.md`. Đừng nhồi chi tiết kiến trúc vào `CLAUDE.md`:
nó vào context mọi lượt, kể cả lượt chỉ hỏi `git log`.
