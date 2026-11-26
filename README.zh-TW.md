# Binsen（便箋）

[简体中文](README.md) | [English](README.en.md) | **繁體中文** | [日本語](README.ja.md) | [Español](README.es.md)

在 iPhone 上隨手記下一句，幾秒後，Mac 桌面上原生的「便條紙」(Stickies) 裡就會安靜地多出一張。

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

**Binsen** 取自日語「便箋（びんせん）」，意為信箋、便條。外出時閃現的念頭、臨時待辦或零碎摘錄，不必再傳訊息給自己，也不用打開笨重的筆記軟體——回到電腦前，它已經貼在桌面上等你了。

```text
iPhone 捷徑「Binsen」
  └─ 存成 .txt ──▶ iCloud 雲碟/捷徑/Binsen
                        └─ Mac 背景常駐程式偵測到新檔案
                              ├─ 靜默在「便條紙」中新增一張並寫入內容
                              └─ 原檔案歸檔至 Binsen/已处理
```

## 為什麼做它

* **純正原生**：直接寫入 macOS 內建的「便條紙」App，不是第三方仿製的浮動視窗。
* **零打擾寫入**：全程在背景操作，不搶走目前視窗的焦點，在 Mac 上打字不會被突然打斷；若「便條紙」尚未執行，會自動沿用它啟動時自帶的預設空白便條，絕不多留一張廢紙。
* **乾淨無痕**：完全不讀寫、不汙染系統剪貼板。
* **零外部依賴**：不需要伺服器、不需要註冊帳號、不開放任何網路連接埠，純靠 iCloud 雲碟同步。
* **極簡透明**：核心邏輯只有單一 Swift 檔案，沒有任何第三方依賴，程式碼一目了然。

## 環境需求

* macOS 13 或更新版本
* Xcode 或命令列工具（可透過 `xcode-select --install` 安裝）
* Mac 與 iPhone 登入同一個 Apple 帳號，並開啟 **iCloud 雲碟**

## 快速開始

### 1. Mac 端安裝

```bash
git clone https://github.com/Qinov5/Binsen.git
cd Binsen
zsh install.sh
```

安裝腳本會自動完成：**編譯建置 → 安裝至 `~/Applications/Binsen.app` → 建立 iCloud 收件匣資料夾 → 註冊登入時自動啟動 → 投遞一則自我檢測訊息**。

看到桌面便條紙跳出 **「Binsen 已接通 ✅」**，就代表安裝成功。

> **日常更新**：在專案資料夾下執行 `git pull && zsh install.sh` 即可覆蓋更新。
>
> **關於簽署**：腳本會優先使用鑰匙圈中的 `Apple Development` 憑證簽署（首次執行時若系統詢問是否允許 `codesign` 取用鑰匙圈，選擇「永遠允許」即可），這樣之後更新不會遺失系統授權；若沒有開發者憑證，則改用臨時簽署，每次更新後都需要重新授權一次。
>
> **介面語言**：安裝腳本與執行記錄的訊息目前為簡體中文。

### 2. 授予控制權限（強烈建議）

首次觸發自我檢測時，系統會請求控制權限。建議只允許 Binsen 控制 **「便條紙」** 這一個 App——授權後，Binsen 才能透過選單靜默新增便條、不搶焦點，並避免冷啟動時多出空白便條。

| 系統版本 | 授權方式 |
| :--- | :--- |
| **macOS 27.3 及更新版本** | 在彈出視窗中點選 **Choose Apps**，只加入「便條紙」，並將右側權限改為 **At Any Time**（若選 *Ask First*，每次都會跳出確認）。之後也可以在 `系統設定 → 隱私權與安全性 → System & App Protection Override` 中調整。 |
| **更早版本** | 前往 `系統設定 → 隱私權與安全性 → 輔助使用`（macOS 27 早期版本名為 *Device Control and Data Access*），開啟 **Binsen**。 |

*註：不授權也能使用。此時程式會自動改用系統服務（Make Sticky）建立便條，但新增時會把「便條紙」帶到最前面，且便條紙未執行時可能會多出一張空白便條。*

### 3. iPhone 端設定捷徑

在 iPhone 上點選下方連結，加入現成的捷徑：

👉 **[點選加入捷徑「Binsen」](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)**

它只做兩件極簡的事：叫出文字輸入框 → 將內容存入 `iCloud 雲碟 › 捷徑 › Binsen`。加入後點一下，寫句話試試看。

💡 **小技巧**：如果你的 iPhone 有「動作按鈕」(Action Button)，可前往 `設定 → 動作按鈕 → 捷徑` 選擇 **Binsen**，之後按一下側邊按鈕就能隨手貼便條。也可以把它加入鎖定畫面小工具，或用「背面輕點」觸發。

<details>
<summary>不想點連結？手動建立</summary>

1. 打開「捷徑」App，點選右上角 **＋**，命名為 `Binsen`。
2. 加入動作 **要求輸入**，輸入類型選「文字」。
3. 加入動作 **儲存檔案**：
   * 儲存內容選擇「提供的輸入」
   * **關閉**「詢問儲存位置」
   * 子路徑填寫 `/Binsen/`

*（在 Mac 的捷徑 App 中建立也可以，會自動透過 iCloud 同步到 iPhone。）*
</details>

## 進階設定

可透過 `defaults` 指令依需求調整預設行為：

```bash
# 新增便條後讓「便條紙」留在最前面（預設會把焦點還給原本的視窗）
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# 自訂監聽的收件匣資料夾
defaults write io.github.qinov5.binsen InboxPath "~/某個資料夾"

# 修改設定後重新啟動背景服務
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## 常見問題排解

| 現象 | 排解方式 |
| :--- | :--- |
| 遲遲沒有出現新便條 | 查看執行記錄：`tail -20 ~/Library/Logs/Binsen.log` |
| iPhone 已儲存，但 Mac 收件匣是空的 | 通常是 iCloud 同步延遲或 Mac 處於睡眠狀態；可前往 `Finder › iCloud 雲碟 › 捷徑 › Binsen` 查看檔案是否已到達 |
| 記錄中出現 `没有控制「便笺」的权限`（沒有控制便條紙的權限） | 參考上方「授予控制權限」一節開啟授權 |
| 新增便條後焦點沒有回到原本的視窗 | 先確認已完成權限設定；若仍會發生，歡迎把記錄中以 `焦点没能还给…` 開頭的那一行貼到 Issues |
| 檢查背景服務是否在執行 | 執行 `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## 解除安裝

```bash
zsh uninstall.sh
```

解除安裝腳本只會移除背景程式與自動啟動設定，**iCloud 收件匣資料夾及桌面上已有的所有便條都會完整保留**。

## 實作原理與目錄結構

* **輕量常駐**：`Binsen.app` 是沒有 Dock 圖示的背景 App，由 `LaunchAgent` 在登入時啟動，每 2 秒輪詢一次收件匣資料夾。
* **按需下載雲端檔案**：剛從 iPhone 同步過來的 `.txt` 在 Mac 上可能只是尚未下載的佔位檔。程式透過 `setiopolicy_np` 開啟按需下載，遇到尚未就緒的檔案還會主動呼叫 `brctl download` 觸發下載。
* **無感寫入**：讀取文字後，透過輔助使用介面直接觸發便條紙選單列的「新增便條」（`⌘N`）並填入內容，全程不啟用便條紙視窗；若便條紙未在執行，則在背景靜默啟動並直接寫入它的初始空白便條；若未獲授權，則平順降級至 `NSPerformService("Make Sticky", …)` 並盡量歸還焦點。

```text
Sources/main.swift   核心監聽與寫入邏輯（單一檔案、無依賴）
Info.plist           背景無介面 App 設定
install.sh           編譯、簽署、安裝、自動啟動與端對端自我檢測（可重複執行以更新）
uninstall.sh         移除 App 與自動啟動服務
```

## 授權條款

[MIT](LICENSE)
