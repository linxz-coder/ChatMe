//
//  ChatMeApp.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI
import SwiftData

@main
struct ChatMeApp: App {
    
    @StateObject private var modelSettings = ModelSettingsData.shared
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var chatViewModel: ChatViewModel
    @Environment(\.modelContext) private var modelContext
    
    var body: some Scene {
        
        WindowGroup {
            ContentView()
                .environmentObject(modelSettings)
                .environmentObject(localization)
                .environmentObject(chatViewModel)
        }
        .modelContainer(for: [ChatMessage.self, ChatSession.self])
        
        
        Settings {
            SettingsView()
                .environmentObject(modelSettings)
                .environmentObject(localization)
                .environmentObject(chatViewModel)
            
        }
        .defaultSize(width: 800, height: 600)
    }
    
    init(){
        // Singleton initialization
        let container = try! ModelContainer(for: ChatMessage.self, ChatSession.self)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(
            modelSettings: ModelSettingsData.shared,
            modelContext: container.mainContext
        ))
        
        // Database path
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
        // Delete old storage files
        //        deleteOldDataStore()
    }
    
    private func deleteOldDataStore() {
        // Get the application support directory
        let applicationSupportURL = URL.applicationSupportDirectory
        
        // Build a persistent storage URL
        let storeURL = applicationSupportURL.appendingPathComponent("default.store")
        
        do {
            // Check if the file exists
            if FileManager.default.fileExists(atPath: storeURL.path) {
                // Delete the main storage file
                try FileManager.default.removeItem(at: storeURL)
                print("Deleted old storage file.")
                
                // Delete the relevant SQLite auxiliary files
                try? FileManager.default.removeItem(at: applicationSupportURL.appendingPathComponent("default.store-shm"))
                try? FileManager.default.removeItem(at: applicationSupportURL.appendingPathComponent("default.store-wal"))
            }
        } catch {
            print("Fail to delete old storage file: \(error)")
        }
    }
}
