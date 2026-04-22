//
//  ContentView.swift
//  promptpop
//

import SwiftUI
import AppKit

struct ContentView: View {
    let store: PromptStore
    
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    
    // 鍵盤事件監聽器。App 關閉視窗時要移除,避免殘留
    @State private var keyMonitor: Any?
    
    // 根據搜尋文字過濾後的提示詞
    private var filteredPrompts: [Prompt] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return store.prompts }
        return store.prompts.filter { prompt in
            prompt.title.localizedCaseInsensitiveContains(query)
                || prompt.content.localizedCaseInsensitiveContains(query)
        }
    }
    
    private var selectedPrompt: Prompt? {
        guard filteredPrompts.indices.contains(selectedIndex) else { return nil }
        return filteredPrompts[selectedIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.3)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(PromptCategory.allCases, id: \.self) { category in
                        let promptsInCategory = filteredPrompts.filter { $0.category == category }
                        if !promptsInCategory.isEmpty {
                            sectionHeader(title: category.displayName)
                            ForEach(promptsInCategory) { prompt in
                                promptRow(
                                    prompt: prompt,
                                    isSelected: selectedPrompt?.id == prompt.id
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 520, height: 360)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        // 視窗出現時啟動鍵盤監聽
        .onAppear {
            installKeyMonitor()
        }
        // 視窗消失時移除,避免重複註冊
        .onDisappear {
            removeKeyMonitor()
        }
    }
    
    // 安裝鍵盤監聽器。回傳 nil 代表事件被吃掉、不往下傳
    private func installKeyMonitor() {
        // 避免重複安裝
        if keyMonitor != nil { return }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // keyCode 參考:125=↓  126=↑  36=Enter  76=小鍵盤 Enter
            switch event.keyCode {
            case 125: // ↓
                if selectedIndex < filteredPrompts.count - 1 {
                    selectedIndex += 1
                }
                return nil  // 吃掉事件,不讓 TextField 收到
            case 126: // ↑
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return nil
            case 36, 76: // Enter
                if let prompt = selectedPrompt {
                    handleSelect(prompt)
                }
                return nil
            default:
                return event  // 其他鍵照常傳給 TextField(包含中文打字)
            }
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleSelect(_ prompt: Prompt) {
        // 開頭類結尾加換行,結尾類原樣
        let textToPaste: String
        switch prompt.category {
        case .prefix:
            textToPaste = prompt.content + "\n"
        case .suffix:
            textToPaste = prompt.content
        }
        
        // 1. 關視窗
        NSApp.keyWindow?.close()
        
        // 2. 讓 promptpop 退居幕後,把前景身份還給原本的 App
        NSApp.hide(nil)
        
        // 3. 延遲一點再貼(等系統完成切換)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Paster.paste(textToPaste)
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            TextField("搜尋提示詞…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
    
    private func promptRow(prompt: Prompt, isSelected: Bool) -> some View {
        HStack {
            Text(prompt.title)
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
    }
}
