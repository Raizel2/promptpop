//
//  VisualEffectView.swift
//  promptpop
//

import SwiftUI
import AppKit

/// 毛玻璃背景。包一層 NSVisualEffectView 給 SwiftUI 用。
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
