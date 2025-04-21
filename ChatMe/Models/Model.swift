//
//  Model.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/28.
//

import Foundation

struct Model: Identifiable, Hashable, Codable, Equatable {
    var id = UUID()
    var providerName: String
    var name: String
    var baseUrl: String
    var apiKey: String
    var isThinkingEnabled: Bool = false
    var modelType: ModelType = .chat // 添加模型类型字段
    
    // 实现Equatable协议
    static func == (lhs: Model, rhs: Model) -> Bool {
        return lhs.id == rhs.id
    }
}

// 增加模型类型枚举
enum ModelType: String, Codable {
    case chat       // 文字聊天
    case image      // 图像生成
}

