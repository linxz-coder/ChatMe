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
    @Attribute(.unique) var id: String // Unique ID
    var ssid: String              // session ssid
    var character: String       // character
    var chat_title: String      // title
    var chat_content: String    // chat content
    var thinking_content: String = ""  // thinking content
    var isThinkingExpanded: Bool = true //check if the thinking content needs to expand
    var imageUrl: String = ""   // image URL
    var sequence: Int           // sequence of the chat，start from 0
    var timestamp: Date         // created time
    var username: String        // username
    var userid: String            // user id
    var providerName: String = "" // Provider's name
    var modelName: String = ""    // model's name
    
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
