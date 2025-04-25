//
//  ShareFunctions.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/4/1.
//

import SwiftUI
import SwiftData

// Create a context to provide createNewSession function to share
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
        
        // Create new Session
        let newSession = ChatSession(
            id: sessionId,
            title: title,
            messages: [],
            timestamp: currentTimestamp,
            username: username,
            userid: userId
        )
        
        // Initialize
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
        
        // Add to SwiftData
        self.insert(newSession)
        self.insert(initialMessage)
        
        // Add message to the session
        chatViewModel.currentSession = newSession
        chatViewModel.chatMessages.append(initialMessage)
        
        // Handle sessions Array
        if chatViewModel.sessions.isEmpty {
            chatViewModel.sessions = [newSession]
        } else {
            chatViewModel.sessions.append(newSession)
        }
        
        do {
            try self.save()
        } catch {
            print("Fail to create new sessions: \(error.localizedDescription)")
        }
        
        return newSession
    }
}
