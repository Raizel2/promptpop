# promptpop 開發進度交接 — Day 7 收工(下次再開或日後接手用)

你好 Claude,我是 Raizel。這份檔接續 Day 6,涵蓋 Day 7 的工作和 v0.1.2 發布。**v0.1.2 已對外發布,我覺得這個版本可以收工了**,這份 handoff 主要是給未來可能的「再開」做準備。

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

## 目前狀態(v0.1.2 已公開發布)

### 存檔點
- **最新 Commit:`9290f28`** — `docs: 擴寫安裝流程 — 解釋 Gatekeeper / AX / 登入項目的意義`
- **Code 主 commit:`b4561ad`** — `Day 7: popup 點擊+IME+視覺順序修正、編輯器拖曳排序`
- **Tag:`v0.1.2`**(已推)
- **Release:** https://github.com/Raizel2/promptpop/releases/tag/v0.1.2
- **Repo(公開):** https://github.com/Raizel2/promptpop
- **/Applications/promptpop.app:** 已升級到 v0.1.2

### Git 歷史(完整)

| Day | Commit | 內容 |
|-----|--------|------|
| Day 2 | `30659f4` | 熱鍵 ⌘⇧P + 浮動視窗 MVP |
| Day 3 | `69ef0df` | 搜尋 UI + 資料載入 + 鍵盤選擇 |
| Day 4 | `9e0b33b` | Enter 自動貼上(剪貼簿 + ⌘V) |
| Day 5 | `c8b962b` | v0.1.0 交付(8 件) |
| Day 6 | `0ccc4ca` | 編輯視窗 + ⌘⇧E + menu bar + popup 滾動 |
| Day 6 | `f7db861` | README 反映新功能 |
| Day 6 | `6f0bb76` | gitignore *.app.zip |
| Day 7 | `b4561ad` | popup 點擊+IME+視覺順序修正、編輯器拖曳排序 |
| Day 7 | `9290f28` | README install 擴寫 |

---

## Day 7 實際完成的事(9 件)

1. **Popup 點擊修通** — `.onTapGesture` 在 borderless 視窗下不可靠,改用 SwiftUI `Button { } label: { promptRow }` + `.buttonStyle(.plain)`
2. **鍵盤 ↑↓ 順著畫面走** — 加 `orderedPrompts`(`PromptCategory.allCases.flatMap { filteredPrompts.filter { $0.category == ... } }`),selectedIndex 走它,不再在 prefix/suffix 段間亂跳
3. **IME 友善** — keyMonitor 開頭加 `if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.hasMarkedText() { return event }`,組字中所有鍵放行給輸入法
4. **編輯器拖曳排序** — `.onMove` on 內層 ForEach + `PromptStore.reorder(category:from:to:)`,類別內自由調整順序
5. **listStyle `.sidebar` → `.inset`** — sidebar 不支援拖曳排序
6. **新增 prompt 插在最前**(`insert(at: 0)`)— 之前是 `append`,使用者要按 ↓ 到底才看得到
7. **修 race condition** — `showPopup` 先 `flushPendingSave()` 再 `load()`,避免編輯 500ms debounce 期間被 popup 重讀覆蓋
8. **發 v0.1.2 release** — Release zip ~215KB,GitHub 已上架,/Applications 已換新
9. **README 安裝步驟擴寫** — 從 4 步精簡擴寫到 6 步詳細版,解釋 Gatekeeper / AX / 登入項目分別在做什麼

---

## 踩過的坑 + 解法(本次新增)

### 1. Carbon `InstallEventHandler` 多 handler 陷阱

裝兩個 HotKeyManager(⌘⇧P + ⌘⇧E)時,**只有最後裝的 handler 會被呼叫**,`return OSStatus(eventNotHandledErr)` 也不會把事件傳給 sibling handler。Apple 文件寫得像可以多個並存,實測就是不行。

**解:** 整個 architecture 改成「一個共用 dispatch handler」:

```swift
final class HotKeyManager {
    private static var managers: [UInt32: HotKeyManager] = [:]
    private static var sharedHandlerInstalled = false

    init(keyCode: UInt32, id: UInt32, label: String) {
        ...
        HotKeyManager.installSharedHandlerIfNeeded()
        HotKeyManager.managers[id] = self
        registerHotKey()
    }

    private static func installSharedHandlerIfNeeded() {
        guard !sharedHandlerInstalled else { return }
        sharedHandlerInstalled = true
        InstallEventHandler(...) { _, event, _ in
            // 從 event 拿 hkID.id,查 dict 找對應 manager,呼叫 onTrigger
            if let manager = managers[hkID.id] {
                DispatchQueue.main.async { manager.onTrigger?() }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }
    }
}
```

### 2. SwiftUI `.onTapGesture` 在 borderless NSWindow 不可靠

NSHostingView 包在 borderless `PopupWindow` 裡時,`.onTapGesture` 有時不觸發,並且觸發後會搞壞 NSEvent local monitor。

**解:** 用 SwiftUI `Button` + `.buttonStyle(.plain)` 取代 `.onTapGesture`。視覺一樣、行為更可靠。

### 3. selectedIndex 對應的順序要跟畫面一致

popup 用 `ForEach(PromptCategory.allCases) { ForEach(promptsInCategory) { ... } }` 顯示,所以畫面順序是「全部 prefix、再全部 suffix」。但 selectedIndex 原本走 `filteredPrompts`(原始陣列順序),當 prefix/suffix 在陣列裡交錯時,按 ↓ 會在兩段間亂跳。

**解:** 加 computed `orderedPrompts`,明確算出畫面順序;selectedIndex 走它。

### 4. IME 組字中按鍵不能截

注音/拼音組字中按 Enter 是「commit IME 候選字」,我們不能截。

**解:** keyMonitor 開頭判斷 `firstResponder` 是不是 NSTextView 且有 marked text,有就放行所有事件。順便這也修了 Day 5 README 列的「組字中方向鍵被吃」已知限制。

### 5. SwiftUI binding 寫入 struct 欄位需要 `var`

`$store.prompts[idx].title` 這種 binding 需要欄位可寫。原本 Prompt 所有欄位都 `let`,Day 6 加編輯視窗時踩到。

**解:** id 維持 let(沒有改它的需求);title/category/content 改 var。

### 6. SwiftUI List `.sidebar` 不能拖曳

`.listStyle(.sidebar)` + `.onMove` → 不會出現拖曳行為。

**解:** 改 `.listStyle(.inset)`。視覺差一點(列分隔比較明顯),但能拖。

### 7. Editor → Popup race condition(資料丟失!)

編輯打字 → `scheduleSave()` 500ms debounce 計時中 → 使用者按 ⌘⇧P 叫 popup → `showPopup` 呼叫 `promptStore.load()` 從硬碟重讀 → **覆蓋掉記憶體裡未存檔的編輯** → 500ms 後 saveNow 把覆蓋後的版本寫進硬碟 → **新編輯永久丟失**。

**解:** `showPopup` 改成先 `flushPendingSave()`(把 pending save 立刻同步寫下去)再 `load()`。

### 8. TCC 又一個雷:toggle 顯示 ON 但 trusted=false

之前在 ad-hoc 簽名 + cdhash 變動的情境下,輔助使用列表的開關**看起來**還亮著,但啟動 log 印 `Accessibility trusted: false`、`CGEvent.post` 靜默失敗。這個情況**只切 toggle OFF→ON 救不回來**。

**解:** 列表 entry **− 刪掉** → 從 Finder 把 `.app` 拖回去重加。記憶 `feedback_adhoc_signing_tcc.md` 已更新這個 detail。

---

## 當前程式碼架構(檔案職責 + 重點)

```
promptpop/
├── promptpopApp.swift     AppDelegate:啟動 / hotkeys 接線(popupHotKey + editorHotKey)/
│                          popup 生命週期 / editor 視窗 / menu bar status item / 登入項目註冊 /
│                          AppDelegate.shared / applicationWillTerminate flush 存檔
├── HotKeyManager.swift    共用 Carbon dispatcher:static managers dict + 一個共用 handler;
│                          每個 instance 註冊自己的 RegisterEventHotKey、用 id 在 dict 占位
├── PopupWindow.swift      borderless 浮動視窗 520x460、失焦自關、Esc 關
├── ContentView.swift      Popup UI:搜尋 + orderedPrompts + Button-based 點擊 +
│                          ScrollViewReader 自動捲 + IME-friendly key monitor
├── EditorView.swift       編輯視窗:HSplitView(List + .onMove)+ 右側表單(TextField/Picker/TextEditor)+
│                          NSAlert 刪除確認 + EditorWindowDelegate
├── PromptStore.swift      @Observable;prompts(public var)/ load / saveNow / scheduleSave(500ms) /
│                          flushPendingSave / addNew(insert at 0)/ delete(id:) / reorder(category:from:to:)
├── Paster.swift           剪貼簿備份 → 寫入 → ⌘V → 0.6s 還原
├── Prompt.swift           id let;category / title / content var(SwiftUI binding 需要)
├── VisualEffectView.swift 毛玻璃 NSVisualEffectView 包裝
├── Assets.xcassets/AppIcon.appiconset/  10 張 icon
└── promptpop.entitlements 空 plist(Sandbox 已關)
```

### 幾個非顯而易見的設計決定
- HotKeyManager 是**全域 singleton-style**(static dict + sharedHandlerInstalled flag)。要加第 3 支熱鍵就 `HotKeyManager(keyCode: ..., id: 唯一數字, label: ...)` + 設 onTrigger,自動會接到共用 handler
- `orderedPrompts` 是**畫面順序**的權威來源;selectedIndex / keyMonitor / scrollTo 都用它
- `Prompt.id` 維持 `let` 是有意的:id 是 prompt 的不變身分,不該變
- `flushPendingSave` 之前的呼叫點:`applicationWillTerminate`、editor 視窗關、`showPopup`(防 race)
- listStyle `.inset` 是**為了能拖曳**才選的(sidebar 比較好看但不支援 .onMove)

---

## 不要再問的事(完整累積版)

- **環境**:macOS 14.5 + Xcode 15.4,**不要叫升級**
- **Sandbox**:已關(Day 3),別開回來
- **熱鍵**:⌘⇧P / ⌘⇧E 寫死,不做自訂 UI
- **登入啟動**:寫死一律開啟,不做開關
- **JSON 路徑**:`~/Library/Application Support/promptpop/prompts.json`
- **貼上機制**:剪貼簿 + ⌘V + 0.6s 還原,不走 Unicode typeString
- **貼上時序**:關視窗 → **立刻**降 `.accessory` → activate prev → 0.15s 後送 ⌘V
- **delegate 存取**:用 `AppDelegate.shared`,不用 `NSApp.delegate as? AppDelegate`
- **開頭/結尾**:prefix 貼完加 `\n`,suffix 原樣
- **搜尋**:literal 字面比對(中英對照在 roadmap)
- **debug log**:NSLog 才看得到,print 在 `log show` 裡不會出現
- **打包 .app**:用 `ditto -c -k --sequesterRsrc --keepParent`,不要用 `zip`
- **HotKeyManager 加新熱鍵**:`HotKeyManager(keyCode: ..., id: 唯一數字, label: "...")` + 設 onTrigger
- **TCC revoke 修法**:**remove (−) + re-add 從 Finder 拖**(切 OFF→ON 常救不回來)
- **Popup 點擊**用 SwiftUI Button + `.buttonStyle(.plain)`,**不要用 .onTapGesture**
- **鍵盤 ↑↓** 走 `orderedPrompts`(視覺順序),不是 filteredPrompts(原陣列順序)
- **IME-friendly**:keyMonitor 先 `firstResponder.hasMarkedText()` 檢查
- **Editor List**:`.listStyle(.inset)`,**不能用 .sidebar**(會失去拖曳能力)
- **新增 prompt**:`insert(at: 0)`,不是 append
- **showPopup**:先 `flushPendingSave()` 再 `load()`,順序不能反

---

## 我已經覺得 v0.1.2 收工了

下面這幾項是「**真的還想再做才開**」的清單,**沒打開的選擇也很合理**。

### 高 CP 值(值得做)

1. **README hero 圖 / GIF** — 唯一**強推**;Day 6 計畫到現在都沒做完;~10 分鐘改變 GitHub 路人第一印象
2. **menu bar tooltip 顯示版本** — `promptpop v0.1.2`,5 行 code
3. **挑個地方分享出去**(r/macapps、HN、台灣朋友)— 不分享就只是個人工具

### 中 CP 值(看心情)

4. **Universal binary**(arm64 + x86_64) — 給 Intel Mac 用戶,改個 build setting
5. **拼音 / 中英對照搜尋** — 唯一 README 列的限制
6. **動態 popup 高度** — prompt 少時不要太空

### 不要做(陷阱)

7. **Apple Developer ID**($99/年)— 沒人抱怨之前都不需要
8. **iCloud sync / 多裝置** — 你只有一台 Mac
9. **無止盡加 feature** — 它已經是個好工具了,別變成「給所有人的好工具」(那是另一個遊戲、代價無上限)

---

## 開工 / 不開工

- **真的有空想做點什麼**:挑高 CP 值清單第 1 項(README hero),其他都看心情
- **不開新 session 也很合理**:這個專案東西已經齊全,放著它在 background 自動跑,你日常用即可
- **再開時的最快流程**:把這份 handoff 開頭那段「定位+環境+存檔點」貼到新對話,加上「我想做 X」,就能無縫接上

收工愉快。
