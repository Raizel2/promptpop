//
//  Paster.swift
//  promptpop
//

import AppKit

enum Paster {
    static func paste(_ text: String) {
        print("[Paster] 開始直接輸入,內容長度:\(text.count)")
        
        // 延遲讓焦點切回去
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            typeString(text)
        }
    }
    
    /// 逐字元模擬 Unicode 輸入,不經過剪貼簿
    private static func typeString(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        for char in text {
            // 每個字元變成 UTF-16 code units
            let utf16 = Array(String(char).utf16)
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }
            
            // 塞入 Unicode 字串
            utf16.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buffer.baseAddress)
                keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: buffer.baseAddress)
            }
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
        
        print("[Paster] ✅ 輸入完成")
    }
}
