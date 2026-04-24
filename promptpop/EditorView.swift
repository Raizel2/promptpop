//
//  EditorView.swift
//  promptpop
//
//  編輯視窗:左清單、右表單。選一個 prompt 直接編輯。
//  失焦不會關,auto-save 500ms debounce(透過 store.scheduleSave)。
//

import SwiftUI
import AppKit

struct EditorView: View {
    @Bindable var store: PromptStore
    @State private var selectedId: String?

    var body: some View {
        HSplitView {
            leftPanel
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 360)

            rightPanel
                .frame(minWidth: 340)
        }
        .frame(minWidth: 560, minHeight: 360)
        .onAppear {
            if selectedId == nil {
                selectedId = store.prompts.first?.id
            }
        }
        .onChange(of: store.prompts) { _, _ in
            // 任何編輯(binding 寫入 / 新增 / 刪除)最終都會走到這;統一 debounce 存檔
            store.scheduleSave()
        }
    }

    // MARK: - 左:清單 + 新增/刪除

    private var leftPanel: some View {
        VStack(spacing: 0) {
            List(selection: $selectedId) {
                ForEach(PromptCategory.allCases, id: \.self) { category in
                    let inCategory = store.prompts.filter { $0.category == category }
                    if !inCategory.isEmpty {
                        Section(header: Text(category.displayName)) {
                            ForEach(inCategory) { p in
                                promptRow(p).tag(p.id)
                            }
                            .onMove { source, dest in
                                store.reorder(category: category, from: source, to: dest)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)

            Divider()

            HStack(spacing: 10) {
                Button(action: addPrompt) {
                    Image(systemName: "plus")
                        .frame(width: 18, height: 18)
                }
                .help("新增提示詞")

                Button(action: deleteSelected) {
                    Image(systemName: "minus")
                        .frame(width: 18, height: 18)
                }
                .help("刪除選取的提示詞")
                .disabled(selectedId == nil)

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private func promptRow(_ p: Prompt) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(p.title.isEmpty ? "(未命名)" : p.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(p.title.isEmpty ? .secondary : .primary)
                .lineLimit(1)
            Text(p.content.isEmpty ? "(無內容)" : String(p.content.prefix(60)))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 右:表單 或 placeholder

    @ViewBuilder
    private var rightPanel: some View {
        if let idx = selectedIndex {
            editorForm(index: idx)
        } else {
            placeholder
        }
    }

    private var selectedIndex: Int? {
        guard let id = selectedId else { return nil }
        return store.prompts.firstIndex { $0.id == id }
    }

    private func editorForm(index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                field(label: "標題") {
                    TextField("簡短標題,會出現在選單裡", text: $store.prompts[index].title)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                }

                field(label: "類別") {
                    Picker("", selection: $store.prompts[index].category) {
                        ForEach(PromptCategory.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Text(store.prompts[index].category == .prefix
                         ? "開頭:貼完會自動換行(適合放定基調的前言)"
                         : "結尾:原樣貼上")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                field(label: "內容") {
                    TextEditor(text: $store.prompts[index].content)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                idRow(index: index)
            }
            .padding(20)
        }
    }

    private func field<Inner: View>(
        label: String,
        @ViewBuilder _ inner: () -> Inner
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            inner()
        }
    }

    private func idRow(index: Int) -> some View {
        HStack(spacing: 6) {
            Text("ID")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(store.prompts[index].id)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("選一個 prompt 編輯")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("或點左下的 + 新增一句")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 動作

    private func addPrompt() {
        let new = store.addNew()
        selectedId = new.id
    }

    private func deleteSelected() {
        guard let id = selectedId,
              let p = store.prompts.first(where: { $0.id == id }) else { return }

        let alert = NSAlert()
        alert.messageText = "刪除「\(p.title.isEmpty ? "(未命名)" : p.title)」?"
        alert.informativeText = "刪除後無法還原。"
        alert.addButton(withTitle: "刪除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            store.delete(id: id)
            selectedId = nil
        }
    }
}

// MARK: - NSWindow delegate:視窗關閉時通知 AppDelegate 清理

final class EditorWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
