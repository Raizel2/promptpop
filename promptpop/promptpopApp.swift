//
//  promptpopApp.swift
//  promptpop
//

import SwiftUI
import AppKit
import ServiceManagement
import Carbon.HIToolbox  // kVK_ANSI_P / kVK_ANSI_E 用的

@main
struct promptpopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var popupHotKey: HotKeyManager!
    private var editorHotKey: HotKeyManager!
    private var promptStore: PromptStore!
    private var popupWindow: PopupWindow?
    private var windowDelegate: PopupWindowDelegate?

    // 編輯視窗
    private var editorWindow: NSWindow?
    private var editorWindowDelegate: EditorWindowDelegate?

    // Menu bar 圖示
    private var statusItem: NSStatusItem?

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

        popupHotKey = HotKeyManager(
            keyCode: UInt32(kVK_ANSI_P),
            id: 1,
            label: "⌘⇧P"
        )
        popupHotKey.onTrigger = { [weak self] in
            self?.togglePopup()
        }

        editorHotKey = HotKeyManager(
            keyCode: UInt32(kVK_ANSI_E),
            id: 2,
            label: "⌘⇧E"
        )
        editorHotKey.onTrigger = { [weak self] in
            self?.openEditor()
        }

        registerLoginItem()
        setupStatusBar()

        NSLog("[promptpop] 啟動完成 — ⌘⇧P 叫出選單、⌘⇧E 打開編輯視窗")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前把還沒寫的編輯落地
        promptStore?.flushPendingSave()
    }

    // MARK: - Menu bar

    private func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "text.bubble",
                accessibilityDescription: "promptpop"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "promptpop(⌘⇧P 叫選單 / ⌘⇧E 打開編輯)"
        }

        let menu = NSMenu()

        let editItem = NSMenuItem(
            title: "編輯 Prompts…",
            action: #selector(openEditor),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "結束 promptpop",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 編輯視窗

    @objc private func openEditor() {
        // 已開啟就帶到前面
        if let window = editorWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // 先重讀一次,拿到最新 JSON(以防使用者同時在改檔案)
        promptStore.load()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "promptpop 編輯"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 360)
        window.contentView = NSHostingView(
            rootView: EditorView(store: promptStore)
        )
        window.center()

        let delegate = EditorWindowDelegate { [weak self] in
            self?.editorWindowClosed()
        }
        window.delegate = delegate
        editorWindowDelegate = delegate
        editorWindow = window

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func editorWindowClosed() {
        // 關視窗時把 pending 的存檔寫完
        promptStore?.flushPendingSave()
        editorWindow = nil
        editorWindowDelegate = nil

        // popup 沒開的話就降回無 Dock 模式
        if popupWindow == nil {
            NSApp.setActivationPolicy(.accessory)
        }
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
