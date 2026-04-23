import Cocoa
import Carbon.HIToolbox

/// 註冊單支全域快捷鍵(⌘⇧ + 指定按鍵),按下時觸發 onTrigger。
/// 用 Carbon 的 RegisterEventHotKey API,能真正獨佔這組按鍵。
///
/// ⚠️ 同一個 target 只裝一個共用的 Carbon event handler,
/// 每支熱鍵透過 `id → manager` 字典分發。
/// 原因:實測 `InstallEventHandler` 對同一 target 裝多個 handler 時,
/// 只有最後裝的會被呼叫,return `eventNotHandledErr` 也不會讓事件傳給 sibling。
final class HotKeyManager {

    /// 按下快捷鍵時要執行的動作,由外部設定
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?

    private let hotKeyID: EventHotKeyID
    private let keyCode: UInt32
    private let label: String

    // MARK: - 共用 dispatch

    /// `id → HotKeyManager` 註冊表。共用 handler 用這個 O(1) 找到該呼叫誰
    private static var managers: [UInt32: HotKeyManager] = [:]
    private static var sharedHandler: EventHandlerRef?
    private static var sharedHandlerInstalled = false

    /// - Parameters:
    ///   - keyCode: Carbon 的 virtual key code(例如 kVK_ANSI_P、kVK_ANSI_E)
    ///   - id: 用來識別這支熱鍵,同一 App 內要唯一
    ///   - label: log 用的名稱,像「⌘⇧P」「⌘⇧E」
    init(keyCode: UInt32, id: UInt32, label: String) {
        self.keyCode = keyCode
        self.hotKeyID = EventHotKeyID(signature: OSType(0x50504F50), id: id)
        self.label = label

        HotKeyManager.installSharedHandlerIfNeeded()
        HotKeyManager.managers[id] = self
        registerHotKey()
    }

    deinit {
        HotKeyManager.managers.removeValue(forKey: hotKeyID.id)
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    // MARK: - 共用 Carbon event handler(只裝一次)

    private static func installSharedHandlerIfNeeded() {
        guard !sharedHandlerInstalled else { return }
        sharedHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event = event else {
                    return OSStatus(eventNotHandledErr)
                }

                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else {
                    return OSStatus(eventNotHandledErr)
                }

                if let manager = HotKeyManager.managers[hkID.id] {
                    DispatchQueue.main.async {
                        manager.onTrigger?()
                    }
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            nil,
            &sharedHandler
        )
    }

    // MARK: - 註冊熱鍵

    private func registerHotKey() {
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            NSLog("[HotKeyManager] 註冊 \(label) 失敗,status = \(status)")
        } else {
            NSLog("[HotKeyManager] \(label) 已註冊")
        }
    }
}
