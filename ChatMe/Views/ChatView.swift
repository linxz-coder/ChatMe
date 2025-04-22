//
//  ChatView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.modelContext) private var context
    @State var message: String = ""
    @State var userFinishedInput = false
    @EnvironmentObject var settings: ModelSettingsData
    @State private var scrollProxy: ScrollViewProxy? = nil
    @StateObject private var artifactViewModel = ArtifactViewModel()
    @State private var dividerPosition: CGFloat = 0.5 // 默认1:1分割
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 0) {
                    // 左侧聊天区域
                    VStack {
                        // 消息列表
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 20) {
                                    
                                    // 显示所有聊天消息，排除系统信息
                                    ForEach(chatViewModel.chatMessages.filter { $0.character != "system" }) { message in
                                        ArtifactMessageView(
                                            message: message,
                                            viewModel: chatViewModel,
                                            userFinishedInput: $userFinishedInput,
                                            artifactViewModel: artifactViewModel
                                        )
                                        .id(message.id)
                                    }
                                }
                                .padding(.vertical)
                            }
                            .onChange(of: chatViewModel.chatMessages) { messages in
                                // 当消息列表更新时，滚动到最新消息
                                if let lastMessage = messages.last {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                            .onAppear {
                                scrollProxy = proxy
                            }
                        }
                        // 错误消息显示
                        if !chatViewModel.errorMessage.isEmpty {
                            Text(chatViewModel.errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                                .padding(.horizontal)
                        }
                        
                        //消息输入框
                        InputView(chatViewModel: _chatViewModel, message: $message,userFinishedInput: $userFinishedInput)
                    }
                    
                    //                    .frame(width: artifactViewModel.isActive ?
                    .frame(width: artifactViewModel.isActive && artifactViewModel.isPreviewEnabled ?
                           geometry.size.width * dividerPosition :
                            geometry.size.width)
                    .background(Color(light: .white, dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                context.createNewSession(chatViewModel: chatViewModel, settings: settings)
                                userFinishedInput = false
                                message = ""
                            } label : {
                                Label("新会话", systemImage: "plus.circle")
                                    .font(.callout)
                            }
                            .keyboardShortcut("n", modifiers: .command)
                        }
                    }
                    
                    // 右侧代码预览区域 - 仅当有代码块且激活时显示
                    if artifactViewModel.isActive && artifactViewModel.isPreviewEnabled {
                        ArtifactPreview(viewModel: artifactViewModel)
                            .frame(width: geometry.size.width * (1 - dividerPosition))
                            .transition(.move(edge: .trailing))
                    }
                }
                
                // 添加可拖动分隔栏，仅当预览窗口激活时显示
                //                if artifactViewModel.isActive {
                if artifactViewModel.isActive && artifactViewModel.isPreviewEnabled {
                    
                    // 分隔栏 - 更容易选中的版本
                    ZStack {
                        Rectangle()
                            .fill(Color(light: Color.white.opacity(0.6), dark: Color.gray.opacity(0.4)))
                            .frame(width: isDragging ? 6 : 4, height: geometry.size.height)
                        
                        // 选中区域 - 透明但可点击，增加可点击区域
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 16, height: geometry.size.height)
                        
                        // 可选：添加视觉指示器，表明可拖动
                        VStack(spacing: 8) {
                            ForEach(0..<5) { _ in
                                Circle()
                                //                                                                     .fill(Color.gray.opacity(0.8))
                                    .fill(Color(light: Color.gray.opacity(0.8), dark: Color.gray.opacity(0.6)))
                                    .frame(width: 3, height: 3)
                            }
                        }
                    }
                    .position(x: geometry.size.width * dividerPosition, y: geometry.size.height / 2)
                    //                                         .shadow(color: Color.black.opacity(0.2), radius: isDragging ? 3 : 1, x: 0, y: 0)
                    .shadow(color: Color(light: Color.black.opacity(0.2), dark: Color.white.opacity(0.1)), radius: isDragging ? 3 : 1, x: 0, y: 0)
                    
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                // 计算新的分割比例，但限制在合理范围内
                                let newPosition = value.location.x / geometry.size.width
                                // 限制分隔栏位置，防止窗口过窄
                                dividerPosition = min(max(newPosition, 0.2), 0.8)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .animation(.interactiveSpring(), value: isDragging)
                }
            }
            .onChange(of: chatViewModel.responseText) { _,newContent in
                // 当AI正在响应时实时提取代码
                if chatViewModel.isLoading {
                    artifactViewModel.extractCodeBlocks(from: newContent)
                }
            }
            // 添加调整光标样式
            .onHover { isHovered in
                //                if artifactViewModel.isActive {
                if artifactViewModel.isActive && artifactViewModel.isPreviewEnabled {
                    // 在分隔栏附近时显示调整光标
                    let mouseLocation = NSEvent.mouseLocation
                    let windowLocation = NSApplication.shared.windows.first?.frame.origin ?? .zero
                    let xInWindow = mouseLocation.x - windowLocation.x
                    
                    let separatorPosition = geometry.size.width * dividerPosition
                    let isNearSeparator = abs(xInWindow - separatorPosition) < 10
                    
                    if isNearSeparator {
                        NSCursor.resizeLeftRight.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
            }
        }
    }
}

#Preview {
    // Create a sample SwiftData container for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatMessage.self, ChatSession.self, configurations: config)
    
    // Create a sample chat session
    let session = ChatSession(
        id: UUID().uuidString,
        title: "Sample Chat",
        messages: [],
        timestamp: Date(),
        username: "Test User",
        userid: UUID().uuidString
    )
    
    // Create some test messages
    let messageContents = [
        "Hello! I'd like to create a simple webpage.",
        "Sure, I can help with that. Here's a simple HTML template to get you started:\n\n```html\n<!DOCTYPE html>\n<html>\n<head>\n    <title>My First Page</title>\n    <style>\n        body {\n            font-family: Arial, sans-serif;\n            margin: 20px;\n            line-height: 1.6;\n        }\n        h1 {\n            color: #0066cc;\n        }\n        .container {\n            max-width: 800px;\n            margin: 0 auto;\n        }\n    </style>\n</head>\n<body>\n    <div class=\"container\">\n        <h1>Welcome to My Website</h1>\n        <p>This is a paragraph of text. You can add more content here.</p>\n    </div>\n</body>\n</html>\n```\n\nYou can copy this code and save it as `index.html` to view it in your browser.",
        "Thanks! Can you add a simple navigation menu to it?",
        "Certainly! Here's the updated HTML with a navigation menu:\n\n```html\n<!DOCTYPE html>\n<html>\n<head>\n    <title>My First Page</title>\n    <style>\n        body {\n            font-family: Arial, sans-serif;\n            margin: 0;\n            padding: 0;\n            line-height: 1.6;\n        }\n        nav {\n            background-color: #333;\n            overflow: hidden;\n        }\n        nav a {\n            float: left;\n            color: white;\n            text-align: center;\n            padding: 14px 16px;\n            text-decoration: none;\n        }\n        nav a:hover {\n            background-color: #ddd;\n            color: black;\n        }\n        .container {\n            max-width: 800px;\n            margin: 0 auto;\n            padding: 20px;\n        }\n    </style>\n</head>\n<body>\n    <nav>\n        <a href=\"#\">Home</a>\n        <a href=\"#\">About</a>\n        <a href=\"#\">Services</a>\n        <a href=\"#\">Contact</a>\n    </nav>\n    <div class=\"container\">\n        <h1>Welcome to My Website</h1>\n        <p>This is a paragraph of text. You can add more content here.</p>\n    </div>\n</body>\n</html>\n```",
        "Could you also make the background color light gray?",
        "Of course! Here's the updated code with a light gray background:\n\n```html\n<!DOCTYPE html>\n<html>\n<head>\n    <title>My First Page</title>\n    <style>\n        body {\n            font-family: Arial, sans-serif;\n            margin: 0;\n            padding: 0;\n            line-height: 1.6;\n            background-color: #f0f0f0;\n        }\n        nav {\n            background-color: #333;\n            overflow: hidden;\n        }\n        nav a {\n            float: left;\n            color: white;\n            text-align: center;\n            padding: 14px 16px;\n            text-decoration: none;\n        }\n        nav a:hover {\n            background-color: #ddd;\n            color: black;\n        }\n        .container {\n            max-width: 800px;\n            margin: 0 auto;\n            padding: 20px;\n            background-color: white;\n            border-radius: 5px;\n            box-shadow: 0 2px 5px rgba(0,0,0,0.1);\n        }\n    </style>\n</head>\n<body>\n    <nav>\n        <a href=\"#\">Home</a>\n        <a href=\"#\">About</a>\n        <a href=\"#\">Services</a>\n        <a href=\"#\">Contact</a>\n    </nav>\n    <div class=\"container\">\n        <h1>Welcome to My Website</h1>\n        <p>This is a paragraph of text. You can add more content here.</p>\n    </div>\n</body>\n</html>\n```"
    ]
    
    // Create alternating messages between user and AI
    for (index, content) in messageContents.enumerated() {
        let character = index % 2 == 0 ? "user" : "ai"
        
        let message = ChatMessage(
            id: UUID().uuidString,
            ssid: session.id,
            character: character,
            chat_title: "Sample Chat",
            chat_content: content,
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: index + 1,
            timestamp: Date().addingTimeInterval(Double(-300 + index * 60)), // 1 minute per message
            username: "Test User",
            userid: UUID().uuidString,
            providerName: "Sample Provider",
            modelName: "Sample Model"
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
    
    // Set the current session
    chatViewModel.currentSession = session
    chatViewModel.chatMessages = messageContents.enumerated().map { index, content in
        let character = index % 2 == 0 ? "user" : "ai"
        
        return ChatMessage(
            id: UUID().uuidString,
            ssid: session.id,
            character: character,
            chat_title: "Sample Chat",
            chat_content: content,
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: index + 1,
            timestamp: Date().addingTimeInterval(Double(-300 + index * 60)),
            username: "Test User",
            userid: UUID().uuidString,
            providerName: "Sample Provider",
            modelName: "Sample Model"
        )
    }
    
    return ChatView()
        .environmentObject(modelSettings)
        .environmentObject(LocalizationManager.shared)
        .environmentObject(chatViewModel)
        .modelContainer(container)
}
