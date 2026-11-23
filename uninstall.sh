#!/bin/zsh
# Binsen · 卸载（保留 iCloud 里的 Binsen 文件夹和已有便笺）
ID=io.github.qinov5.binsen
launchctl bootout "gui/$(id -u)/$ID" 2>/dev/null
pkill -x Binsen 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$ID.plist"
rm -rf "$HOME/Applications/Binsen.app"
defaults delete "$ID" 2>/dev/null
print "已卸载。iCloud 云盘 › 快捷指令 › Binsen 文件夹保留未动。"
