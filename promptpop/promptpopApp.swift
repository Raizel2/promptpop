//
//  promptpopApp.swift
//  promptpop
//

import SwiftUI
import AppKit

@main
struct promptpopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyManager: HotKeyManager!
    private var promptStore: PromptStore!
    private var popupWindow: PopupWindow?
    private var windowDelegate: PopupWindowDelegate?
    
    private var previousApp: NSRunningApplication?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 啟動時先設 .accessory(無 Dock 圖示)
        NSApp.setActivationPolicy(.accessory)
        
        promptStore = PromptStore()
        print("[promptpop] 已載入提示詞:")
        for prompt in promptStore.prompts {
            print("  [\(prompt.category.displayName)] \(prompt.title)")
        }
        
        hotKeyManager = HotKeyManager()
        hotKeyManager.onTrigger = { [weak self] in
            self?.togglePopup()
        }
        
        print("[promptpop] 啟動完成,按 ⌘⇧P 叫出視窗")
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
        // 1. 關視窗
        popupWindow?.close()
        popupWindow = nil
        windowDelegate = nil
        
        // 2. 把前景還給原本的 App
        if let app = previousApp {
            app.activate()
        }
        previousApp = nil
        
        // 3. 延遲後降回 accessory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // 4. 延遲模擬貼上
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Paster.paste(text)
        }
    }
}
