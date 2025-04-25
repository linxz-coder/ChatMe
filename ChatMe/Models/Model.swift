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
    var modelType: ModelType = .chat // Add model type field
    
    // Equatable protocol
    static func == (lhs: Model, rhs: Model) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model Type enum
enum ModelType: String, Codable {
    case chat       // Text Chat
    case image      // Image Generation
}

