# promptpop

> Press ⌘⇧P to paste your favorite AI prompts into any app.

A tiny macOS utility that pops up a command-palette picker for your personal AI prompts. Search, pick with arrow keys, hit **Enter** — and it's pasted into whatever app you were just typing in.

No Dock icon. No settings UI. Just a JSON file you own and a hotkey that works everywhere.

## Features

- **⌘⇧P global hotkey** — pop the picker in any focused app. Pick with ↑↓ + Enter, **or just click** a row
- **⌘⇧E global hotkey** — open the built-in prompt editor (no JSON wrangling)
- **Literal search** through your prompt library by title or content
- **Prefix vs suffix** categories — prefix prompts get a trailing newline (for role-setting preambles); suffix prompts paste as-is
- **Built-in editor** — add, edit, delete, and **drag-to-reorder**; auto-saves as you type
- **IME-friendly** — arrow keys and Enter defer to Zhuyin / Pinyin / etc. composition; only act on the picker after the composition is committed
- **Safe reload** — if the underlying JSON is ever malformed, the last-good copy stays loaded and a red banner warns you until it's fixed
- **Menu bar icon** — click for quick access to the editor
- **Starts at login**, runs silently in the background

## Install

Requires **macOS 14+**.

1. Download the latest `promptpop-vX.Y.Z.app.zip` from [Releases](https://github.com/Raizel2/promptpop/releases)
2. Unzip, drag `promptpop.app` into `/Applications`
3. **Right-click → Open** the first time (unsigned apps are blocked by default; this only applies on first launch)
4. When prompted, grant **Accessibility** access:
   System Settings → Privacy & Security → Accessibility → add `promptpop.app` and turn it on

That's it. Press **⌘⇧P** anywhere to use it.

## Edit your prompts

**The easy way — built-in editor:**

Press **⌘⇧E** anywhere (or click the menu bar icon → *Edit Prompts…*) to open a proper editor window. Pick a prompt on the left, tweak title / category / content on the right. Changes auto-save 500ms after you stop typing. **Drag rows up or down in the sidebar to reorder** within a category — the popup reflects the new order next time it opens.

**The power-user way — directly edit the JSON:**

Your prompts live at:

```
~/Library/Application Support/promptpop/prompts.json
```

The shape of each entry:

```json
{
  "id": "unique-id",
  "category": "prefix",
  "title": "Short label shown in the picker",
  "content": "The full text that gets pasted"
}
```

- `category`: `"prefix"` appends a newline after the content; `"suffix"` pastes as-is
- Changes take effect the **next time you open the popup** — no restart needed
- If the JSON is malformed, promptpop keeps your last-good copy loaded and shows a red warning banner until you fix it

See [`examples/prompts.default.json`](./examples/prompts.default.json) for the starter set that ships as the first-launch default.

## Known limitations

- **Literal search only** — typing `zhongwen` won't find 中文 prompts, and vice versa. Cross-language / phonetic matching is on the roadmap.
- **Not signed with a paid Apple Developer ID** — first launch requires right-click → Open. After that it opens normally.

## License

MIT © Raizel — see [LICENSE](./LICENSE).

---

## 繁體中文說明

按 **⌘⇧P** 在任何 App 叫出你常用的 AI 提示詞選單,選一句按 Enter,直接貼到游標所在位置。

### 安裝(macOS 14+)

1. 從 [Releases](https://github.com/Raizel2/promptpop/releases) 下載 `promptpop-vX.Y.Z.app.zip`
2. 解壓後把 `promptpop.app` 拖到 `/Applications`
3. **第一次必須右鍵 → 打開**(未簽章的 App 被 Gatekeeper 擋是正常的,只有第一次需要這樣做)
4. 出現權限請求時授權「輔助使用」:
   系統設定 → 隱私與安全性 → 輔助使用 → 加入 `promptpop.app` 並打開開關

裝完就沒事了,沒 Dock 圖示、在背景跑。任何 App 裡按 ⌘⇧P 叫出來、按 ⌘⇧E 打開內建的 prompt 編輯視窗。

### 自訂你的提示詞

**簡單路線 — 內建編輯視窗:**

任何地方按 **⌘⇧E**(或點 menu bar 的 icon → *編輯 Prompts…*)叫出編輯視窗。左邊選一句、右邊改標題 / 類別 / 內容,停止打字 500ms 後自動存檔。**在左側清單把任一列上下拖移可調整順序**(只能在同類別內),popup 下次打開會照新順序顯示。

**進階路線 — 直接改 JSON:**

你的 prompts 放在:

```
~/Library/Application Support/promptpop/prompts.json
```

每筆的格式:

```json
{
  "id": "獨一無二的 id",
  "category": "prefix",
  "title": "選單裡顯示的短標題",
  "content": "真正會被貼出去的完整文字"
}
```

- `category`:`"prefix"` 貼完會多一個換行(適合放定基調的前言);`"suffix"` 原樣貼
- 改完**下次叫出視窗就生效**,不用重開 App
- JSON 壞掉的話,promptpop 會保留上一次讀成功的版本,視窗頂端會出現紅字警告,直到你修好

範例見 [`examples/prompts.default.json`](./examples/prompts.default.json)(也是第一次啟動時內建的預設空格版)。

### 已知限制

- **中英搜尋不對照** — 搜「zhongwen」找不到「中文」的 prompt,反之亦然。跨語言 / 拼音對照在 roadmap 上。
- **未用付費 Apple Developer ID 簽章**,第一次打開被 Gatekeeper 擋是預期行為,右鍵 → 打開即可。

### License

MIT © Raizel
