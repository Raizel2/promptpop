//
//  PromptStore.swift
//  promptpop
//

import Foundation
import Observation

// 負責讀取並管理所有提示詞
// @Observable 讓 SwiftUI 在資料變動時自動重新繪製 UI(Day 4 UI 會用到)
@Observable
final class PromptStore {
    
    // 所有載入的提示詞。UI 會從這裡拿資料
    private(set) var prompts: [Prompt] = []
    
    // 初始化時自動載入一次
    init() {
        load()
    }
    
    // 從磁碟讀取 prompts.json
    // 讀檔失敗不會讓 App crash,只會印錯誤訊息,prompts 維持空陣列
    func load() {
        let url = Self.promptsFileURL
        
        // 檢查檔案是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("[PromptStore] 找不到檔案:\(url.path)")
            print("[PromptStore] 預期位置:~/Library/Application Support/promptpop/prompts.json")
            return
        }
        
        // 讀檔 + 解碼
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Prompt].self, from: data)
            self.prompts = decoded
            print("[PromptStore] 成功載入 \(decoded.count) 句提示詞")
        } catch {
            print("[PromptStore] 載入失敗:\(error)")
        }
    }
    
    // 提示詞檔案的標準位置:~/Library/Application Support/promptpop/prompts.json
    // 拆成 static property 方便之後其他地方共用(例如監聽檔案變動)
    static var promptsFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        return appSupport
            .appendingPathComponent("promptpop", isDirectory: true)
            .appendingPathComponent("prompts.json")
    }
}
