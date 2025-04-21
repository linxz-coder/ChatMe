//
//  ChatSession.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/7.
//

import Foundation
import SwiftData

@Model
class ChatSession: Identifiable, Hashable {
    var id: String //id唯一, 聊天会话ID (ssid)
    var title: String           // 聊天标题
    var messages: [ChatMessage] // 该会话中的所有消息
    var timestamp: Date         // 会话创建时间
    var username: String        // 用户名称
    var userid: String            // 用户ID
    
    // 实现 Hashable 协议的函数
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // 添加 Equatable 协议的实现
    static func == (lhs: ChatSession, rhs: ChatSession) -> Bool { lhs.id == rhs.id }
    
    init(id: String, title: String, messages: [ChatMessage], timestamp: Date, username: String, userid: String) {
        self.id = id
        self.title = title
        self.messages = messages
        self.timestamp = timestamp
        self.username = username
        self.userid = userid
    }
}
