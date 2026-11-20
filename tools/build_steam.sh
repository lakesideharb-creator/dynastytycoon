#!/usr/bin/env bash
# 导出 Steam 用的桌面版（Windows / macOS / Linux）到 godot/export/steam/<平台>/，可选用 steamcmd 上传
# 用法：
#   tools/build_steam.sh                     只导出三个平台
#   tools/build_steam.sh --upload            导出后用 steamcmd 按 tools/steam/app_build.vdf 上传（需先填好 AppID / DepotID）
# 环境变量：GODOT_BIN（Godot 可执行文件）、STEAM_USER（Steamworks 构建账号）
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-$HOME/Downloads/Godot.app/Contents/MacOS/Godot}"
OUT="godot/export/steam"

python3 tools/sync_godot_data.py
rm -rf "$OUT" && mkdir -p "$OUT"/{windows,macos,linux}
"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
for preset in Windows macOS Linux; do
  case $preset in
    Windows) path="export/steam/windows/DynastyTycoon.exe" ;;
    macOS)   path="export/steam/macos/DynastyTycoon.zip" ;;
    Linux)   path="export/steam/linux/DynastyTycoon.x86_64" ;;
  esac
  echo "== 导出 $preset"
  "$GODOT" --headless --path godot --export-release "$preset" "$path" 2>&1 | grep -E "ERROR|WARNING|savepack|DONE" || true
done
# macOS：Steam 需要解压后的 .app
(cd "$OUT/macos" && unzip -q -o DynastyTycoon.zip && rm DynastyTycoon.zip && mv ./*.app DynastyTycoon.app)
du -sh "$OUT"/*

if [[ "${1:-}" == "--upload" ]]; then
  : "${STEAM_USER:?请设置 STEAM_USER=你的 Steamworks 构建账号}"
  steamcmd +login "$STEAM_USER" +run_app_build "$(pwd)/tools/steam/app_build.vdf" +quit
fi
