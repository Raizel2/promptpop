import Cocoa
import SwiftUI

/// promptpop 的浮動視窗。
/// 負責視窗「行為」:無邊框、浮在最上層、失焦自動關閉、按 Esc 關閉、置中顯示。
/// 視窗裡放什麼 UI 內容,由外部傳入。
///
/// ⚠️ 重要:必須設定 isReleasedWhenClosed = false,
/// 否則第二次叫出視窗時會因為持有已釋放的參考而 crash。
final class PopupWindow: NSWindow {

    init<Content: View>(content: Content) {
        // 視窗大小需與 ContentView 的 .frame 一致
        let contentSize = NSSize(width: 520, height: 460)

        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],   // 無邊框,沒有紅綠黃標題列
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false

        // 把 SwiftUI 的 View 裝進來
        self.contentView = NSHostingView(rootView: content)

        // 視窗外觀 & 行為
        self.isOpaque = false                            // 允許透明
        self.backgroundColor = .clear                     // 背景透明,讓圓角等設計能顯示
        self.hasShadow = true                             // 有陰影,看起來像浮動面板
        self.level = .floating                            // 浮在最上層
        self.collectionBehavior = [.canJoinAllSpaces,    // 在所有桌面空間都能出現
                                    .fullScreenAuxiliary] // 全螢幕 App 上也能出現
        self.isMovableByWindowBackground = true          // 拖拉背景可以移動視窗
        self.animationBehavior = .utilityWindow
    }

    /// 按 Esc 關閉。
    /// NSWindow 本身會把 Esc 對應到 cancelOperation,我們覆寫它。
    override func cancelOperation(_ sender: Any?) {
        self.close()
    }

    /// 一個小技巧:讓無邊框視窗也能成為 key window(能接收鍵盤事件)。
    /// 預設無邊框視窗不接鍵盤,這樣搜尋框就打不了字。
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    /// 把視窗置中在「滑鼠目前所在的螢幕」,並顯示。
    func showCentered() {
        // 找出滑鼠在哪個螢幕
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main

        if let screen = targetScreen {
            let f = screen.visibleFrame
            let x = f.midX - self.frame.width / 2
            let y = f.midY - self.frame.height / 2
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// 監聽「視窗失焦」的小幫手。
/// 當使用者點了視窗外的地方,視窗就關閉。
final class PopupWindowDelegate: NSObject, NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.close()
        }
    }
}
