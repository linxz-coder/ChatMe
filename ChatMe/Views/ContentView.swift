//
//  ContentView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @EnvironmentObject var settings: ModelSettingsData
    @State private var showModelPicker = false
    @EnvironmentObject var chatViewModel: ChatViewModel
    
    var body: some View {
        NavigationSplitView {
            SideBarView()
        } detail: {
            ZStack(alignment: .topLeading) {
                VStack {
                    ChatView()
                }
                
                if showModelPicker {
                    ModelPickerView(isPresented: $showModelPicker)
                        .environmentObject(settings)
                        .zIndex(1) // Ensure displayed at the top
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    //Select Model
                    Button {
                        showModelPicker.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 2) {
                                // Main Title
                                Text(settings.selectedModel?.providerName ?? "Select Model")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                
                                if !settings.modelName.isEmpty {
                                    Text(settings.modelName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(showModelPicker ? 180 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                }
                
            }
        }
        
        
    }
}

#Preview {
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatMessage.self, ChatSession.self, configurations: config)
    
    
    // Create some sample data
    let session = ChatSession(
        id: UUID().uuidString,
        title: "Test Session",
        messages: [],
        timestamp: Date(),
        username: "test user",
        userid: UUID().uuidString
    )
    
    // Create multiple test messages
    let messageContents = [
        "Hello, this is the first test message.",
        "this is the second test message.",
        "this is the third test message.",
        "this is the fourth test message.",
        "this is the fifth test message."
    ]
    
    // Create alternating messages between users and AI.
    for (index, content) in messageContents.enumerated() {
        let character = index % 2 == 0 ? "user" : "ai"
        let responseContent = index % 2 == 0 ? content : "AI：\(content)"
        
        let message = ChatMessage(
            id: UUID().uuidString,
            ssid: session.id,
            character: character,
            chat_title: "Test Session",
            chat_content: responseContent,
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: index + 1,
            timestamp: Date().addingTimeInterval(Double(-300 + index * 60)),  // 1 minute per message
            username: "test user",
            userid: UUID().uuidString,
            providerName: "Test Provider",
            modelName: "Test Model"
        )
        
        container.mainContext.insert(message)
    }
    
    // Add sample data to the container
    container.mainContext.insert(session)
    
    // Create the required environment objects
    let modelSettings = ModelSettingsData.shared
    let chatViewModel = ChatViewModel(
        modelSettings: modelSettings,
        modelContext: container.mainContext
    )
    
    return ContentView()
        .environmentObject(modelSettings)
        .environmentObject(LocalizationManager.shared)
        .environmentObject(chatViewModel)
        .modelContainer(container)
}
