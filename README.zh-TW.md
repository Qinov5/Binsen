# Binsen（便箋）

[简体中文](README.md) | [English](README.en.md) | **繁體中文** | [日本語](README.ja.md) | [Español](README.es.md)

在 iPhone 上隨手記下一句，幾秒後，Mac 桌面上原生的「便條紙」(Stickies) 裡就會安靜地多出一張。

https://github.com/user-attachments/assets/12b98983-d6f9-4837-83bc-dde8d83b0335

**Binsen** 取自日語「便箋（びんせん）」，意為信箋、便條。外出時閃現的念頭、臨時待辦或零碎摘錄，不必再傳訊息給自己，也不用打開笨重的筆記軟體——回到電腦前，它已經貼在桌面上等你了。

```text
iPhone 捷徑「Binsen」
  ├─ 建議：加入提醒事項列表「Binsen」 ──▶ iCloud，幾秒同步
  └─ 舊版：存成 .txt ──▶ iCloud 雲碟/捷徑/Binsen
                        └─ Mac 背景常駐的 Binsen 收到新內容
                              ├─ 靜默在「便條紙」中新增一張並寫入內容
                              └─ 提醒事項標記為已完成；檔案歸檔至 Binsen/已处理（30 天後自動刪除）
```

## 為什麼做它

* **純正原生**：直接寫入 macOS 內建的「便條紙」App，不是第三方仿製的浮動視窗。
* **零打擾寫入**：全程在背景操作，不搶走目前視窗的焦點，在 Mac 上打字不會被突然打斷；新便條從螢幕右上角依序往下排，不會蓋住已有的便條；若「便條紙」尚未執行，會自動沿用它啟動時自帶的預設空白便條，絕不多留一張廢紙。
* **乾淨無痕**：完全不讀寫、不汙染系統剪貼板；貼出後的原文 30 天後自動從 iCloud 刪除。
* **零外部依賴**：不需要伺服器、不需要註冊帳號、不開放任何網路連接埠，只用你自己的 iCloud（提醒事項或 iCloud 雲碟）同步。
* **極簡透明**：核心邏輯只有單一 Swift 檔案，沒有任何第三方依賴，程式碼一目了然。

## 環境需求

* macOS 13 或更新版本（Apple 晶片和 Intel 皆可）
* Mac 與 iPhone 登入同一個 Apple 帳號，並在 iCloud 中開啟 **提醒事項**（使用舊版檔案方式時還需開啟 **iCloud 雲碟**）

## 快速開始

### 1. Mac 端安裝

打開「終端機」，貼上下面這一行並按 Return：

```bash
curl -fsSL https://raw.githubusercontent.com/Qinov5/Binsen/main/install.sh | zsh
```

不用安裝 Xcode，也不用編譯。安裝腳本會自動完成：**下載打包好的 Binsen → 安裝至 `~/Applications/Binsen.app` → 建立 iCloud 收件匣資料夾 → 註冊登入時自動啟動 → 分別自我檢測 iCloud 雲碟通道與提醒事項通道**。

看到桌面便條紙跳出 **「Binsen 已接通 ✅」** 和 **「Binsen 提醒事项通道已接通 ✅」**，就代表安裝成功。

> **日常更新**：再執行一次上面那行指令即可覆蓋更新。
>
> **關於簽署**：下載的安裝包是臨時簽署，每次更新後可能需要重新授權一次（腳本自我檢測時會提示並打開設定頁面）。
>
> **從原始碼編譯**（需要 Xcode 或命令列工具，`xcode-select --install`）：
> ```bash
> git clone https://github.com/Qinov5/Binsen.git && cd Binsen && zsh install.sh
> ```
> 之後在專案資料夾執行 `git pull && zsh install.sh` 更新。腳本會優先使用鑰匙圈中的 `Apple Development` 憑證簽署（首次執行若詢問是否允許 `codesign` 取用鑰匙圈，選「永遠允許」），這樣更新後不會遺失系統授權。
>
> **介面語言**：安裝腳本與執行記錄的訊息目前為簡體中文。

### 2. 授予控制權限（強烈建議）

首次觸發自我檢測時，系統會請求控制權限。建議只允許 Binsen 控制 **「便條紙」** 這一個 App——授權後，Binsen 才能透過選單靜默新增便條、不搶焦點，並避免冷啟動時多出空白便條。

| 系統版本 | 授權方式 |
| :--- | :--- |
| **macOS 27.3 及更新版本** | 在彈出視窗中點選 **Choose Apps**，只加入「便條紙」，並將右側權限改為 **At Any Time**（若選 *Ask First*，每次都會跳出確認）。之後也可以在 `系統設定 → 隱私權與安全性 → System & App Protection Override` 中調整。 |
| **更早版本** | 前往 `系統設定 → 隱私權與安全性 → 輔助使用`（macOS 27 早期版本名為 *Device Control and Data Access*），開啟 **Binsen**。 |

*註：不授權也能使用。此時程式會自動改用系統服務（Make Sticky）建立便條，但新增時會把「便條紙」帶到最前面，且便條紙未執行時可能會多出一張空白便條。*

**提醒事項權限**：安裝過程中會跳出視窗請求取用「提醒事項」，請點「允許」。Binsen 只讀寫「Binsen」這一個列表（沒有的話會自動在 iCloud 建立），貼成便條後會把那則提醒事項標記為已完成。如果漏點了，到 `系統設定 → 隱私權與安全性 → 提醒事項` 開啟 Binsen，再重新執行一次安裝指令。

### 3. iPhone 端設定捷徑

建議使用「提醒事項」版：提醒事項會立即同步，實測從 iPhone 送出到 Mac 貼上約 10 秒。

👉 **[點選加入捷徑「Binsen」](https://www.icloud.com/shortcuts/54ba2387d2b54ceebe1437aef3b34d47)**

它只做兩件極簡的事：叫出文字輸入框 → 把內容加入提醒事項列表「Binsen」。加入後打開看一下：如果列表欄位不是「Binsen」，重新選一次即可（先在 Mac 上裝好 Binsen，這個列表會自動出現）。

💡 **小技巧**：如果你的 iPhone 有「動作按鈕」(Action Button)，可前往 `設定 → 動作按鈕 → 捷徑` 選擇 **Binsen**，之後按一下側邊按鈕就能隨手貼便條。也可以把它加入鎖定畫面小工具，或用「背面輕點」觸發。

<details>
<summary>不想點連結？三步手動建立</summary>

1. 打開「捷徑」App，點選右上角 **＋**，命名為 `Binsen`。
2. 加入動作 **要求輸入**，輸入類型選「文字」。
3. 加入動作 **加入新的提醒事項**：提醒事項欄位選「提供的輸入」（通常會自動填好），列表選 **Binsen**（若暫時沒出現，打開一次「提醒事項」App 等它同步）。

*（在 Mac 的捷徑 App 中建立也可以，會自動透過 iCloud 同步到 iPhone。）*
</details>

<details>
<summary>舊版：存成檔案到 iCloud 雲碟（可能延遲很久）</summary>

👉 [點選加入舊版捷徑](https://www.icloud.com/shortcuts/22b6bb3e26b046278a8ee42ee9dd0edd)

也可以手動建立：**要求輸入**（文字）→ **儲存檔案**（儲存內容選「提供的輸入」，關閉「詢問儲存位置」，子路徑填 `/Binsen/`）。

> 注意：iPhone 往往不會馬上把捷徑存下的檔案上傳到 iCloud，常常要等你打開「檔案」App 才開始上傳，所以可能延遲幾分鐘到幾小時。Mac 端仍會監聽這個資料夾，舊捷徑可以繼續用。
</details>

## 進階設定

可透過 `defaults` 指令依需求調整預設行為：

```bash
# 新增便條後讓「便條紙」留在最前面（預設會把焦點還給原本的視窗）
defaults write io.github.qinov5.binsen RestoreFocus -bool false

# 自訂監聽的收件匣資料夾
defaults write io.github.qinov5.binsen InboxPath "~/某個資料夾"

# 修改提醒事項通道監聽的列表（預設 Binsen，沒有會自動建立）
defaults write io.github.qinov5.binsen RemindersList "某個列表"

# 關閉提醒事項通道，只用 iCloud 雲碟檔案
defaults write io.github.qinov5.binsen UseReminders -bool false

# 新便條的位置：預設從螢幕右上角往下排、不蓋住已有便條；在便條紙預設位置依序往右下錯開用 cascade，不移動用 off
defaults write io.github.qinov5.binsen NotePlacement cascade

# 已貼出的原文保留幾天：到期自動刪除「已处理」裡的檔案和提醒事項裡的已完成項目（預設 30；0 = 一直保留）
# RemindersList 改成你自己的列表時，只有設定了這一項才會清理那個列表
defaults write io.github.qinov5.binsen KeepDays -int 7

# 修改設定後重新啟動背景服務
launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen
```

## 常見問題排解

| 現象 | 排解方式 |
| :--- | :--- |
| 遲遲沒有出現新便條 | 查看執行記錄：`tail -20 ~/Library/Logs/Binsen.log` |
| 便條隔了很久才出現 | 看記錄裡以 `收到：` 開頭的那一行：會寫明 iCloud 花了多久才送到這台 Mac、期間 Mac 睡了多久。從 `收到` 到 `已贴到便笺` 通常只要 1–2 秒，慢幾乎都慢在 iCloud 這一段 |
| Mac 闔上或睡眠期間送出的便條沒出現 | Mac 睡眠時無法新增便條；喚醒後 iCloud 會補齊同步，通常幾十秒內就會自動貼上 |
| 使用舊版（儲存檔案）捷徑時，要打開「檔案」App 才會到 | iPhone 不會馬上上傳捷徑存下的檔案。換成上面的「提醒事項」版捷徑即可 |
| Mac 醒著、iPhone 也已送出，仍要等好幾分鐘 | 多半是 iCloud 推播被代理或 VPN 擋住了，Mac 收不到更新通知。使用 Shadowrocket、Clash 等設定了系統代理時，把 `*.push.apple.com` 和 `17.0.0.0/8` 加進「略過代理」清單 |
| 記錄中出現 `没有控制「便笺」的权限`（沒有控制便條紙的權限） | 參考上方「授予控制權限」一節開啟授權 |
| 記錄中出現 `提醒事项：没有访问权限`（沒有取用提醒事項的權限） | 到 `系統設定 → 隱私權與安全性 → 提醒事項` 開啟 Binsen，再執行 `launchctl kickstart -k gui/$(id -u)/io.github.qinov5.binsen` |
| 新增便條後焦點沒有回到原本的視窗 | 先確認已完成權限設定；若仍會發生，歡迎把記錄中以 `焦点没能还给…` 開頭的那一行貼到 Issues |
| 檢查背景服務是否在執行 | 執行 `launchctl print gui/$(id -u)/io.github.qinov5.binsen \| grep state` |

## 解除安裝

```bash
curl -fsSL https://raw.githubusercontent.com/Qinov5/Binsen/main/uninstall.sh | zsh
```

（在專案資料夾裡也可以直接執行 `zsh uninstall.sh`。）

解除安裝腳本只會移除背景程式與自動啟動設定，**iCloud 收件匣資料夾、提醒事項裡的「Binsen」列表及桌面上已有的所有便條都會完整保留**。

## 實作原理與目錄結構

* **輕量常駐**：`Binsen.app` 是沒有 Dock 圖示的背景 App，由 `LaunchAgent` 在登入時啟動；透過 FSEvents 監聽收件匣，檔案一到就立刻處理，另有每 2 秒一次的備援檢查。新增失敗會依 2、4、8……秒自動重試，直到貼上為止。
* **提醒事項通道**：透過 EventKit 監聽「Binsen」列表的變化（另外每分鐘主動重新整理一次），讀到新的提醒事項後貼成便條，再標記為已完成。提醒事項走 CloudKit，iPhone 會立即上傳；捷徑存下的檔案則要等 iCloud 雲碟擇機上傳。
* **按需下載雲端檔案**：剛從 iPhone 同步過來的 `.txt` 在 Mac 上可能只是尚未下載的佔位檔。程式透過 `setiopolicy_np` 開啟按需下載，遇到尚未就緒的檔案還會主動呼叫 `brctl download` 觸發下載。讀取在背景執行緒進行，某個檔案下載較慢，也不會耽誤其他便條。
* **無感寫入**：讀取文字後，透過輔助使用介面直接觸發便條紙選單列的「新增便條」（`⌘N`）並填入內容，全程不啟用便條紙視窗；若便條紙未在執行，則在背景靜默啟動並直接寫入它的初始空白便條；若未獲授權，則平順降級至 `NSPerformService("Make Sticky", …)` 並盡量歸還焦點。
* **擺放與清理**：新便條寫好後，透過輔助使用介面移到螢幕右上角的空位（一欄排滿就往左再排一欄，都滿了就在右上角依序錯開）。貼出後的原文保留 30 天，之後自動從「已处理」資料夾和提醒事項中刪除。
* **打包發佈**：發佈 Release 時，GitHub Actions 會編譯 Apple 晶片與 Intel 通用版本，打包成 Binsen.zip 附在 Release 上，一行安裝指令下載的就是它。

```text
Sources/main.swift           核心監聽與寫入邏輯（單一檔案、無依賴）
Info.plist                   背景無介面 App 設定
Binsen.entitlements          以 Developer ID 簽署、公證時的權限宣告
Icon/                        App 圖示（AppIcon.svg 為原始檔；依系統版本選用 .icns）
install.sh                   下載或編譯、安裝、自動啟動與端對端自我檢測（可重複執行以更新）
uninstall.sh                 移除 App 與自動啟動服務
scripts/package.sh           打包發佈用的通用安裝包
.github/workflows/build.yml  每次推送都編譯一次；發佈 Release 時自動附上安裝包
```

## 授權條款

[MIT](LICENSE)
