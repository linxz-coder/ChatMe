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
        // 单例初始化
        let container = try! ModelContainer(for: ChatMessage.self, ChatSession.self)
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(
            modelSettings: ModelSettingsData.shared,
            modelContext: container.mainContext
        ))
        
        //数据库路径
        print(URL.applicationSupportDirectory.path(percentEncoded: false))
        // 删除旧的存储文件
//        deleteOldDataStore()
    }
    
    private func deleteOldDataStore() {
        // 获取应用支持目录
        let applicationSupportURL = URL.applicationSupportDirectory
        
        // 构建持久化存储URL
        let storeURL = applicationSupportURL.appendingPathComponent("default.store")
        
        do {
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: storeURL.path) {
                // 删除主存储文件
                try FileManager.default.removeItem(at: storeURL)
                print("已删除旧的数据存储文件")
                
                // 删除相关的SQLite辅助文件
                try? FileManager.default.removeItem(at: applicationSupportURL.appendingPathComponent("default.store-shm"))
                try? FileManager.default.removeItem(at: applicationSupportURL.appendingPathComponent("default.store-wal"))
            }
        } catch {
            print("删除存储文件时出错: \(error)")
        }
    }
    
    
}
