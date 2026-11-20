#!/bin/bash
# 导出网页版，并（可选）用 butler 推送到 itch.io 的 html5 频道。
# 思路沿用 Ninefold Gate 的 tools/publish_itch.sh。
#
# 第一次推送之前：
#   1. 在 itch.io 上新建游戏页面（可设为 Draft / Restricted，只给试玩者看），
#      类型选 HTML，把下面的 ITCH_GAME 设为「用户名/游戏网址名」
#   2. 确认 butler 已登录：butler login
#
# 用法：
#   tools/publish_web.sh                 只导出到 godot/export/web/（不上传）
#   ITCH_GAME=用户名/dynasty-tycoon tools/publish_web.sh --push   导出并推送
#   tools/publish_web.sh --push --dry-run                          只打印推送命令
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
OUT="godot/export/web"
PUSH=0; DRY=0
for a in "$@"; do
  case "$a" in
    --push) PUSH=1 ;;
    --dry-run) DRY=1 ;;
    *) echo "未知参数：$a"; exit 2 ;;
  esac
done

python3 tools/sync_godot_data.py
rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
"$GODOT" --headless --path godot --export-release "Web" "export/web/index.html"
echo "已导出：$OUT（$(du -sh "$OUT" | cut -f1)）"
echo "本地试玩：python3 -m http.server 8765 --directory $OUT  然后打开 http://localhost:8765"

if [ "$PUSH" = 1 ]; then
  : "${ITCH_GAME:?请先设置 ITCH_GAME=用户名/游戏网址名}"
  VERSION=$(grep -m1 '^config/version=' godot/project.godot | cut -d'"' -f2)
  CMD=(butler push "$OUT" "$ITCH_GAME:html5" --userversion "$VERSION")
  if [ "$DRY" = 1 ]; then echo "将执行：${CMD[*]}"; else "${CMD[@]}"; fi
fi
