//
//  ShareFunctions.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/4/1.
//

import SwiftUI
import SwiftData

// 创建一个上下文扩展，提供会话创建功能
extension ModelContext {
    
    func createNewSession(
        chatViewModel: ChatViewModel,
        settings: ModelSettingsData,
        username: String = "lxz",
        userId: String = "b5224a80-56ab-42ed-8cf4-394dc9728bbc",
        title: String = "默认聊天标题"
    ) -> ChatSession {
        let sessionId = UUID().uuidString
        let currentTimestamp = Date()
        
        // 创建新会话
        let newSession = ChatSession(
            id: sessionId,
            title: title,
            messages: [],
            timestamp: currentTimestamp,
            username: username,
            userid: userId
        )
        
        // 创建初始系统消息
        let initialMessage = ChatMessage(
            id: UUID().uuidString,
            ssid: sessionId,
            character: "system",
            chat_title: title,
            chat_content: "会话已创建",
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: 0,
            timestamp: currentTimestamp,
            username: username,
            userid: userId,
            providerName: settings.selectedModel?.providerName ?? "",
            modelName: settings.selectedModel?.name ?? ""
        )
        
        // 添加到数据库
        self.insert(newSession)
        self.insert(initialMessage)
        
        // 添加消息到会话
        chatViewModel.currentSession = newSession
        chatViewModel.chatMessages.append(initialMessage)
        
        // 处理sessions数组
        if chatViewModel.sessions.isEmpty {
            chatViewModel.sessions = [newSession]
        } else {
            chatViewModel.sessions.append(newSession)
        }
        
        do {
            try self.save()
        } catch {
            print("创建新会话失败: \(error.localizedDescription)")
        }
        
        return newSession
    }
}
