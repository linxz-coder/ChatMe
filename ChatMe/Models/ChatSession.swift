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
    var id: String //Unique id, chat session ID (ssid)
    var title: String           // Chat title
    var messages: [ChatMessage] // All messages in the current session
    var timestamp: Date         // created time
    var username: String        // username
    var userid: String            // user ID
    
    // Hashable protocol
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable protocol
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
