import Cocoa
import Carbon.HIToolbox

/// 負責註冊全域快捷鍵 ⌘⇧P,按下時觸發 onTrigger 回呼。
/// 用 Carbon 的 RegisterEventHotKey API,能真正獨佔這組按鍵。
final class HotKeyManager {

    /// 按下快捷鍵時要執行的動作,由外部設定
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// 幫 promptpop 的熱鍵取一個識別碼,數字隨便設,只要在自己 App 裡唯一就好
    private let hotKeyID = EventHotKeyID(signature: OSType(0x50504F50), id: 1) // "PPOP"

    init() {
        registerHotKey()
    }

    deinit {
        unregisterHotKey()
    }

    private func registerHotKey() {
        // 1. 告訴系統我們要監聽「熱鍵被按下」這種事件
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // 2. 裝一個 callback:系統收到熱鍵事件 → 呼叫這個函式
        //    因為 C API 不能直接抓 self,所以用 Unmanaged 把 self 的指標傳進去,callback 裡再拿回來
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData, let event = event else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

                // 確認這個事件真的是我們註冊的熱鍵(不是別的)
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

                if status == noErr && hkID.id == manager.hotKeyID.id {
                    // 回主執行緒呼叫 onTrigger(UI 相關的動作必須在主執行緒)
                    DispatchQueue.main.async {
                        manager.onTrigger?()
                    }
                }

                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        // 3. 實際向系統註冊 ⌘⇧P
        //    kVK_ANSI_P = P 鍵的鍵碼
        //    cmdKey + shiftKey = 修飾鍵組合
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_P)

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            print("[HotKeyManager] 註冊熱鍵失敗,status = \(status)")
        } else {
            print("[HotKeyManager] ⌘⇧P 已註冊")
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}
