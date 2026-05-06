//
//  Paster.swift
//  promptpop
//

import AppKit
import Carbon.HIToolbox

enum Paster {
    /// 把 text 放到剪貼簿 → 模擬 ⌘V → 0.5 秒後還原原本的剪貼簿
    static func paste(_ text: String) {
        NSLog("[promptpop] Paster.paste called, len=\(text.count)")
        let pasteboard = NSPasteboard.general

        // 備份使用者原本的剪貼簿(可能是文字、圖片、檔案…通通保留)
        let savedItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []

        // 寫入要貼的文字
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 等一點點時間讓焦點真的切到目標 App,再送 ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            postCommandV()
        }

        // 貼完 0.5 秒後還原剪貼簿
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pasteboard.clearContents()
            if !savedItems.isEmpty {
                pasteboard.writeObjects(savedItems)
            }
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}
