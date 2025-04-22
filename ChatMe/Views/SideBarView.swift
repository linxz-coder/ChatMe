//
//  SideBarView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI
import SwiftData

struct SideBarView: View {
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State var selection: ChatSession?
    @State private var editingSessionId: UUID? = nil
    @State private var editingTitle: String = ""
    @State private var showingTitleEditor = false
    @State private var selectedSession: ChatSession? = nil
    @State private var sessionToDelete: ChatSession? = nil
    @State private var filteredSessions: [ChatSession] = []
    @State private var isSearching: Bool = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack{
            
            //搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.init(top: 0, leading: 6, bottom: 0, trailing: 0))
                TextField(text: $searchText) {
                    LocalizedText(key: "search")
                }
                .textFieldStyle(.plain)
                .onChange(of: searchText) { oldValue, newValue in
                    performSearch(query: newValue)
                }
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        performSearch(query: "")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }
            }
            .textFieldStyle(.plain)
            .padding(.vertical, 8)
            .background(
                Rectangle()
                    .fill((Color(red: 209/255, green: 208/255, blue: 212/255).opacity(0.3)))
            )
            .cornerRadius(10)
            .padding()
            
            List(selection: $selection) {
                
                Section {
                    ForEach(isSearching ? filteredSessions : chatViewModel.sessions.sorted(by: { $0.timestamp < $1.timestamp }))  { session in
                        Label(session.title, systemImage: "figure.american.football")
                            .tag(session)
                        //右键修改标题
                            .contextMenu {
                                Button{
                                    editingTitle = session.title
                                    selectedSession = session
                                    showingTitleEditor = true
                                }label:{
                                    Label("修改标题", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    //删除会话
                                    sessionToDelete = session
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("删除会话", systemImage: "trash")
                                }
                            }.labelStyle(.titleAndIcon) //右键菜单显示图标
                    }
                    if isSearching && filteredSessions.isEmpty {
                        Text("没有找到匹配的会话")
                            .foregroundColor(.gray)
                            .italic()
                    }
                } header: {
                    if isSearching {
                        Text("搜索结果")
                    } else {
                        LocalizedText(key: "conversation")
                    }
                }
                
            }
            .listStyle(.sidebar)
            //选中标题
            .onChange(of: selection) { oldSession, newSession in
                if let newSession = newSession {
                    // 切换到选中的会话
                    chatViewModel.switchSession(to: newSession)
                }
            }
            // 监听当前会话的变化，自动选中新创建的会话
            .onChange(of: chatViewModel.currentSession) { oldSession, newSession in
                selection = newSession
            }
            //修改标题
            .onChange(of: showingTitleEditor) { oldValue, newValue in
                // 如果关闭了编辑器但没有保存，重置标题
                if oldValue && !newValue {
                    if let session = selectedSession {
                        editingTitle = session.title
                    }
                }
            }
            // 初始加载时设置选中的会话为当前会话
            .onAppear {
                selection = chatViewModel.currentSession
                filteredSessions = chatViewModel.sessions
            }
            
            
            Spacer()
            HStack {
                SettingsLink(
                    label: {
                        Image(systemName: "gear")
                    }
                ).buttonStyle(.plain)
                Spacer()
            }.padding()
        }
        .sheet(item: $selectedSession) { session in
            VStack(spacing: 20) {
                Text("修改会话标题")
                    .font(.headline)
                
                TextField("输入新标题", text: $editingTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onAppear {
                        // 确保在视图出现时更新标题
                        editingTitle = session.title
                    }
                
                HStack {
                    Button("取消") {
                        selectedSession = nil
                    }
                    .buttonStyle(.bordered)
                    
                    Button("保存") {
                        chatViewModel.updateSessionTitle(session: session, newTitle: editingTitle)
                        selectedSession = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minWidth: 300, minHeight: 200)
            
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                dismiss()
            }
            Button("删除", role: .destructive) {
                // 执行实际删除操作
                if let session = sessionToDelete {
                    performDeleteSession(session: session)
                }
                
            }
        } message: {
            Text("您确定要删除这个会话吗？此操作无法撤销。")
        }
        
    }
    
    //删除会话
    private func performDeleteSession(session: ChatSession){
        do {
            // 必须获取会话ID作为本地变量才能用Predicate
            let sessionId = session.id
            
            // 使用本地变量在谓词中
            let messagesQuery = FetchDescriptor<ChatMessage>(
                predicate: #Predicate<ChatMessage> { message in
                    message.ssid == sessionId
                }
            )
            
            let messages = try context.fetch(messagesQuery)
            
            print("找到 \(messages.count) 条与会话 \(session.id) 相关的消息")
            
            // 删除所有相关消息
            for message in messages {
                context.delete(message)
            }
            
            // 删除会话本身
            let sessionQuery = FetchDescriptor<ChatSession>(
                predicate: #Predicate<ChatSession> { chatSession in
                    chatSession.id == sessionId
                }
            )
            
            let sessionsToDelete = try context.fetch(sessionQuery)
            
            for theSession in sessionsToDelete{
                context.delete(theSession)
            }
            
            // 保存变更
            try context.save()
            
            // 更新内存中的数据
            chatViewModel.chatMessages.removeAll(where: {$0.ssid == session.id})
            chatViewModel.sessions.removeAll(where: {$0.id == session.id})
            
            print("会话及相关消息已从数据库中成功删除")
        } catch {
            print("删除数据时出错: \(error)")
        }
    }
    
    
    // 搜索功能实现
    private func performSearch(query: String) {
        if query.isEmpty {
            isSearching = false
            return
        }
        
        isSearching = true
        let lowercaseQuery = query.lowercased()
        
        filteredSessions = chatViewModel.sessions.filter { session in
            // 1. 检查标题是否包含搜索词
            let titleMatch = session.title.lowercased().contains(lowercaseQuery)
            
            // 2. 加载会话中的消息并检查内容是否包含搜索词
            var contentMatch = false
            
            // 如果当前会话就是我们正在搜索的会话，直接检查已加载的消息
            if chatViewModel.currentSession!.id == session.id {
                contentMatch = chatViewModel.chatMessages.contains(where: {
                    $0.chat_content.lowercased().contains(lowercaseQuery)
                })
            } else {
                // 这里我们不希望在UI线程中阻塞搜索，所以这只是初步过滤
                // 后面会有更详细的内容搜索
                contentMatch = false
            }
            
            return titleMatch || contentMatch
        }
        
        // 对于标题中没有匹配的会话，异步检查它们的内容
        for session in chatViewModel.sessions {
            if !filteredSessions.contains(where: { $0.id == session.id }) {
                chatViewModel.searchMessagesContent(for: session.id, query: lowercaseQuery) { result in
                    if result {
                        DispatchQueue.main.async {
                            // 如果找到匹配，将该会话添加到过滤结果中
                            if !self.filteredSessions.contains(where: { $0.id == session.id }) {
                                self.filteredSessions.append(session)
                            }
                        }
                    }
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
    
    return SideBarView()
        .environmentObject(modelSettings)
        .environmentObject(LocalizationManager.shared)
        .environmentObject(chatViewModel)
        .modelContainer(container)
}
