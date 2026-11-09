#!/usr/bin/env bash
# 卸载：注销扩展并删除 App
set -uo pipefail
pluginkit -r ~/Applications/RightKit.app/Contents/PlugIns/RightKitExt.appex 2>/dev/null || true
rm -rf ~/Applications/RightKit.app
echo "已卸载。已拷贝到剪贴板的历史不受影响。"
