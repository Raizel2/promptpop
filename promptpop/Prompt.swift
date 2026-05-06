//
//  Prompt.swift
//  promptpop
//

import Foundation

// 單一提示詞的資料結構
// 欄位順序和名稱必須與 prompts.json 完全一致,Codable 才能自動轉換
struct Prompt: Codable, Identifiable, Hashable {
    let id: String
    var category: PromptCategory
    var title: String
    var content: String
}

// 提示詞分類:開頭(prefix)或結尾(suffix)
// 用 String 作為原始值,讓 JSON 裡的 "prefix" / "suffix" 字串能自動對應過來
enum PromptCategory: String, Codable, CaseIterable {
    case prefix
    case suffix
    
    // 中文顯示名稱,之後 UI 上會用到
    var displayName: String {
        switch self {
        case .prefix: return "開頭"
        case .suffix: return "結尾"
        }
    }
}
