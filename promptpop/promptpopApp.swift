//
//  promptpopApp.swift
//  promptpop
//

import SwiftUI
import AppKit
import ServiceManagement

@main
struct promptpopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var hotKeyManager: HotKeyManager!
    private var promptStore: PromptStore!
    private var popupWindow: PopupWindow?
    private var windowDelegate: PopupWindowDelegate?

    private var previousApp: NSRunningApplication?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 啟動時先設 .accessory(無 Dock 圖示)
        NSApp.setActivationPolicy(.accessory)

        // 請求輔助使用權限。第一次啟動會彈系統對話框
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        NSLog("[promptpop] Accessibility trusted: \(trusted)")

        promptStore = PromptStore()
        NSLog("[promptpop] 已載入提示詞 \(promptStore.prompts.count) 句")

        hotKeyManager = HotKeyManager()
        hotKeyManager.onTrigger = { [weak self] in
            self?.togglePopup()
        }

        registerLoginItem()

        NSLog("[promptpop] 啟動完成,按 ⌘⇧P 叫出視窗")
    }

    /// 用 SMAppService 把 promptpop 註冊為登入項目(macOS 13+)。
    /// 寫死一律開啟,無 UI 開關。
    private func registerLoginItem() {
        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            NSLog("[promptpop] 登入啟動已啟用")
        default:
            do {
                try service.register()
                NSLog("[promptpop] 登入啟動註冊成功")
            } catch {
                NSLog("[promptpop] 登入啟動註冊失敗:\(error.localizedDescription)")
            }
        }
    }
    
    func togglePopup() {
        if let window = popupWindow, window.isVisible {
            closePopup()
        } else {
            showPopup()
        }
    }
    
    func showPopup() {
        previousApp = NSWorkspace.shared.frontmostApplication

        // 暫時提升為正常 App(才能正確處理鍵盤與焦點切換)
        NSApp.setActivationPolicy(.regular)

        // 每次叫出視窗都重讀一次 prompts.json(讓使用者剛改完就能看到)
        promptStore.load()

        let content = ContentView(store: promptStore)
        let window = PopupWindow(content: content)

        let delegate = PopupWindowDelegate()
        window.delegate = delegate
        windowDelegate = delegate

        window.showCentered()
        popupWindow = window
    }
    
    func closePopup() {
        popupWindow?.close()
        popupWindow = nil
        windowDelegate = nil
        
        // 降回 accessory(無 Dock 圖示)
        NSApp.setActivationPolicy(.accessory)
    }
    
    func pasteAndDismiss(text: String) {
        NSLog("[promptpop] pasteAndDismiss called, prevApp=\(previousApp?.bundleIdentifier ?? "nil")")

        // 1. 關視窗
        popupWindow?.close()
        popupWindow = nil
        windowDelegate = nil

        // 2. 立刻降回 accessory — 讓 promptpop 不再是前景 App,⌘V 才會送到目標
        NSApp.setActivationPolicy(.accessory)

        // 3. 把前景還給原本的 App
        if let app = previousApp {
            app.activate()
        }
        previousApp = nil

        // 4. 延遲模擬貼上(等前景 App 真的拿到焦點)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Paster.paste(text)
        }
    }
}
