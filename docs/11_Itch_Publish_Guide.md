# 11 · 发布网页试玩版到 itch.io

把 Godot 网页版发布到 itch.io，生成一个试玩链接。第一次约需 15 分钟，之后每次更新只要一条命令。

本机已经具备的条件：

- Godot 4.7.2 与网页导出模板已安装
- butler（itch 官方上传工具，v15.32.0）已安装并登录过（Ninefold Gate 发布时登录的是 `lakesideharb` 账号）
- 一键脚本 `tools/publish_web.sh`：导出网页版，加 `--push` 时用 butler 上传

---

## 一、在 itch.io 新建游戏页面（只需一次）

1. 登录 itch.io，右上角头像菜单 → **Upload new project**。
2. 按下表填写，其余保持默认：

| 字段 | 填写 |
|---|---|
| Title | 商道玄机·大亨罗盘 |
| Project URL | `dynasty-tycoon`（页面地址会是 `https://lakesideharb.itch.io/dynasty-tycoon`） |
| Short description | 以奇门遁甲（天时·地利·人和）经营商海的商业策略游戏 |
| Classification | Games |
| **Kind of project** | **HTML**（必须选这个，网页版才能在页面里直接玩） |
| Release status | Prototype |
| Pricing | No payments |
| Uploads | 先不上传，留空（由 butler 上传） |

3. 页面下方 **Embed options**：

| 选项 | 设置 |
|---|---|
| Embed in page | 选 **Manually set size**，宽 **1600**、高 **900**（游戏按 16:9 设计，也可以用 1280 × 720） |
| Mobile friendly | 不勾（目前只针对电脑浏览器） |
| Automatically start on page load | 不勾（让试玩者点击后再加载，约 40 MB） |
| Fullscreen button | 勾选 |
| SharedArrayBuffer support | **不勾**（我们的导出是单线程版本，不需要） |

4. 页面最下方 **Visibility & access** 先选 **Draft**，点 **Save & view page**。页面存好后才能用 butler 上传。

> 如果你的 itch 用户名不是 `lakesideharb`，后面命令里的用户名一律换成你自己的。页面地址 `https://用户名.itch.io/游戏网址名` 对应命令里的 `用户名/游戏网址名`。

---

## 二、上传

在仓库根目录 `dynasty_tycoon/` 下运行。

**1. 先确认 butler 登录的是哪个账号**

```bash
butler login
```

如果提示已经登录，确认是你建页面的那个账号。不是的话，先运行 `butler logout` 再 `butler login`，在弹出的浏览器里授权。

**2. 试运行（只打印命令，不上传）**

```bash
ITCH_GAME=lakesideharb/dynasty-tycoon tools/publish_web.sh --push --dry-run
```

最后一行应该是：`将执行：butler push godot/export/web lakesideharb/dynasty-tycoon:html5 --userversion 0.5.0`

**3. 正式导出并上传**

```bash
ITCH_GAME=lakesideharb/dynasty-tycoon tools/publish_web.sh --push
```

脚本会依次：同步数据 → 导出网页版到 `godot/export/web/` → 用 butler 推送到 `html5` 频道。第一次上传约 70 MB，之后只传有变化的部分。

---

## 三、上传后在 itch 页面上设置（只需一次）

1. 打开游戏页面 → **Edit game**。
2. 在 **Uploads** 区域会看到 butler 推上来的文件（频道名 `html5`），勾选 **This file will be played in the browser**。
3. 点 **Save**，再打开页面，确认游戏出现在页面里，点击能开始加载。

---

## 四、给试玩者看

在 **Edit game → Visibility & access** 中选择：

| 选项 | 适合 |
|---|---|
| **Restricted** + 设置密码 | 小范围试玩（推荐）：只有知道密码的人能打开 |
| Draft | 只有你自己能看，用来先自测 |
| Public | 公开发布，会出现在 itch 的搜索与浏览中 |

把页面链接（和密码）发给试玩者，并附上这几句：

- 请用**电脑上的 Chrome 或 Edge**，打开声音；首次加载约 40 MB。
- 进入游戏后先点击一下画面，浏览器才会允许播放声音。
- 玩完后在结局画面或「设置」里点 **导出试玩记录**，把下载的 `dynasty_tycoon_playtest_日期.jsonl` 发给我。
- 存档保存在浏览器里：同一浏览器再打开同一个链接，标题画面会有「继续游戏」。

试玩流程与访谈问题见 [08_Playtest_Guide.md](08_Playtest_Guide.md)。

---

## 五、发布更新

1. 改 `godot/project.godot` 里的版本号，例如 `config/version="0.5.1"`（itch 页面会显示这个版本，方便区分试玩者玩的是哪一版）。
2. 重新运行：

```bash
ITCH_GAME=lakesideharb/dynasty-tycoon tools/publish_web.sh --push
```

butler 只上传差异，通常几十秒完成。itch 页面会自动换成新版本，试玩者刷新页面即可。

---

## 六、常见问题

| 现象 | 处理 |
|---|---|
| butler 报 `404` 或 `invalid game` | `ITCH_GAME` 写错，或页面还没保存；对照页面地址检查「用户名/游戏网址名」 |
| butler 报未登录或无权限 | 运行 `butler login`，确认登录的是建页面的账号 |
| 页面上只有下载按钮，没有在网页里玩 | 第三步漏了：在 Uploads 里勾选 **This file will be played in the browser**；并确认 Kind of project 是 HTML |
| 页面里一片黑或一直在加载 | 用浏览器开发者工具（F12）看 Console 报错；确认上传的是完整的 `godot/export/web/` 目录（包括 index.pck 和 index.wasm） |
| 提示需要 SharedArrayBuffer / 跨源隔离 | 导出预设里 `variant/thread_support` 应为 `false`（目前就是），重新导出上传；itch 的 SharedArrayBuffer 选项保持不勾 |
| 没有声音 | 先在游戏画面里点击一下（浏览器要求用户操作后才能播放声音）；检查「设置」里的音量；用 Chrome / Edge 再试 |
| 画面太小或有黑边 | 在 Embed options 里调整宽高，或让试玩者点全屏按钮；游戏会自动适配 16:9 以外的比例 |
| 想先在本机确认网页版 | `tools/publish_web.sh`（不加 `--push`）导出后运行 `python3 -m http.server 8765 --directory godot/export/web`，打开 http://localhost:8765 |
