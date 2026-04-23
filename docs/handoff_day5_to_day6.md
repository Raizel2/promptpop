# promptpop 開發進度交接 — Day 6 開始

你好 Claude,我是 Raizel。這份檔接續 Day 5(v0.1.0 已發佈)。

---

## ⚠️ 重要:我的學習定位(別忘了)

我不是要成為工程師,我是**想成為 vibe coding 的人**。

- **不要教太細**,但可以教「未來能重用的通用知識」— 我兩種模式會在任務裡明說:
  - **SKIP**:直接動手,回報「改了什麼 / 輪到我做什麼」
  - **LEARN**:每步說你在做什麼、為什麼,但依舊不擠牙膏
- 概念一兩句、bug 直接給解、深挖的部分我會主動問
- 繁體中文、叫我 **Raizel**
- 環境固定:**macOS 14.5 + Xcode 15.4**,不要叫我升級
- 值得錄的瞬間主動提醒(YouTube 素材)

---

## 目前狀態(Day 5 結束)

### 存檔點
- **Commit:`c8b962b`** — `Day 5: 交付 v0.1.0 — 修貼上、換 icon、補產品細節、登入啟動、README+LICENSE`
- **Tag:`v0.1.0`**(已推)
- **Release:** https://github.com/Raizel2/promptpop/releases/tag/v0.1.0
- **Repo(公開):** https://github.com/Raizel2/promptpop

### Git 歷史
| Day | Commit | 內容 |
|-----|--------|------|
| Day 2 | `30659f4` | 熱鍵 ⌘⇧P + 浮動視窗 MVP |
| Day 3 | `69ef0df` | 搜尋 UI + 資料載入 + 鍵盤選擇 |
| Day 4 | `9e0b33b` | Enter 自動貼上(剪貼簿 + ⌘V) |
| Day 5 | `c8b962b` | v0.1.0 交付(8 件) |

---

## Day 5 實際完成的事(跟計畫的差異標 ⚠)

1. **修貼上功能** — 兩個 bug 串在一起(詳見下方踩坑)
2. **換 App Icon** — ⚠ 計畫是「用戶準備好 AppIcon.appiconset」,實際 Downloads 只找到 6 張鬆散 PNG,我手動組 appiconset + 用 `sips` 從 32 下採樣出缺的 16x16
3. **產品細節補完** — 滑鼠所在螢幕真・置中、每次叫出重載 JSON、壞 JSON 保留舊版+紅字 banner、首啟寫預設 9 句、剪貼簿 0.6s 還原
4. **登入自動啟動** — `SMAppService.mainApp.register()`,寫死一律開啟
5. **寫 README** — 英文主 + 繁中附錄
6. **加 LICENSE + examples** — ⚠ 原計畫含 `prompts.raizel.json`(使用者個人版),顧問建議不放,最後只留 `prompts.default.json`
7. **推 GitHub** — 從零設 SSH key、裝 gh CLI、建 `Raizel2/promptpop` 公開 repo
8. **發 Release v0.1.0** — 用 `ditto` 打包 app.zip(不是 `zip`,理由見踩坑 4)

---

## 踩過的坑 + 解法

### 1. 貼上失敗 #1 — SwiftUI delegate cast 是 nil

**症狀:** 按 Enter 後視窗沒關、剪貼簿沒被覆寫。

**原因:** ContentView 原本這樣呼叫:
```swift
(NSApp.delegate as? AppDelegate)?.pasteAndDismiss(text: textToPaste)
```
SwiftUI 的 `@NSApplicationDelegateAdaptor` 包裝後,`NSApp.delegate` 回來的不是裸 `AppDelegate`,downcast 返回 nil,整條鏈靜默失敗。

**解法:** AppDelegate 加 `static weak var shared: AppDelegate?`,在 `init()` 裡自設:
```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    override init() {
        super.init()
        AppDelegate.shared = self
    }
}
// ContentView 裡:
AppDelegate.shared?.pasteAndDismiss(text: textToPaste)
```

### 2. 貼上失敗 #2 — ⌘V 被 promptpop 自己吃掉

**症狀:** 修好 #1 後,TextEdit 測試可貼,但加了「產品細節」那批改後又失敗。

**原因:** 我把 `setActivationPolicy(.accessory)` 延後到 1.0s,結果 ⌘V 在 0.25s 送出時 promptpop 還是 `.regular` 前景 App,keystroke 被自己接走。

**解法:** 關視窗後**立刻**降 `.accessory`,再 activate previousApp,最後 delay 送 ⌘V:
```swift
func pasteAndDismiss(text: String) {
    popupWindow?.close()
    NSApp.setActivationPolicy(.accessory)       // 立刻讓出前景
    previousApp?.activate()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        Paster.paste(text)
    }
}
```

### 3. Accessibility 授權每次 rebuild 失效

**症狀:** 剛授權完,rebuild 一次貼上又失敗,`AXIsProcessTrustedWithOptions` 返回 false。

**原因:** ad-hoc 簽名(`codesign --sign -`)每次 build 的 cdhash 都變,TCC 把新 binary 視為新 app 自動 revoke。

**現行解(治標):** 集中 code 改動,**一次 rebuild** 讓 Raizel 只授權一次。啟動時必在 log 輸出 `Accessibility trusted: <bool>` 方便確認。

**根治(Day 6+ 可做):** 建 self-signed code signing cert(Keychain Access → Create a Certificate → Code Signing)並在 Xcode `CODE_SIGN_IDENTITY` 指定該 cert name。

### 4. 打包 .app 要用 `ditto` 不是 `zip`

`zip` 會破壞 macOS extended attributes 和 code signature。正規作法:
```bash
ditto -c -k --sequesterRsrc --keepParent /Applications/promptpop.app promptpop-v0.1.0.app.zip
```

### 5. `print` 看不到,要用 `NSLog`

`log show` CLI 只看得到 os_log/NSLog 輸出。Day 5 為 debug 全面改 NSLog。**Day 6 可以考慮清掉或用 `#if DEBUG` 包起來**。

---

## 當前程式碼架構(檔案職責)

```
promptpop/
├── promptpopApp.swift      AppDelegate:啟動邏輯、popup 生命週期、登入啟動、AX 權限請求、AppDelegate.shared
├── HotKeyManager.swift     Carbon RegisterEventHotKey 註冊 ⌘⇧P
├── PopupWindow.swift       無邊框浮動視窗、滑鼠所在螢幕真・置中、失焦自關
├── ContentView.swift       SwiftUI UI:搜尋框、分類 list、紅字 banner、NSEvent 鍵盤監聽(↑↓ Enter)
├── Prompt.swift            Prompt struct + PromptCategory enum
├── PromptStore.swift       @Observable;load / 首啟 fallback / 壞 JSON 保留舊版 + loadError
├── Paster.swift            NSPasteboard 備份 → 寫入 → ⌘V → 0.6s 還原
├── VisualEffectView.swift  毛玻璃 NSVisualEffectView 包裝
├── Assets.xcassets/AppIcon.appiconset/  10 張 icon + Contents.json
└── promptpop.entitlements  空 plist(Sandbox 已關)
```

**幾個非顯而易見的決定:**
- `PromptStore.defaultPrompts` 是唯一的 9 句來源 — 首啟寫檔時用它,`examples/prompts.default.json` 是它的 mirror
- `ContentView.handleSelect` 不自己關視窗,全交給 `AppDelegate.shared.pasteAndDismiss`
- 熱鍵走 Carbon 不走 SwiftUI `.keyboardShortcut` — 因為要全域、獨佔
- JSON 重載在 `AppDelegate.showPopup()` 裡呼叫 `promptStore.load()`,不是檔案 watcher

---

## Day 6 建議清單(排序:簡單 → 難)

1. **截 README 的 screenshot / 錄 GIF** — Demo 作品必備,README 現在純文字沒 hero image
2. **動態視窗高度** — 目前寫死 360,9 句以上會被截斷要滾動;算 `min(idealHeight, maxHeight)` 就好
3. **清 NSLog debug 輸出** — 或 `#if DEBUG` 包起來,release 建不出現
4. **menu bar 圖示** — 點一下能「打開 prompts.json」,讓使用者找到檔案位置
5. **JSON 檔案 watcher** — 目前每次 popup 開才重讀,加 DispatchSource file monitor 就能即時
6. **中英/拼音搜尋對照** — `table` 找到「用表格整理」。需要拼音表或 keyword 欄位
7. **self-signed cert** 或 **Apple Developer ID 簽章** — 解 AX 授權每次失效 + Gatekeeper 右鍵打開兩個體驗痛點。Apple Developer ID($99/年)同時能跑 notarization,給人用的工具建議走這條

---

## 下一個 Claude「不要再問的事」

- **環境**:macOS 14.5 + Xcode 15.4,不要叫升級
- **Sandbox**:已關(Day 3),別開回來
- **熱鍵**:寫死 ⌘⇧P,不做自訂 UI
- **登入啟動**:寫死一律開啟,不做開關
- **JSON 路徑**:`~/Library/Application Support/promptpop/prompts.json`
- **貼上機制**:剪貼簿 + ⌘V + 0.6s 還原,不走 Unicode typeString
- **貼上時序**:關視窗 → **立刻**降 `.accessory` → activate prev → 0.15s 後送 ⌘V。不要把降 policy 延後,會被自己吃掉
- **delegate 存取**:用 `AppDelegate.shared`,不用 `NSApp.delegate as? AppDelegate`
- **開頭/結尾**:prefix 貼完加 `\n`,suffix 原樣
- **搜尋**:literal 字面比對,不做中英對照(寫在 Day 6 清單,不是 bug)
- **debug log**:NSLog 才看得到,print 在 `log show` 裡不會出現
- **ad-hoc 簽名陷阱**:每次 rebuild AX 授權失效,rebuild 前先集中所有 code 改動
- **打包 .app**:用 `ditto -c -k --sequesterRsrc --keepParent`,不要用 `zip`

---

## 開工

請你:
1. 先用一兩句確認你看懂了交接、特別是**學習定位(SKIP / LEARN 兩模式)**那段
2. 告訴我你想先做 Day 6 清單哪一項、為什麼(或等我指定)
3. **不要立刻丟 code**,先對齊方向

開工。
