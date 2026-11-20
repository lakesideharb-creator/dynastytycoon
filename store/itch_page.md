# itch.io 页面素材 · 商道玄机·大亨罗盘

## 图片清单

| 文件 | 用途 | 尺寸 |
|---|---|---|
| `cover.png` | **Cover image**（Edit game → Cover image） | 630 × 500 |
| `cover@2x.png` | 高清版封面（itch 也接受，显示更清楚，二选一上传） | 1260 × 1000 |
| `screenshots/01_title.png` | 截图 1：标题画面 | 1920 × 1080 |
| `screenshots/03_campaign.png` | 截图 2：经营主界面（月度结账、现金走势、三才因子、高管） | 1920 × 1080 |
| `screenshots/02_opening_choice.png` | 截图 3：开局决断 | 1920 × 1080 |
| `screenshots/04_decision.png` | 截图 4：董事会紧急议题 | 1920 × 1080 |
| `screenshots/05_office.png` | 截图 5：企业总部风水工位 | 1920 × 1080 |
| `screenshots/06_ending.png` | 截图 6：通关结算 | 1920 × 1080 |

截图按上表顺序上传（itch 的截图在页面右侧按上传顺序排列，第一张最显眼，所以把经营主界面放在第二张）。

重新生成：截图 `"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --path godot --resolution 1920x1080 res://tests/capture_shots.tscn`；封面 `python3 tools/make_cover.py`。

---

## 填写字段

| 字段 | 中文 | English |
|---|---|---|
| Title | 商道玄机·大亨罗盘 | Dynasty Tycoon |
| Short description / tagline | 以奇门遁甲经营商海：看天时、调地利、和人心，带公司穿过十二个月的商战。 | Run a company by the ancient Chinese compass — read the timing, fix the feng shui, and keep your executives from tearing each other apart. |
| Genre | Strategy | Strategy |
| Tags（最多 10 个） | `management` `business` `strategy` `chinese` `simulation` `tycoon` `turn-based` `narrative` `singleplayer` `ink` | 同左 |
| Languages | Chinese | Chinese |
| Inputs | Mouse, Keyboard | Mouse, Keyboard |
| Average session | About a half-hour | About a half-hour |

> 标题建议填 `商道玄机·大亨罗盘 Dynasty Tycoon`，中英文玩家都能搜到。

---

## 中文简介（贴到 Description）

**商道玄机·大亨罗盘**

天时、地利、人和——你是董事长，手里只有一面罗盘。

这是一款以奇门遁甲为框架的经营策略游戏。每个月，你要读懂大运与节气带来的「天时」，调整门店选址与总部风水的「地利」，安排高管所落的八门、化解他们之间的冲突，求得「人和」。三者相乘，就是公司这个月的营收。

**三个案例，三种算法**

- **案例一【空间算法】新中式烘焙的跨省选址之争**：30 家门店首次跨省扩张，进军郑州合肥，还是成都西安？十二个月内把账面现金做到 1.35 亿。
- **案例二【时间算法】AI 教育初创公司的融资择时生死战**：现金只够撑 4.7 个月，对赌融资签不签、何时签？熬过资本寒冬。
- **案例三【人物算法】豪华创业四人组的权力归位**：四位联创势成水火，内耗高达 45%。重新排兵布阵，让团队归位、产品上线。

**玩法**

- **开局决断与董事会议题**：关键月份会出现紧急议题，每个选项都有后果，有的立刻见效，有的要几个月后才显现。
- **每月盈亏解读**：结账后逐项说明天时、地利、人和各贡献了多少，并预告下个月的天时走向，不靠猜。
- **企业总部风水工位**：在等距视角的办公室里摆放屏风、招财树、鱼缸，破解穿堂煞、背门而坐等格局，风水评分直接影响全部门店营收。
- **高管与八门**：每位高管落在不同的门（景门、生门、伤门……），相生则互补，相克则内耗。
- **随机事件**：螣蛇暗流、白虎猖狂、贵人辅弼……天有不测风云。

**说明**

- 网页版，请用电脑上的 Chrome 或 Edge 打开，首次加载约 40 MB。进入后先点一下画面以启用声音。
- 存档保存在浏览器中；可随时按 Esc 打开菜单存档、读档、调整音量。
- 快捷键：空格 / 回车 推进本月，F 打开风水工位，Esc 菜单。
- 目前为试玩版（v0.5），仅支持简体中文。玩完后可在结局画面点「导出试玩记录」，欢迎把记录和意见发给我。

*游戏中的奇门遁甲与风水内容为游戏化的设定，仅供娱乐，不构成任何投资或经营建议。*

---

## English Description

**Dynasty Tycoon**

Heaven's timing, earthly advantage, human harmony — you are the chairman, and all you have is a compass.

Dynasty Tycoon is a business strategy game built on *Qimen Dunjia*, the ancient Chinese art of divination. Each month you read the **timing** of the grand cycle and the solar terms, shape your **terrain** through store locations and the feng shui of your headquarters, and seat your executives in the Eight Gates to keep the **people** in harmony. Multiply the three together and you get this month's revenue.

**Three cases, three disciplines**

- **Case 1 · Space** — A new-Chinese-style bakery chain makes its first leap across provinces. Low-rent Zhengzhou and Hefei, or the cultural hubs of Chengdu and Xi'an? Reach ¥135 million in cash within twelve months.
- **Case 2 · Time** — An AI-education startup with 4.7 months of runway left. Do you sign the harsh term sheet now, or bet on a better valuation later? Survive the capital winter.
- **Case 3 · People** — Four star co-founders at each other's throats, with 45% internal friction. Reassign the team, end the infighting and ship the product.

**Features**

- **Opening calls and board crises** — Key months bring urgent decisions. Some pay off immediately; others come back to haunt you months later.
- **Every month explained** — After each settlement, the game breaks down exactly how much timing, terrain and people contributed, and forecasts next month's timing. No guesswork.
- **Feng shui headquarters** — Arrange screens, money trees and aquariums in an isometric office to break harmful layouts. Your feng shui score affects revenue at every store.
- **Executives and the Eight Gates** — Each executive sits in a gate. Compatible gates complement each other; clashing gates breed friction.
- **Random events** — Hidden serpents, raging white tigers and helpful patrons: fortune is never fixed.

**Notes**

- **Language: Simplified Chinese only** for now.
- Browser build. Use Chrome or Edge on a desktop computer; the first load is about 40 MB. Click the screen once to enable sound.
- Progress is saved in your browser. Press Esc at any time to save, load or adjust volume.
- Shortcuts: Space / Enter advances the month, F opens the feng shui office, Esc opens the menu.
- This is a playtest build (v0.5). After a run, click "导出试玩记录" (Export playtest log) on the ending screen. Feedback is very welcome.

*The Qimen Dunjia and feng shui systems in this game are gameplay mechanics for entertainment only and are not investment or business advice.*
