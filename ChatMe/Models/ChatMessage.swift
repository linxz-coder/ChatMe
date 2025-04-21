//
//  ChatMessage.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/7.
//

import Foundation
import SwiftData

@Model
class ChatMessage: Identifiable, Equatable {
    @Attribute(.unique) var id: String //id唯一
    var ssid: String              // 聊天标识
    var character: String       // 用户角色
    var chat_title: String      // 聊天标题
    var chat_content: String    // 具体内容
    var thinking_content: String = ""  // 存储思考内容
    var isThinkingExpanded: Bool = true //是否展开思考内容
    var imageUrl: String = ""   // 图片URL
    var sequence: Int           // 聊天顺序，从0开始
    var timestamp: Date         // 具体时间
    var username: String        // 用户名称
    var userid: String            // 用户id
    var providerName: String = "" // 添加供应商名称属性
    var modelName: String = ""    // 添加模型名称属性
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
    
    init(id: String, ssid: String, character: String, chat_title: String, chat_content: String, thinking_content: String, isThinkingExpanded: Bool, imageUrl: String, sequence: Int, timestamp: Date, username: String, userid: String, providerName: String, modelName: String) {
        self.id = id
        self.ssid = ssid
        self.character = character
        self.chat_title = chat_title
        self.chat_content = chat_content
        self.thinking_content = thinking_content
        self.isThinkingExpanded = isThinkingExpanded
        self.imageUrl = imageUrl
        self.sequence = sequence
        self.timestamp = timestamp
        self.username = username
        self.userid = userid
        self.providerName = providerName
        self.modelName = modelName
    }
}
