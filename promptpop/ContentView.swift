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

    /// 視覺順序:先列出所有「開頭」、再列出所有「結尾」,每段內照 store.prompts 的順序。
    /// 鍵盤 ↑↓ 走的是這個順序,才會跟畫面一致
    private var orderedPrompts: [Prompt] {
        PromptCategory.allCases.flatMap { category in
            filteredPrompts.filter { $0.category == category }
        }
    }

    private var selectedPrompt: Prompt? {
        guard orderedPrompts.indices.contains(selectedIndex) else { return nil }
        return orderedPrompts[selectedIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let err = store.loadError {
                errorBanner(err)
            }
            searchBar
            Divider().opacity(0.3)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(PromptCategory.allCases, id: \.self) { category in
                            let promptsInCategory = filteredPrompts.filter { $0.category == category }
                            if !promptsInCategory.isEmpty {
                                sectionHeader(title: category.displayName)
                                ForEach(promptsInCategory) { prompt in
                                    Button {
                                        // 點一下直接貼上(跟 Enter 行為一致)
                                        handleSelect(prompt)
                                    } label: {
                                        promptRow(
                                            prompt: prompt,
                                            isSelected: selectedPrompt?.id == prompt.id
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .id(prompt.id)  // 供 scrollTo 定位
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                // 選中改變時自動捲到可見(↑↓ 鍵、搜尋後 reset 到 0 都會觸發)
                .onChange(of: selectedPrompt?.id) { _, newId in
                    guard let id = newId else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 520, height: 460)
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
            // 如果輸入法正在組字(例如注音/拼音還沒上屏),所有鍵都放行給 TextField/IME 處理。
            // 這樣:
            //   - 注音組字中按 Enter 會正常 commit 候選字,不會被我們當「選中項目」
            //   - 組字中按 ↑↓ 會讓輸入法切候選字,不會跳到別的 prompt
            if let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
               editor.hasMarkedText() {
                return event
            }

            // keyCode 參考:125=↓  126=↑  36=Enter  76=小鍵盤 Enter
            switch event.keyCode {
            case 125: // ↓
                if selectedIndex < orderedPrompts.count - 1 {
                    selectedIndex += 1
                }
                return nil  // 吃掉事件,不讓 TextField 收到
            case 126: // ↑
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return nil
            case 36, 76: // Enter
                NSLog("[promptpop] Enter pressed, selectedPrompt=\(selectedPrompt?.title ?? "nil")")
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

        // 交給 AppDelegate 完成「關視窗 → 切回原 App → 貼上」流程
        AppDelegate.shared?.pasteAndDismiss(text: textToPaste)
    }
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .lineLimit(2)
            Spacer()
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.85))
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
