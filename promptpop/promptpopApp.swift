import SwiftUI
import AppKit

@main
struct promptpopApp: App {

    // 把 AppDelegate 接上。AppDelegate 負責處理「App 啟動後」的邏輯(例如註冊熱鍵、建立視窗管理器等)。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // promptpop 不需要常駐主視窗,用 Settings 這個「空 Scene」當佔位,
        // App 就不會自動開視窗,但還是有個合法的 Scene 結構。
        Settings {
            EmptyView()
        }
    }
}

/// AppDelegate:處理 App 層級的事件,例如啟動、快捷鍵、視窗管理。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var hotKeyManager: HotKeyManager?
    private var popupWindow: PopupWindow?
    private let popupDelegate = PopupWindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 設成 accessory 模式:不在 Dock 顯示,不搶 App 切換器。
        // 這樣 promptpop 就像個隱形幫手,按熱鍵才冒出來。
        NSApp.setActivationPolicy(.accessory)

        // 建立熱鍵管理器,按下時叫出視窗
        hotKeyManager = HotKeyManager()
        hotKeyManager?.onTrigger = { [weak self] in
            self?.togglePopup()
        }

        print("[promptpop] 啟動完成,按 ⌘⇧P 叫出視窗")
    }

    /// 每次按 ⌘⇧P 時被呼叫。
    /// 如果視窗已經開著,再按一次就關掉;如果關著,就打開。
    private func togglePopup() {
        if let window = popupWindow, window.isVisible {
            window.close()
            return
        }

        showPopup()
    }

    private func showPopup() {
        // 視窗裡先放一個最簡單的內容:只顯示「promptpop」四個字,用來驗證整條管線有通。
        // 之後會把這裡換成真正的搜尋 UI。
        let content = PlaceholderView()

        let window = PopupWindow(content: content)
        window.delegate = popupDelegate
        window.showCentered()

        self.popupWindow = window
    }
}

/// 臨時的佔位內容。真正的搜尋 UI 之後再做。
struct PlaceholderView: View {
    var body: some View {
        ZStack {
            // 毛玻璃背景
            VisualEffectView()

            Text("promptpop")
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(width: 520, height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// 包一層 NSVisualEffectView,給 SwiftUI 用。
/// 這個是 macOS 原生的毛玻璃效果。
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
