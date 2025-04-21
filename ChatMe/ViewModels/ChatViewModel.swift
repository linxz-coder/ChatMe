import Foundation
import SwiftData
import SwiftUI

class ChatViewModel: NSObject, ObservableObject, URLSessionDataDelegate {
    
    @Published var chatMessages: [ChatMessage] = []
    @Published var currentSession: ChatSession?
    @Published var sessions: [ChatSession] = []
    @Published var responseText = ""
    @Published var thinkingText = ""
    @Published var errorMessage = ""
    @Published var isLoading: Bool = false
    @Published var isAnswering: Bool = false
    @Published var searchReferences: [SearchReference] = []  // 存储搜索引用
    var modelSettings: ModelSettingsData
    private var activeTask: URLSessionDataTask?
    private var session: URLSession!
    
    // 添加用于批量更新的属性-thinking
    private var pendingThinkingText = ""
    private var thinkingUpdateTimer: Timer?
    private var thinkingUpdateQueue = DispatchQueue(label: "com.chatme.thinkingupdate")
    private var lastThinkingUpdate = Date()
    private var thinkingBuffer = ""
    
    private var modelContext: ModelContext
    
    // 为了支持在视图加载后更新ModelContext
    func updateModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // 默认用户信息
    let defaultUsername = "lxz"
    let defaultUserId = "b5224a80-56ab-42ed-8cf4-394dc9728bbc"
    let defaultTitle = "默认聊天标题"
    
    
    //初始化设置
    init(modelSettings: ModelSettingsData, modelContext: ModelContext) {
        self.modelSettings = modelSettings
        self.modelContext = modelContext
        
        super.init()
        
        //加载已存在的会话
        loadSessions()
    }
    
    // 加载会话列表
    func loadSessions() {
        do {
            let descriptor = FetchDescriptor<ChatSession>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            let loadedSessions = try modelContext.fetch(descriptor)
            
            DispatchQueue.main.async {
                if loadedSessions.isEmpty {
                    //无内容
                    print("nothing")
                } else {
                    self.sessions = loadedSessions
                    // 如果有会话，默认使用第一个会话
                    self.switchSession(to: self.sessions[0])
                }
            }
        } catch {
            print("加载会话失败: \(error.localizedDescription)")
            self.errorMessage = "加载会话失败: \(error.localizedDescription)"
        }
        
    }
    
    // 切换到指定会话
    func switchSession(to session: ChatSession) {
        currentSession = session
        loadMessages(for: session.id)
    }
    
    // 加载会话的消息
    func loadMessages(for sessionId: String) {
        isLoading = true
        chatMessages = []
        
        do {
            let descriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.ssid == sessionId },
                sortBy: [SortDescriptor(\.sequence)]
            )
            let messages = try modelContext.fetch(descriptor)
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.chatMessages = messages
            }
        } catch {
            print("加载消息失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "加载消息失败: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // 添加用户消息
    func addUserMessage(_ content: String) {
        //无内容
    }
    
    //更改聊天标题
    func updateSessionTitle(session: ChatSession, newTitle: String) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].title = newTitle
            
            if currentSession!.id == session.id {
                currentSession!.title = newTitle
            }
            
            //更新chatMessages
            for (index, message) in self.chatMessages.enumerated() {
                if message.ssid == session.id {
                    chatMessages[index].chat_title = newTitle
                }
            }
            
            // 更新数据库中的会话标题
            do {
                try modelContext.save()
                print("会话标题已更新")
            } catch {
                print("更新会话标题失败: \(error.localizedDescription)")
            }
        }
    }
    
    
    // 创建新会话
    func createNewSession() {
        //无内容
        
    }
    
    // 搜索会话消息内容
    func searchMessagesContent(for sessionId: String, query: String, completion: @escaping (Bool) -> Void) {
        // 如果是当前会话，直接在已加载的消息中搜索
        if sessionId == currentSession!.id {
            let hasMatch = chatMessages.contains { message in
                message.chat_content.lowercased().contains(query.lowercased())
            }
            completion(hasMatch)
            return
        }
        
        // 如果不是当前会话，需要从数据库中加载并搜索
        do {
            let predicate = #Predicate<ChatMessage> { message in
                message.ssid == sessionId && message.chat_content.localizedStandardContains(query)
            }
            let descriptor = FetchDescriptor<ChatMessage>(predicate: predicate)
            let matches = try modelContext.fetch(descriptor)
            completion(!matches.isEmpty)
        } catch {
            print("搜索消息失败: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // 在会话列表和消息内容中搜索
    func searchAllContent(query: String, completion: @escaping ([ChatSession]) -> Void) {
        if query.isEmpty {
            completion(sessions)
            return
        }
        
        let lowercaseQuery = query.lowercased()
        
        // 首先，找出标题中包含查询词的会话
        var matchingSessions = sessions.filter { session in
            session.title.lowercased().contains(lowercaseQuery)
        }
        
        // 创建一个调度组，用于等待所有搜索完成
        let group = DispatchGroup()
        
        // 对于每个未匹配的会话，搜索它们的消息内容
        for session in sessions {
            if !matchingSessions.contains(where: { $0.id == session.id }) {
                group.enter()
                
                searchMessagesContent(for: session.id, query: lowercaseQuery) { hasMatch in
                    if hasMatch {
                        DispatchQueue.main.async {
                            matchingSessions.append(session)
                        }
                    }
                    group.leave()
                }
            }
        }
        
        // 当所有搜索完成时，返回结果
        group.notify(queue: .main) {
            completion(matchingSessions)
        }
    }
    
    // 删除会话
    //    func deleteSession(session: ChatSession) {
    //        // 删除所有关联的消息
    //        do {
    //            // 简单方式
    //            let predicate = #Predicate<ChatMessage> { message in
    //                message.ssid == session.id
    //            }
    //
    //            // 创建 FetchDescriptor
    //            let descriptor = FetchDescriptor<ChatMessage>(
    //                predicate: predicate,
    //                sortBy: [SortDescriptor(\.sequence)]
    //            )
    //
    //            // 执行查询
    //            let messages = try modelContext.fetch(descriptor)
    //
    //            // 删除消息
    //            for message in messages {
    //                modelContext.delete(message)
    //            }
    //
    //            // 删除会话
    //            modelContext.delete(session)
    //
    //            try modelContext.save()
    //
    //            // 更新会话列表
    //            DispatchQueue.main.async {
    //                self.sessions.removeAll(where: { $0.id == session.id })
    //
    //                // 如果删除的是当前会话，创建新会话或切换到其他会话
    //                if self.currentSession.id == session.id {
    //                    if let firstSession = self.sessions.first {
    //                        self.switchSession(to: firstSession)
    //                    } else {
    //                        self.createNewSession()
    //                    }
    //                }
    //            }
    //        } catch {
    //            print("删除会话失败: \(error.localizedDescription)")
    //        }
    //    }
    //
    
    //AI回复
    func streamAnswer(requestURL: String, apiKey: String, requestModel: String, systemMessage: String = "You are a helpful assistant", userMessage: String, userMessageWithoutFile: String = "", enableWebSearch: Bool = false) {
        
        var chatHistoryString = ""
        
        // 检查当前选择的模型类型
        if let selectedModel = modelSettings.selectedModel, selectedModel.modelType == .image {
            // 对于图像模型，调用generateImage
            generateImage(prompt: userMessage)
            return
        }
        
        // 首先获取该会话的历史聊天记录
        do {
            
            let messages = currentSession!.messages
            
            // 格式化聊天历史记录
            var formattedHistory = ""
            // 只取最近的10条消息
            let recentMessages = messages.sorted(by: { $0.sequence < $1.sequence }).suffix(10)
            
            for message in recentMessages {
                let role = message.character == "user" ? "用户" : "AI"
                formattedHistory += "\(role): \(message.chat_content)\n"
            }
            
            chatHistoryString = formattedHistory
            
            // 添加用户消息到聊天记录
            let messageToAdd = userMessageWithoutFile.isEmpty ? userMessage : userMessageWithoutFile
            self.addUserMessage(messageToAdd)
            
            // 继续处理，将历史记录传入进行API调用
            DispatchQueue.main.async {
                self.continueStreamAnswerWithHistory(
                    requestURL: requestURL,
                    apiKey: apiKey,
                    requestModel: requestModel,
                    systemMessage: systemMessage,
                    userMessage: userMessage,
                    chatHistory: chatHistoryString,
                    enableWebSearch: enableWebSearch
                )
            }
        } catch {
            print("获取聊天记录失败: \(error.localizedDescription)")
            // 出错时也添加用户消息并继续
            let messageToAdd = userMessageWithoutFile.isEmpty ? userMessage : userMessageWithoutFile
            self.addUserMessage(messageToAdd)
            
            self.continueStreamAnswerWithHistory(
                requestURL: requestURL,
                apiKey: apiKey,
                requestModel: requestModel,
                systemMessage: systemMessage,
                userMessage: userMessage,
                chatHistory: "",
                enableWebSearch: enableWebSearch
            )
        }
    }
    
    // 添加同步方法，确保chatMessages和数据库中的消息保持一致
    func synchronizeMessages(for sessionId: String) {
        do {
            let descriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.ssid == sessionId },
                sortBy: [SortDescriptor(\.sequence)]
            )
            chatMessages = try modelContext.fetch(descriptor)
        } catch {
            print("同步消息失败: \(error.localizedDescription)")
        }
    }
    
    
    private func continueStreamAnswerWithHistory(requestURL: String, apiKey: String, requestModel: String, systemMessage: String, userMessage: String, chatHistory: String, enableWebSearch: Bool = false) {
        
        // 同步确保chatMessages是最新的
        synchronizeMessages(for: self.currentSession!.id)
        
        // 预先创建一个空的AI回复消息
        let aiMessageId = UUID().uuidString
        let aiMessage = ChatMessage(
            id: aiMessageId,
            ssid: self.currentSession!.id,
            character: "ai",
            chat_title: self.currentSession!.title,
            chat_content: "",
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: self.chatMessages.isEmpty ? 0 : self.chatMessages.last!.sequence + 1,
            timestamp: Date(),
            username: self.defaultUsername,
            userid: self.defaultUserId,
            providerName: self.modelSettings.selectedModel?.providerName ?? "",
            modelName: self.modelSettings.selectedModel?.name ?? ""
        )
        
        DispatchQueue.main.async {
            self.responseText = ""
            self.errorMessage = ""
            self.thinkingText = ""
            self.searchReferences = []
            self.isLoading = true
            self.isAnswering = true
            self.chatMessages.append(aiMessage)
            
            // 添加到数据库
            self.modelContext.insert(aiMessage)
            
            // 添加到当前会话
            self.currentSession!.messages.append(aiMessage)
            
            // 保存更改
            do {
                try self.modelContext.save()
            } catch {
                print("保存AI消息失败: \(error.localizedDescription)")
            }
        }
        
        guard let url = URL(string: requestURL) else { return }
        
        // 检查是否需要使用代理
        let providerName = getProviderNameFromURL(requestURL)
        let configuration = URLSessionConfiguration.default
        
        // 如果是Anthropic或OpenAI，并且有代理设置，则配置代理
        if (providerName == "Anthropic" || providerName == "OpenAI"),
           let proxyURL = URL(string: modelSettings.proxyURL), !modelSettings.proxyURL.isEmpty {
            let host = proxyURL.host ?? "127.0.0.1"
            let port = proxyURL.port ?? 1087
            
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable: true,
                kCFNetworkProxiesHTTPProxy: host,
                kCFNetworkProxiesHTTPPort: port,
                kCFNetworkProxiesHTTPSEnable: true,
                kCFNetworkProxiesHTTPSProxy: host,
                kCFNetworkProxiesHTTPSPort: port
            ]
            //            print("使用代理: \(host):\(port) 用于 \(providerName)")
        }
        
        // 为每个请求创建新的URLSession
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        
        
        let isThinkingMode = requestURL.contains("anthropic.com") &&
        modelSettings.selectedModel?.isThinkingEnabled == true
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 检测是否为Anthropic API并特殊处理授权头
        if providerName == "Anthropic" {
            // Anthropic API要求特定的Authorization头格式
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            // 其他API使用标准Bearer格式
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        
        
        // 构建请求体
        let messages: [[String: String]]
        
        if providerName == "Anthropic" {
            messages = [
                //                ["role": "user", "content": userMessage],
                ["role": "user", "content": "之前的对话:\n\(chatHistory)\n\n对方新提出的问题: \(userMessage)"]
                
            ]
        }else{
            messages = [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": "之前的对话:\n\(chatHistory)\n\n对方新提出的问题: \(userMessage)"]
            ]
        }
        
        print("之前的对话:\n\(chatHistory)\n\n对方新提出的问题: \(userMessage)")
        
        
        var postData: [String: Any]
        
        if providerName == "Anthropic" {
            postData = [
                "model": requestModel,
                "messages": messages,
                "max_tokens": 20000,
                "system":"总是用中文回答问题，如果涉及修改代码，总是用diff格式输出。",
                "stream": true  // 确保stream设置为true
            ]
            
            // 如果是思考模式，添加thinking参数
            if isThinkingMode {
                postData["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": 16000
                ]
                //print("启用思考模式，budget_tokens: 16000")
            }
        } else if providerName == "腾讯混元" && enableWebSearch {
            // 为腾讯混元启用联网搜索功能
            postData = [
                "model": requestModel,
                "messages": messages,
                "stream": true,
                "enableEnhancement": true,
                "citation": true,
                "search_info": true
            ]
        }else{
            postData = [
                "model": requestModel,
                "messages": messages,
                "stream": true  // 确保stream设置为true
            ]
        }
        
        
        
        
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postData) else {
            print("Failed to convert data to JSON")
            return
        }
        
        request.httpBody = jsonData
        
        let task = self.session.dataTask(with: request)
        
        print("开始发送请求...")
        self.activeTask = task
        task.resume()
        //    }
        //    }
    }
    
    
    // 从URL识别API提供商
    private func getProviderNameFromURL(_ urlString: String) -> String {
        if urlString.contains("anthropic.com") {
            return "Anthropic"
        } else if urlString.contains("openai.com") {
            return "OpenAI"
        } else if urlString.contains("deepseek.com") {
            return "DeepSeek"
        } else if urlString.contains("dashscope.aliyuncs.com") {
            return "通义千问"
        } else if urlString.contains("hunyuan.cloud.tencent.com") {
            return "腾讯混元"
        } else if urlString.contains("moonshot.cn") {
            return "月之暗面"
        } else if urlString.contains("bigmodel.cn") {
            return "智谱清言"
        } else if urlString.contains("googleapis.com") {
            return "Google"
        }
        return "Unknown"
    }
    
    // 接收到数据块时调用
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // 转换数据为字符串
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        
        // 打印原始返回数据用于调试
        // print("收到数据: \(dataString)")
        
        
        
        
        //检查是否为错误相应
        if let httpResponse = dataTask.response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            // 尝试解析错误信息
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var detailedError = "API错误: "
                
                // 尝试提取错误详情
                if let error = errorJson["error"] as? [String: Any] {
                    if let message = error["message"] as? String {
                        detailedError += message
                    } else if let message = error["error"] as? String {
                        detailedError += message
                    } else {
                        detailedError += (error.description)
                    }
                } else if let message = errorJson["message"] as? String {
                    detailedError += message
                } else {
                    detailedError += dataString
                }
                
                print("错误详情: \(detailedError)")
                DispatchQueue.main.async {
                    self.errorMessage = detailedError
                }
                return
            }
        }
        
        let isAnthropicAPI = dataTask.currentRequest?.url?.absoluteString.contains("anthropic.com") ?? false
        let isTencentAPI = dataTask.currentRequest?.url?.absoluteString.contains("hunyuan.cloud.tencent.com") ?? false
        
        // 每个块之间用换行符分隔
        let lines = dataString.split(separator: "\n")
        
        for line in lines {
            //忽略空行
            if line.isEmpty { continue }
            
            
            if isAnthropicAPI {
                // 检查是否是数据行
                if !line.hasPrefix("data: ") { continue }
                let jsonString = line.dropFirst(6) // 删除"data: "前缀
                
                // 忽略 [DONE] 消息
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    continue
                }
                
                // 尝试解析JSON
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                
                // 打印完整的JSON响应，以便查看所有字段
                //                print("Anthropic 返回JSON: \(json)")
                
                // 处理错误响应
                if let type = json["type"] as? String, type == "error" {
                    // 提取错误信息
                    var errorMessage = "Anthropic API 错误"
                    
                    if let error = json["error"] as? [String: Any] {
                        if let message = error["message"] as? String {
                            errorMessage += ": " + message
                        }
                        
                        if let type = error["type"] as? String {
                            errorMessage += " (类型: \(type))"
                        }
                        
                        if let code = error["code"] as? String {
                            errorMessage += " [代码: \(code)]"
                        }
                    }
                    
                    print("完整错误信息: \(errorMessage)")
                    
                    // 更新UI显示错误信息
                    DispatchQueue.main.async {
                        self.errorMessage = errorMessage
                        self.isLoading = false
                    }
                    
                    continue
                }
                
                if let type = json["type"] as? String {
                    switch type {
                    case "content_block_delta":
                        if let delta = json["delta"] as? [String: Any],
                           let deltaType = delta["type"] as? String {
                            
                            // 处理思考文本
                            if deltaType == "thinking_delta", let thinking = delta["thinking"] as? String {
                                //                                print("收到思考内容: \(thinking)")
                                //                                DispatchQueue.main.async {
                                //                                    self.thinkingText += thinking
                                //                                }
                                // 累积思考内容到缓冲区
                                self.thinkingBuffer += thinking
                                
                                // 检查是否应该更新UI
                                let now = Date()
                                if now.timeIntervalSince(self.lastThinkingUpdate) > 0.5 { // 500毫秒批量更新
                                    self.flushThinkingBuffer()
                                }
                            }
                            // 处理普通文本
                            else if deltaType == "text_delta", let text = delta["text"] as? String {
                                DispatchQueue.main.async {
                                    self.responseText += text
                                }
                            }
                        }
                    case "message_start", "content_block_start", "content_block_stop", "message_delta", "message_stop":
                        // 记录事件类型但不需要特殊处理
                        print("事件类型: \(type)")
                    default:
                        print("未知事件类型: \(type)")
                    }
                }
                
            } else if isTencentAPI {
                guard line.hasPrefix("data: ") else { continue }
                
                // 提取JSON部分
                let jsonString = line.dropFirst(6) // 删除"data: "前缀
                
                // 忽略[DONE]消息
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    continue
                }
                
                // 解析JSON
                // 打印调试信息，查看收到的数据格式
                print("腾讯混元原始数据: \(jsonString)")
                
                
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    // 处理常规输出
                    //                               if let choices = json["Choices"] as? [[String: Any]],
                    //                                  let firstChoice = choices.first,
                    //                                  let delta = firstChoice["Delta"] as? [String: Any],
                    //                                  let content = delta["Content"] as? String {
                    
                    // 检查不同格式的响应结构
                    if let choices = json["choices"] as? [[String: Any]] {
                        if let firstChoice = choices.first {
                            // 尝试解析 Delta 格式
                            if let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                // 更新UI
                                DispatchQueue.main.async {
                                    print("收到腾讯混元内容: \(content)")
                                    self.responseText += content
                                }
                            }
                            // 尝试解析非 Delta 格式
                            else if let content = firstChoice["content"] as? String {
                                DispatchQueue.main.async {
                                    print("收到腾讯混元内容(非Delta): \(content)")
                                    self.responseText += content
                                }
                            }
                        }
                    }
                    
                    //                                   // 更新UI
                    //                                   DispatchQueue.main.async {
                    //                                       self.responseText += content
                    //                                   }
                    
                    
                    // 处理搜索引用
                    if let searchInfo = json["search_info"] as? [String: Any],
                       let searchResults = searchInfo["search_results"] as? [[String: Any]] {
                        
                        print("收到搜索引用数据: \(searchResults.count) 条")
                        let references = searchResults.compactMap { result -> SearchReference? in
                            guard let index = result["index"] as? Int,
                                  let title = result["title"] as? String,
                                  let url = result["url"] as? String else {
                                print("引用数据格式不符: \(result)")
                                return nil
                            }
                            
                            return SearchReference(index: index, title: title, url: url)
                        }
                        
                        // 更新引用数据
                        if !references.isEmpty {
                            DispatchQueue.main.async {
                                print("添加 \(references.count) 条引用")
                                // 只添加新的引用
                                for reference in references {
                                    if !self.searchReferences.contains(where: { $0.index == reference.index }) {
                                        self.searchReferences.append(reference)
                                    }
                                }
                            }
                        }
                    }
                }
                
                
            }else{
                guard line.hasPrefix("data: ") else { continue }
                
                
                // 提取JSON部分
                let jsonString = line.dropFirst(6) // 删除"data: "前缀
                
                // 忽略[DONE]消息
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    continue
                }
                
                // 解析JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    // 更新UI
                    DispatchQueue.main.async {
                        self.responseText += content
                    }
                }
            }
            
            
        }
    }
    
    // 添加新方法来刷新思考内容缓冲区
    private func flushThinkingBuffer() {
        guard !thinkingBuffer.isEmpty else { return }
        
        let contentToAdd = thinkingBuffer
        thinkingBuffer = ""
        self.lastThinkingUpdate = Date()
        
        DispatchQueue.main.async {
            self.thinkingText += contentToAdd
        }
    }
    
    // 接收到响应时调用
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        //        print("收到响应头，状态码: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        
        // 确保刷新任何剩余的思考内容
        if !thinkingBuffer.isEmpty {
            flushThinkingBuffer()
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            print("收到响应头，状态码: \(statusCode)")
            
            // 对于错误状态码，将其记录到errorMessage中
            if statusCode >= 400 {
                DispatchQueue.main.async {
                    self.errorMessage = "错误状态码: \(statusCode)"
                    self.isLoading = false
                }
            }
        }
        
        completionHandler(.allow)
    }
    
    // 任务完成时调用
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            //            print("任务出错: \(error.localizedDescription)")
            // 检查错误是否是用户取消操作
            let nsError = error as NSError
            let isCancelled = nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
            
            if isCancelled {
                print("用户手动停止了AI响应")
                
                // 即使是取消操作，也保存当前接收到的响应
                DispatchQueue.main.async {
                    self.saveCurrentResponse()
                    self.isAnswering = false
                }
            } else {
                print("任务出错: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } else {
            print("任务成功完成")
            // 当任务完成时，将当前的responseText添加为AI回复
            DispatchQueue.main.async {
                self.saveCurrentResponse()
                self.isLoading = false
                self.isAnswering = false
            }
        }
    }
    
    private func saveCurrentResponse(){
        if !self.responseText.isEmpty {
            
            
            // 更新最后一条AI消息的内容
            if let lastIndex = self.chatMessages.lastIndex(where: { $0.character == "ai" }) {
                let updatedMessage = self.chatMessages[lastIndex]
                
                // 构建最终的回复内容，包括引用
                var finalContent = self.responseText
                
                // 如果有搜索引用，添加到内容末尾
                if !self.searchReferences.isEmpty {
                    finalContent += "\n\n---\n\n"
                    finalContent += "\n\n**参考资料：**\n"
                    for reference in self.searchReferences.sorted(by: { $0.index < $1.index }) {
                        finalContent += "\n[\(reference.index)] \(reference.title): \(reference.url)\n"
                    }
                }
                
                
                //                updatedMessage.chat_content = self.responseText
                updatedMessage.chat_content = finalContent
                
                // 保存思考内容到消息的附加属性中
                if !self.thinkingText.isEmpty {
                    updatedMessage.thinking_content = self.thinkingText
                }
                
                // 保存当前模型信息到消息中
                if let currentModel = self.modelSettings.selectedModel {
                    updatedMessage.providerName = currentModel.providerName
                    updatedMessage.modelName = currentModel.name
                }
                
                self.chatMessages[lastIndex] = updatedMessage
                //                        print(self.chatMessages) //打印聊天数据
                
                // 保存AI回复到数据库
                // 保存到数据库
                do {
                    try self.modelContext.save()
                    print("AI回复已保存")
                    print("添加AI回复后")
                    for message in self.chatMessages {
                        print("ID: \(message.id), SSID: \(message.ssid), 角色: \(message.character), 内容: \(message.chat_content)")
                    }
                } catch {
                    print("保存AI回复失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 增加生成图片的方法
    func generateImage(prompt: String) {
        // 添加用户消息到聊天记录
        addUserMessage(prompt)
        
        // 预先创建一个空的AI回复消息，用于实时更新
        let aiMessage = ChatMessage(
            id: UUID().uuidString,
            ssid: self.currentSession!.id,
            character: "ai",
            chat_title: self.currentSession!.title,
            chat_content: "生成图片中...",
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: self.chatMessages.isEmpty ? 0 : self.chatMessages.last!.sequence + 1,
            timestamp: Date(),
            username: self.defaultUsername,
            userid: self.defaultUserId,
            providerName: self.modelSettings.selectedModel?.providerName ?? "",
            modelName: self.modelSettings.selectedModel?.name ?? ""
        )
        
        DispatchQueue.main.async {
            self.responseText = ""
            self.errorMessage = ""
            self.thinkingText = ""
            self.isLoading = true
            self.chatMessages.append(aiMessage)
            
            // 添加到数据库
            self.modelContext.insert(aiMessage)
            self.currentSession!.messages.append(aiMessage)
            try? self.modelContext.save()
        }
        
        guard let selectedModel = modelSettings.selectedModel,
              let url = URL(string: selectedModel.baseUrl) else {
            DispatchQueue.main.async {
                self.errorMessage = "模型配置错误"
                self.isLoading = false
            }
            return
        }
        
        // 配置请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(selectedModel.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 打印所有请求头信息（但遮盖API密钥部分内容）
        print("====== 请求信息 ======")
        print("URL: \(request.url?.absoluteString ?? "未知")")
        print("HTTP方法: \(request.httpMethod ?? "未知")")
        print("请求头:")
        if let allHTTPHeaderFields = request.allHTTPHeaderFields {
            for (key, value) in allHTTPHeaderFields {
                if key.lowercased() == "authorization" {
                    // 只显示API密钥的前10个字符和后4个字符，中间用***替代
                    let apiKeyPrefix = String(value.prefix(15))
                    let apiKeySuffix = value.count > 4 ? String(value.suffix(4)) : ""
                    print("  \(key): \(apiKeyPrefix)***\(apiKeySuffix)")
                } else {
                    print("  \(key): \(value)")
                }
            }
        }
        
        // 构建请求体
        let requestData: [String: Any] = [
            "model": selectedModel.name.isEmpty ? "dall-e-3" : selectedModel.name,
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
        ]
        
        
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            DispatchQueue.main.async {
                self.errorMessage = "生成请求数据失败"
                self.isLoading = false
            }
            return
        }
        
        request.httpBody = jsonData
        
        // 创建会话配置
        let configuration = URLSessionConfiguration.default
        if shouldUseProxy() {
            if let proxyConfig = modelSettings.getProxyConfiguration() {
                configuration.connectionProxyDictionary = proxyConfig.connectionProxyDictionary
            }
        }
        
        // 创建会话并发送请求
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            
            // 清除活跃任务引用
            self?.activeTask = nil
            
            guard let self = self else { return }
            
            
            
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "请求失败: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "没有返回数据"
                }
                return
            }
            
            // 解析响应JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [[String: Any]],
                   let firstImage = data.first,
                   let imageUrl = firstImage["url"] as? String {
                    
                    // 更新AI消息
                    DispatchQueue.main.async {
                        if let lastIndex = self.chatMessages.lastIndex(where: { $0.character == "ai" }) {
                            var updatedMessage = self.chatMessages[lastIndex]
                            updatedMessage.chat_content = "图片已生成:"
                            updatedMessage.imageUrl = imageUrl
                            self.chatMessages[lastIndex] = updatedMessage
                            
                            // 保存到数据库
                            do {
                                try self.modelContext.save()
                                print("AI图片已保存")
                            } catch {
                                print("保存AI图片消息失败: \(error.localizedDescription)")
                            }
                        }
                    }
                } else if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let error = errorJson["error"] as? [String: Any]{
                        if let message = error["message"] as? String {
                            DispatchQueue.main.async {
                                self.errorMessage = "API错误: \(message)"
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "无法解析API响应"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "解析响应失败: \(error.localizedDescription)"
                }
            }
        }
        
        task.resume()
        self.activeTask = task
    }
    
    // 判断是否需要使用代理
    func shouldUseProxy() -> Bool {
        guard let model = modelSettings.selectedModel else { return false }
        return model.providerName == "Anthropic" || model.providerName == "OpenAI" || model.providerName == "DALL-E-3"
    }
    
    // 停止流式响应的方法
    func stopStreamResponse() {
        
        // 确保刷新任何剩余的思考内容
        if !thinkingBuffer.isEmpty {
            flushThinkingBuffer()
        }
        
        // 在取消任务前保存当前收到的响应
        DispatchQueue.main.async {
            self.saveCurrentResponse()
            // 清空临时响应文本，避免重复显示
            self.responseText = ""
            self.thinkingText = ""
            self.isLoading = false
            print("用户手动停止了AI响应")
        }
        
        // 取消当前活跃的数据任务
        if let task = self.activeTask {
            task.cancel()
            self.activeTask = nil
            
            // 更新UI状态
            //                DispatchQueue.main.async {
            //                    self.isLoading = false
            //                    print("用户手动停止了AI响应")
            //                }
        }
    }
    
}

// ChatViewModel的扩展，添加文件处理相关功能
extension ChatViewModel {
    
    // 处理智谱AI的文件请求
    func handleFileRequest(fileId: String, prompt: String) {
        // 设置加载状态
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // 获取当前选中的模型或默认模型
        let apiKey = modelSettings.selectedModel?.apiKey ?? modelSettings.apiKey
        let model = ((modelSettings.selectedModel?.name.isEmpty) != nil) ?
        "glm-4-long" : modelSettings.selectedModel?.name ?? "glm-4-long"
        
        // 首先获取文件内容
        FileUploadManager.shared.getFileContent(fileId: fileId, apiKey: apiKey) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let content):
                // 构建请求消息
                var messageContent = prompt
                if !messageContent.isEmpty {
                    messageContent += "\n\n"
                }
                messageContent += "文件内容：\n\(content)"
                
                // 添加用户消息
                self.addUserMessage(prompt.isEmpty ? "请分析上传的文件" : prompt)
                
                // 使用文件内容创建流式响应
                self.streamAnswerWithFileContent(
                    content: messageContent,
                    model: model,
                    apiKey: apiKey
                )
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "获取文件内容失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // 使用文件内容创建流式响应
    private func streamAnswerWithFileContent(content: String, model: String, apiKey: String) {
        // 检查API密钥是否存在
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "API密钥未设置"
                self.isLoading = false
            }
            return
        }
        
        
        // 预先创建一个空的AI回复消息，用于实时更新
        let aiMessage = ChatMessage(
            id: UUID().uuidString,
            ssid: self.currentSession!.id,
            character: "ai",
            chat_title: self.currentSession!.title,
            chat_content: "",
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: self.chatMessages.isEmpty ? 0 : self.chatMessages.last!.sequence + 1,
            timestamp: Date(),
            username: self.defaultUsername,
            userid: self.defaultUserId,
            providerName: self.modelSettings.selectedModel?.providerName ?? "",
            modelName: self.modelSettings.selectedModel?.name ?? ""
        )
        
        DispatchQueue.main.async {
            self.responseText = ""
            self.errorMessage = ""
            self.thinkingText = ""
            self.isLoading = true
            self.chatMessages.append(aiMessage)
            
            // 添加到数据库
            self.modelContext.insert(aiMessage)
            self.currentSession!.messages.append(aiMessage)
            try? self.modelContext.save()
        }
        
        // 创建请求URL
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions") else {
            DispatchQueue.main.async {
                self.errorMessage = "无效的API URL"
                self.isLoading = false
            }
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": content]
            ],
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 32000
        ]
        
        // 将请求体转换为JSON数据
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            DispatchQueue.main.async {
                self.errorMessage = "创建请求数据失败"
                self.isLoading = false
            }
            return
        }
        
        request.httpBody = jsonData
        
        // 创建URL会话
        let configuration = URLSessionConfiguration.default
        if shouldUseProxy() {
            if let proxyConfig = modelSettings.getProxyConfiguration() {
                configuration.connectionProxyDictionary = proxyConfig.connectionProxyDictionary
            }
        }
        
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        
        // 发送请求
        let task = session.dataTask(with: request)
        task.resume()
    }
    
    // 添加多个文件并处理
    func processMultipleFiles(files: [UploadedFile], prompt: String) {
        // 设置加载状态
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // 获取当前选中的模型或默认模型
        let apiKey = modelSettings.selectedModel?.apiKey ?? modelSettings.apiKey
        
        // 需要处理的文件数量
        var remainingFiles = files.count
        var fileContents: [String] = []
        
        // 获取每个文件的内容
        for file in files {
            if let fileId = file.fileId {
                FileUploadManager.shared.getFileContent(fileId: fileId, apiKey: apiKey) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let content):
                        fileContents.append("文件 '\(file.name)' 内容：\n\(content)\n\n")
                    case .failure(let error):
                        print("获取文件内容失败: \(error.localizedDescription)")
                    }
                    
                    remainingFiles -= 1
                    
                    // 当所有文件处理完毕，发送请求
                    if remainingFiles == 0 {
                        // 构建请求消息
                        var messageContent = prompt
                        if !messageContent.isEmpty && !fileContents.isEmpty {
                            messageContent += "\n\n"
                        }
                        
                        // 添加所有文件内容
                        messageContent += fileContents.joined()
                        
                        // 添加用户消息
                        self.addUserMessage(prompt.isEmpty ? "请分析上传的\(files.count)个文件" : prompt)
                        
                        // 获取当前选中的模型
                        let model = ((self.modelSettings.selectedModel?.name.isEmpty) != nil) ?
                        "glm-4-long" : self.modelSettings.selectedModel?.name ?? "glm-4-long"
                        
                        // 使用文件内容创建流式响应
                        self.streamAnswerWithFileContent(
                            content: messageContent,
                            model: model,
                            apiKey: apiKey
                        )
                    }
                }
            } else {
                remainingFiles -= 1
                
                // 当所有文件处理完毕，检查是否需要发送请求
                if remainingFiles == 0 && !fileContents.isEmpty {
                    // 构建请求消息
                    var messageContent = prompt
                    if !messageContent.isEmpty && !fileContents.isEmpty {
                        messageContent += "\n\n"
                    }
                    
                    // 添加所有文件内容
                    messageContent += fileContents.joined()
                    
                    // 添加用户消息
                    self.addUserMessage(prompt.isEmpty ? "请分析上传的文件" : prompt)
                    
                    // 获取当前选中的模型
                    let model = ((self.modelSettings.selectedModel?.name.isEmpty) != nil) ?
                    "glm-4-long" : self.modelSettings.selectedModel?.name ?? "glm-4-long"
                    
                    // 使用文件内容创建流式响应
                    self.streamAnswerWithFileContent(
                        content: messageContent,
                        model: model,
                        apiKey: apiKey
                    )
                } else if remainingFiles == 0 {
                    // 没有有效的文件内容
                    DispatchQueue.main.async {
                        self.errorMessage = "没有有效的文件内容"
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

// 搜索引用结构
struct SearchReference: Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let url: String
}
