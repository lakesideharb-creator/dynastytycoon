# 12 · 上架 Steam

从注册 Steamworks 到正式发售的完整流程。素材和构建脚本都已准备好，大部分时间花在 Valve 的审核与等待期上。

> Steam 的规则和后台界面会更新。尺寸、费用与等待期以 Steamworks 后台和官方文档（partner.steamgames.com/doc）当时的说明为准；本文写于 2026 年 11 月。

---

## 〇、时间线一览

| 阶段 | 需要多久 | 说明 |
|---|---|---|
| 注册 Steamworks、付 Steam Direct 费用、填税务与银行信息 | 1～7 天 | 身份与银行验证需要等 |
| 付费后到可以发售 | **至少 30 天** | Valve 对新开发者的固定等待期，可以同时做下面的事 |
| 商店页审核 | 3～5 个工作日 | 审核通过后才能上线「即将推出」 |
| 「即将推出」页面公开 | **至少 2 周** | 发售前必须先公开，用来积累愿望单 |
| 构建（游戏本体）审核 | 3～5 个工作日 | 发售前至少提前一周提交 |

**结论：** 从今天开始，最快约 5～6 周可以发售。建议先上「即将推出」页积累愿望单，并考虑参加 Steam 新品节（Next Fest）。

---

## 一、注册 Steamworks（只需一次）

1. 打开 partner.steamgames.com，用你的 Steam 账号登录，选择注册成为合作伙伴。
2. 填写法律主体（个人或公司）、联系地址。
3. **支付 Steam Direct 费用**：每款游戏 100 美元。游戏总收入达到 1000 美元后，这笔钱会返还到收入中。
4. **税务信息**：在线填写税务问卷（个人一般填 W-8BEN）。中国大陆与美国有税收协定，正确填写可以降低预扣税率。
5. **银行信息**：填写可以接收美元电汇的银行账户（SWIFT 代码），以便收款。
6. 完成后，在后台点「创建新应用」，得到你的 **AppID**（一个 6～7 位数字）。

---

## 二、准备素材（已完成）

所有素材都在 `store/steam/`。重新生成：`python3 tools/make_steam_assets.py`。

### 商店图形素材（Steamworks → 编辑商店页面 → 图形素材）

| 文件 | Steamworks 字段 | 尺寸 | 用在哪里 |
|---|---|---|---|
| `header_capsule_920x430.png` | 页眉胶囊图 Header Capsule | 920 × 430 | 商店页顶部、搜索结果、推荐位 |
| `small_capsule_462x174.png` | 小胶囊图 Small Capsule | 462 × 174 | 列表、搜索结果（字最小，只放中文标志） |
| `main_capsule_1232x706.png` | 主胶囊图 Main Capsule | 1232 × 706 | 首页大推荐位 |
| `vertical_capsule_748x896.png` | 竖版胶囊图 Vertical Capsule | 748 × 896 | 季节特卖等活动页 |
| `page_background_1438x810.png` | 页面背景 Page Background（可选） | 1438 × 810 | 商店页背景，已做低对比、去饱和处理 |

### 游戏库素材（Steamworks → 编辑商店页面 → 游戏库素材）

| 文件 | 字段 | 尺寸 |
|---|---|---|
| `library_capsule_600x900.png` | 游戏库胶囊图 | 600 × 900 |
| `library_header_920x430.png` | 游戏库页眉 | 920 × 430 |
| `library_hero_3840x1240.png` | 游戏库主视觉 Hero（不能有文字） | 3840 × 1240 |
| `library_logo_1280x720.png` | 游戏库标志（透明底） | 1280 宽 |

上传 Logo 后，后台会让你在 Hero 图上拖动标志的位置：建议放在左下角，避开右侧的罗盘。

### 图标（Steamworks → 应用管理 → 通用设置 → 图标）

| 文件 | 字段 |
|---|---|
| `community_icon_184x184.jpg` | 社区图标 |
| `client_icon.ico` | 客户端图标 |
| `client_icon_32x32.tga` | 客户端 TGA 图标 |

游戏本身的图标也已设置好（`godot/icon.png`、`icon.ico`、`icon.icns`），三个平台的可执行文件都会显示罗盘图标。

### 截图与预告片（编辑商店页面 → 截图 / 预告片）

| 文件 | 说明 |
|---|---|
| `screenshots/01_campaign.png` ～ `06_title.png` | 6 张 1920 × 1080，Steam 至少要 5 张；按编号顺序上传，第一张最常被看到 |
| `trailer_steam_1080p.mp4` | 54 秒预告片，高码率版本（约 8 Mbps），Steam 会自己重新压缩 |

截图上传后，**把每张截图都勾选「适合所有年龄」**，否则需要年龄验证才能看。

### 素材规则（审核会检查）

- 胶囊图上**只能有游戏名称/标志**，不能放评测引用、奖项、「免费」「打折」之类的文字。现有素材都符合。
- Hero 图不能有文字和标志，现有素材符合。
- 截图必须是游戏实际画面，不能是概念图。现有截图都是游戏实机画面。

---

## 三、填写商店页文案

全部文案在 `store/steam/store_text.md`，可以直接复制：

- 中英文游戏名称、简短描述（≤ 300 字符）
- 「关于这款游戏」中英文版（Steam BBCode 格式）
- 支持语言：**只勾简体中文**（界面）
- 类型、用户标签、系统需求、内容调查问卷

填好后点「提交审核」。审核通过后，在「发行」页设置「即将推出」的公开时间，以及预计发售日期（可以先写「2027 年第一季度」这种模糊日期）。

---

## 四、构建桌面版

Steam 不能用网页版，需要 Windows / macOS / Linux 的桌面版。导出预设已加到 `godot/export_presets.cfg`：

```bash
tools/build_steam.sh
```

脚本会同步数据，并导出到 `godot/export/steam/`：

| 平台 | 文件 | 大小 |
|---|---|---|
| Windows | `windows/DynastyTycoon.exe`（单文件，资源已嵌入） | 约 135 MB |
| macOS | `macos/DynastyTycoon.app`（通用二进制，Intel + Apple Silicon） | 约 195 MB |
| Linux / Steam Deck | `linux/DynastyTycoon.x86_64` | 约 100 MB |

已在本机验证 macOS 版能正常启动。Windows 版和 Linux 版请在对应系统上各试玩一次（Steam Deck 用 Linux 版）。

**关于 macOS 签名**：目前是临时（ad-hoc）签名。通过 Steam 下载的游戏一般不会被 macOS 拦截，但正式发售时更稳妥的做法是：加入 Apple Developer Program（99 美元/年），用 Developer ID 证书签名并公证（notarize）。也可以先只上架 Windows 版，以后再加 macOS。

---

## 五、上传构建（SteamPipe）

### 1. 在 Steamworks 设置 Depot（只需一次）

1. Steamworks → 你的应用 → **SteamPipe → Depot**。后台默认会建一个 AppID + 1 的 Depot，再添加两个，共三个。
2. 每个 Depot 设置操作系统：
   - 第一个：Windows（64 位）
   - 第二个：macOS
   - 第三个：Linux + SteamOS
3. 记下三个 Depot ID，**发布**这些改动（「发布」标签页 → 准备发布 → 发布到 Steam）。

### 2. 设置启动选项（应用管理 → 安装 → 通用安装）

| 操作系统 | 可执行文件 |
|---|---|
| Windows | `DynastyTycoon.exe` |
| macOS | `DynastyTycoon.app` |
| Linux | `DynastyTycoon.x86_64` |

改完同样要「发布」。

### 3. 填写 AppID 与 Depot ID

编辑 `tools/steam/` 下的四个文件：

- `app_build.vdf`：把 `1000000` 换成你的 AppID，`1000001～1000003` 换成三个 Depot ID
- `depot_windows.vdf`、`depot_macos.vdf`、`depot_linux.vdf`：各自的 `DepotID`

### 4. 安装 steamcmd 并上传

```bash
brew install --cask steamcmd
```

```bash
STEAM_USER=你的Steam账号 tools/build_steam.sh --upload
```

第一次登录会要求输入密码和 Steam 令牌验证码（在 steamcmd 里由你自己输入）。建议在 Steamworks 里为构建单独建一个只有「编辑应用元数据 / 发布构建」权限的账号。

### 5. 让构建生效

Steamworks → SteamPipe → **构建版本**：找到刚上传的构建，在「为分支设置构建」里选 `default`，点「预览更改」→「立即设为正式」。

然后在 Steam 客户端里，用 Steamworks 自动发放给你的开发者密钥激活游戏，下载并试玩三个平台。

---

## 六、提交发售审核

1. Steamworks → 你的应用 → **发行**（Release）页：检查清单全部变绿（商店页、构建、价格、内容调查、税务等）。
2. 设置**价格**：后台会根据你填的美元价格，给出各地区的建议价。参考：同类小体量经营游戏一般在 18～38 元人民币。目前内容是三个案例，约 2～3 小时，建议定低价，或先免费做 Playtest（见下一节）。
3. 点「提交构建审核」。审核通过后，发行页会出现「发售」按钮，到了日期你自己按下即可。

---

## 七、建议：先做 Steam Playtest

Playtest 是 Steam 的免费试玩功能，挂在主游戏商店页上，玩家点「申请参与」即可下载，不影响主游戏的正式发售：

- 在 Steamworks 后台为主游戏创建 Playtest（会生成一个独立的 AppID），上传同样的构建
- 可以控制每批放进来的人数
- 适合现在这个阶段：收集试玩记录和反馈，同时主商店页在积累愿望单

试玩反馈仍可以用游戏里的「导出试玩记录」收集，见 [08_Playtest_Guide.md](08_Playtest_Guide.md)。

---

## 八、发售前检查清单

- [ ] Steamworks 税务、银行信息已通过验证
- [ ] 付费后已满 30 天
- [ ] 商店页审核通过，「即将推出」已公开满 2 周
- [ ] 全部图形素材、游戏库素材、图标已上传
- [ ] 6 张截图已上传，并勾选「适合所有年龄」
- [ ] 预告片已上传，并设为第一个展示
- [ ] 支持语言只勾了简体中文
- [ ] 三个平台在真机上各试玩通关一次（Windows、macOS、Linux 或 Steam Deck）
- [ ] 构建已设为 `default` 分支，并通过构建审核
- [ ] 价格与发售日期已设定
- [ ] `godot/project.godot` 里的版本号与上传说明（app_build.vdf 的 `Desc`）一致

---

## 九、更新游戏

1. 修改 `godot/project.godot` 的 `config/version`，以及 `tools/steam/app_build.vdf` 里的 `Desc`。
2. 运行 `STEAM_USER=你的Steam账号 tools/build_steam.sh --upload`。
3. 在 SteamPipe → 构建版本，把新构建设为 `default` 正式版。
4. 可以在 Steamworks 的「活动与公告」里发一条更新公告（需要 800 × 450 的封面图和 1920 × 622 的页眉图，可以用 `tools/make_steam_assets.py` 照着现有尺寸再加）。

---

## 十、以后可以加的 Steam 功能

目前游戏没有接入 Steamworks SDK，不影响上架。以后如果想要成就、云存档、Steam 排行榜：

- **Steam 云存档**：最简单。在 Steamworks → 应用管理 → Steam 云 里设置「自动云存储（Auto-Cloud）」，把存档路径 `user://saves/` 对应的系统目录加进去即可，不需要改代码。Windows 是 `%APPDATA%/DynastyTycoon/saves`，macOS 是 `~/Library/Application Support/DynastyTycoon/saves`，Linux 是 `~/.local/share/DynastyTycoon/saves`。
- **成就**：需要接入 GodotSteam 插件，例如「通关案例一」「风水评分 100」「零内耗」等。
