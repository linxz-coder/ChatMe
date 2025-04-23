//
//  ArtifactMessageView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/12.
//
import SwiftUI
import MarkdownUI
import SwiftData

struct ArtifactMessageView: View {
    let message: ChatMessage //Must be at the front
    @ObservedObject var viewModel: ChatViewModel
    @Binding var userFinishedInput: Bool
    @ObservedObject var artifactViewModel: ArtifactViewModel
    
    var body: some View {
        if message.character == "user" {
            // User Message
            MessageView(
                message: message,
                viewModel: viewModel,
                userFinishedInput: $userFinishedInput,
                artifactViewModel: artifactViewModel
            )
        } else {
            // AI Message
            VStack(alignment: .leading, spacing: 0) {
                MessageView(
                    message: message,
                    viewModel: viewModel,
                    userFinishedInput: $userFinishedInput,
                    artifactViewModel: artifactViewModel
                )
                
                // 分析消息中的代码块
                .onAppear {
                    if message.character == "ai" {
                        artifactViewModel.extractCodeBlocks(from: message.chat_content)
                    }
                }
                .onChange(of: message.chat_content) { _, _ in
                    if message.character == "ai" {
                        artifactViewModel.extractCodeBlocks(from: message.chat_content)
                    }
                }
            }
        }
    }
}

#Preview {
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatMessage.self, ChatSession.self, configurations: config)
    
    // Create the required environment objects
    let modelSettings = ModelSettingsData.shared
    let chatViewModel = ChatViewModel(
        modelSettings: modelSettings,
        modelContext: container.mainContext
    )
    
    // 创建示例消息
    let sampleMessage = ChatMessage(
        id: UUID().uuidString,
        ssid: "test-session",
        character: "ai",
        chat_title: "Test Chat",
        chat_content: """
       This is a code block：
       
       ```html
       <!DOCTYPE html>
       <html>
       <head>
           <title>Test Page</title>
       </head>
       <body>
           <h1>Hello World</h1>
           <p>This is a HTML page.</p>
       </body>
       </html>
       ```
       
       还有CSS代码：
       
       ```css
       body {
           font-family: sans-serif;
           margin: 20px;
       }
       h1 {
           color: blue;
       }
       ```
       """,
        thinking_content: "",
        isThinkingExpanded: true,
        imageUrl: "",
        sequence: 1,
        timestamp: Date(),
        username: "test user",
        userid: UUID().uuidString,
        providerName: "test provider",
        modelName: "test model"
    )
    
    // Create and config ArtifactViewModel
    let artifactViewModel = ArtifactViewModel()
    
    
    return ArtifactMessageView(
        message: sampleMessage,
        viewModel: chatViewModel,
        userFinishedInput: .constant(true),
        artifactViewModel: artifactViewModel
    )
    .environmentObject(LocalizationManager.shared)
}
