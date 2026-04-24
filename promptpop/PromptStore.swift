//
//  PromptStore.swift
//  promptpop
//

import Foundation
import Observation

@Observable
final class PromptStore {

    var prompts: [Prompt] = []

    /// 最近一次 load / save 失敗的訊息。nil = 正常
    private(set) var loadError: String?

    @ObservationIgnored private var saveWorkItem: DispatchWorkItem?

    init() {
        load()
    }

    /// 每次叫出視窗時重新讀一次,確保使用者剛改完的 prompts.json 會即時反映
    func load() {
        let url = Self.promptsFileURL

        // 首啟:檔案不存在就寫入內建預設 9 句
        if !FileManager.default.fileExists(atPath: url.path) {
            writeDefaultsToDisk(at: url)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Prompt].self, from: data)
            self.prompts = decoded
            self.loadError = nil
            NSLog("[PromptStore] 成功載入 \(decoded.count) 句")
        } catch {
            // 讀/解失敗:保留上次成功的 prompts,只設 error 讓 UI 顯示警告
            self.loadError = "prompts.json 讀取失敗:\(error.localizedDescription)"
            NSLog("[PromptStore] 載入失敗:\(error)")
        }
    }

    // MARK: - 寫檔 / 編輯

    /// 編輯後 500ms 沒動作才真的寫檔,避免每個鍵盤事件都 I/O
    func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// 還有 pending 的存檔就立刻寫下去。視窗關閉 / App 退出時呼叫
    func flushPendingSave() {
        guard saveWorkItem != nil else { return }
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveNow()
    }

    private func saveNow() {
        let url = Self.promptsFileURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(prompts)
            try data.write(to: url, options: [.atomic])
            loadError = nil
            NSLog("[PromptStore] 已存檔 \(prompts.count) 句")
        } catch {
            loadError = "存檔失敗:\(error.localizedDescription)"
            NSLog("[PromptStore] 存檔失敗:\(error)")
        }
    }

    /// 新增一句空的 prompt,回傳剛加的項目(讓 UI 立刻選取它)
    /// 插在陣列最前,這樣使用者剛加的 prompt 在 popup 裡出現在自己類別的最上面,
    /// 不用按 ↓ 到最底才看得到
    @discardableResult
    func addNew() -> Prompt {
        let new = Prompt(
            id: UUID().uuidString,
            category: .prefix,
            title: "新提示詞",
            content: ""
        )
        prompts.insert(new, at: 0)
        scheduleSave()
        return new
    }

    func delete(id: String) {
        prompts.removeAll { $0.id == id }
        scheduleSave()
    }

    /// 類別內拖曳排序。source / destination 是類別過濾後列表的 index,
    /// 需要翻譯成 self.prompts 的絕對 index 才能真正 move
    func reorder(category: PromptCategory, from source: IndexSet, to destination: Int) {
        // 1. 找到這個類別在 self.prompts 裡的所有位置(保留原 index)
        let inCategory = prompts.enumerated()
            .filter { $0.element.category == category }
        guard !inCategory.isEmpty else { return }

        // 2. 翻譯 source:filtered index → 絕對 index
        let absoluteSource = IndexSet(source.compactMap { filteredIdx in
            guard filteredIdx < inCategory.count else { return nil }
            return inCategory[filteredIdx].offset
        })

        // 3. 翻譯 destination
        //    .onMove 的 destination 可能等於 inCategory.count(丟到最後)
        let absoluteDestination: Int
        if destination >= inCategory.count {
            absoluteDestination = (inCategory.last?.offset ?? prompts.count - 1) + 1
        } else {
            absoluteDestination = inCategory[destination].offset
        }

        prompts.move(fromOffsets: absoluteSource, toOffset: absoluteDestination)
        scheduleSave()
    }

    private func writeDefaultsToDisk(at url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(Self.defaultPrompts)
            try data.write(to: url)
            NSLog("[PromptStore] 首啟:已寫入預設 prompts.json → \(url.path)")
        } catch {
            NSLog("[PromptStore] 寫入預設失敗:\(error)")
        }
    }

    static var promptsFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        return appSupport
            .appendingPathComponent("promptpop", isDirectory: true)
            .appendingPathComponent("prompts.json")
    }

    /// 首啟 fallback。也是 examples/prompts.default.json 的來源
    static let defaultPrompts: [Prompt] = [
        Prompt(
            id: "prefix-background",
            category: .prefix,
            title: "我的背景(請先修改此句)",
            content: "我是 [請填入出生年] 年生的 [請填入國籍] 人,[請填入學歷/專業] 背景,現職是 [請填入職業]。興趣是 [請填入興趣]。如果回答中有跟我的背景相關的連結,請主動指出。"
        ),
        Prompt(
            id: "prefix-no-flattery",
            category: .prefix,
            title: "不要迎合我",
            content: "請不要迎合我,直接告訴我真實的看法,包含我可能不想聽的。"
        ),
        Prompt(
            id: "prefix-devils-advocate",
            category: .prefix,
            title: "魔鬼代言人",
            content: "請扮演魔鬼代言人,挑戰我的想法。"
        ),
        Prompt(
            id: "suffix-ask-questions",
            category: .suffix,
            title: "先問我問題",
            content: "請先盡量問我問題,幫助你更好地回答。"
        ),
        Prompt(
            id: "suffix-clarify",
            category: .suffix,
            title: "釐清我在問什麼",
            content: "這是我的大致想法,但可能沒問得精準。先幫我釐清我真正想問的可能是什麼,再回答。"
        ),
        Prompt(
            id: "suffix-fresh-data",
            category: .suffix,
            title: "查最新資料",
            content: "請先查最新的資料再回答我,並附上資料來源(請自行判斷今天日期,並搜尋近期資訊)。"
        ),
        Prompt(
            id: "suffix-search-precedent",
            category: .suffix,
            title: "搜尋前人經驗",
            content: "請幫我搜尋網路或歷史上有沒有類似的產品、想法或討論。"
        ),
        Prompt(
            id: "suffix-three-angles",
            category: .suffix,
            title: "三個角度分析",
            content: "請從至少三個不同角度分析這個問題,再綜合給我結論。"
        ),
        Prompt(
            id: "suffix-table",
            category: .suffix,
            title: "用表格整理",
            content: "請用表格整理。"
        )
    ]
}
