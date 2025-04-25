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
    @Published var searchReferences: [SearchReference] = []
    var modelSettings: ModelSettingsData
    private var activeTask: URLSessionDataTask?
    private var session: URLSession!
    
    // Add properties for batch updates-thinking
    private var lastThinkingUpdate = Date()
    private var thinkingBuffer = ""
    
    private var modelContext: ModelContext
    
    // To support updating ModelContext after view loading
    func updateModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // Default user information
    let defaultUsername = "lxz"
    let defaultUserId = "b5224a80-56ab-42ed-8cf4-394dc9728bbc"
    let defaultTitle = "默认聊天标题"
    
    
    // initialization
    init(modelSettings: ModelSettingsData, modelContext: ModelContext) {
        self.modelSettings = modelSettings
        self.modelContext = modelContext
        
        super.init()
        
        // Load existing session
        loadSessions()
    }
    
    func loadSessions() {
        do {
            let descriptor = FetchDescriptor<ChatSession>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            let loadedSessions = try modelContext.fetch(descriptor)
            
            DispatchQueue.main.async {
                if loadedSessions.isEmpty {
                    print("nothing")
                } else {
                    self.sessions = loadedSessions
                    // If sessions exist, switch to the first session
                    self.switchSession(to: self.sessions[0])
                }
            }
        } catch {
            print("Load Sessions Failed: \(error.localizedDescription)")
            self.errorMessage = "Load Sessions Failed: \(error.localizedDescription)"
        }
        
    }
    
    // Switch to the selected session
    func switchSession(to session: ChatSession) {
        currentSession = session
        loadMessages(for: session.id)
    }
    
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
            print("Load Messages Failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Load Messages Failed: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    //Update Session Title
    func updateSessionTitle(session: ChatSession, newTitle: String) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].title = newTitle
            
            if currentSession!.id == session.id {
                currentSession!.title = newTitle
            }
            
            //Update chatMessages
            for (index, message) in self.chatMessages.enumerated() {
                if message.ssid == session.id {
                    chatMessages[index].chat_title = newTitle
                }
            }
            
            // Update chat titles in SwiftData
            do {
                try modelContext.save()
                print("Session title updated")
            } catch {
                print("Session title updated Failed: \(error.localizedDescription)")
            }
        }
    }
    
    // Search Messages
    func searchMessagesContent(for sessionId: String, query: String, completion: @escaping (Bool) -> Void) {
        // If it is the current session, search directly in the loaded messages.
        if sessionId == currentSession!.id {
            let hasMatch = chatMessages.contains { message in
                message.chat_content.lowercased().contains(query.lowercased())
            }
            completion(hasMatch)
            return
        }
        
        // If it is not the current session, load and search from the database.
        do {
            let predicate = #Predicate<ChatMessage> { message in
                message.ssid == sessionId && message.chat_content.localizedStandardContains(query)
            }
            let descriptor = FetchDescriptor<ChatMessage>(predicate: predicate)
            let matches = try modelContext.fetch(descriptor)
            completion(!matches.isEmpty)
        } catch {
            print("Search Messages Failed: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // Search in the session list and message content
    func searchAllContent(query: String, completion: @escaping ([ChatSession]) -> Void) {
        if query.isEmpty {
            completion(sessions)
            return
        }
        
        let lowercaseQuery = query.lowercased()
        
        // Firstly, find the sessions that contain the query word in the title.
        var matchingSessions = sessions.filter { session in
            session.title.lowercased().contains(lowercaseQuery)
        }
        
        //Create a Dispatch group to wait for all searches to complete
        let group = DispatchGroup()
        
        // For each unmatched session, search their message content
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
        
        // When all searches are completed, return the results.
        group.notify(queue: .main) {
            completion(matchingSessions)
        }
    }
    
    //AI Answer
    func streamAnswer(requestURL: String, apiKey: String, requestModel: String, systemMessage: String = "You are a helpful assistant", userMessage: String, userMessageWithoutFile: String = "", enableWebSearch: Bool = false) {
        
        var chatHistoryString = ""
        
        // Check the current selected model type
        if let selectedModel = modelSettings.selectedModel, selectedModel.modelType == .image {
            // For Image Model，Use generateImage
            generateImage(prompt: userMessage)
            return
        }
        
        // Get History messages
        do {
            
            let messages = currentSession!.messages
            
            // Clear History
            var formattedHistory = ""
            // Get the most recent 10 messages
            let recentMessages = messages.sorted(by: { $0.sequence < $1.sequence }).suffix(10)
            
            for message in recentMessages {
                let role = message.character == "user" ? "用户" : "AI"
                formattedHistory += "\(role): \(message.chat_content)\n"
            }
            
            chatHistoryString = formattedHistory
            
            // Add user message
            let messageToAdd = userMessageWithoutFile.isEmpty ? userMessage : userMessageWithoutFile
            
            // Continue processing, pass the history into the API call
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
            print("Fail to get messages history: \(error.localizedDescription)")
            // When an error occurs, also add a user message and continue.
            let messageToAdd = userMessageWithoutFile.isEmpty ? userMessage : userMessageWithoutFile
            
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
    
    // sync chatMessages and the messages in SwiftData
    func synchronizeMessages(for sessionId: String) {
        do {
            let descriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.ssid == sessionId },
                sortBy: [SortDescriptor(\.sequence)]
            )
            chatMessages = try modelContext.fetch(descriptor)
        } catch {
            print("Fail to sync message: \(error.localizedDescription)")
        }
    }
    
    
    private func continueStreamAnswerWithHistory(requestURL: String, apiKey: String, requestModel: String, systemMessage: String, userMessage: String, chatHistory: String, enableWebSearch: Bool = false) {
        
        // Make sure chatMessages are updated
        synchronizeMessages(for: self.currentSession!.id)
        
        // a blank AI answer
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
            
            // Add to swiftData
            self.modelContext.insert(aiMessage)
            
            // Add to current session
            self.currentSession!.messages.append(aiMessage)
            
            // save to the context
            do {
                try self.modelContext.save()
            } catch {
                print("Fail to save AI answer: \(error.localizedDescription)")
            }
        }
        
        guard let url = URL(string: requestURL) else { return }
        
        // Check if needs proxy
        let providerName = getProviderNameFromURL(requestURL)
        let configuration = URLSessionConfiguration.default
        
        // if the provider is Anthropic or OpenAI，and proxy setting is set, use proxy
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
            print("Use proxy: \(host):\(port) for \(providerName)")
        }
        
        // Use URLSession for every request
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        
        
        let isThinkingMode = requestURL.contains("anthropic.com") &&
        modelSettings.selectedModel?.isThinkingEnabled == true
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // if the provider is Anthropic API, adjust to a different Authorization format
        if providerName == "Anthropic" {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        } else {
            // Other API: standard Bearer format
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Make request
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
                "stream": true  // Make sure to set stream as "true"
            ]
            
            // If thinking mode is on，add thinking property
            if isThinkingMode {
                postData["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": 16000
                ]
                //print("启用思考模式，budget_tokens: 16000")
            }
        } else if providerName == "腾讯混元" && enableWebSearch {
            // Add Search function to hunyuan model
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
                "stream": true
            ]
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: postData) else {
            print("Failed to convert data to JSON")
            return
        }
        
        request.httpBody = jsonData
        
        let task = self.session.dataTask(with: request)
        
        print("Making request...")
        self.activeTask = task
        task.resume()
    }
    
    
    // Identify providers from URL
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
    
    // Invoke when receiving a data block
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // Data to String
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        
        // Print the original returned data for debugging
        // print("Data received: \(dataString)")
        
        // Check if it is an error response
        if let httpResponse = dataTask.response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            // Parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var detailedError = "API Error: "
                
                // Extract error details
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
                
                print("Error Detail: \(detailedError)")
                DispatchQueue.main.async {
                    self.errorMessage = detailedError
                }
                return
            }
        }
        
        let isAnthropicAPI = dataTask.currentRequest?.url?.absoluteString.contains("anthropic.com") ?? false
        let isTencentAPI = dataTask.currentRequest?.url?.absoluteString.contains("hunyuan.cloud.tencent.com") ?? false
        
        // Each block is separated by a newline character.
        let lines = dataString.split(separator: "\n")
        
        for line in lines {
            //Ignore empty lines
            if line.isEmpty { continue }
            
            
            if isAnthropicAPI {
                // Check if it is a data row
                if !line.hasPrefix("data: ") { continue }
                let jsonString = line.dropFirst(6) // Delete "data: " prefix
                
                // Ignore [DONE] message
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    continue
                }
                
                // Parse JSON
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                
                // Print JSON response
                //                print("Anthropic response JSON: \(json)")
                
                // Handle error
                if let type = json["type"] as? String, type == "error" {
                    // Extract Error information
                    var errorMessage = "Anthropic API Error"
                    
                    if let error = json["error"] as? [String: Any] {
                        if let message = error["message"] as? String {
                            errorMessage += ": " + message
                        }
                        
                        if let type = error["type"] as? String {
                            errorMessage += " (Type: \(type))"
                        }
                        
                        if let code = error["code"] as? String {
                            errorMessage += " [Code: \(code)]"
                        }
                    }
                    
                    print("Error Message: \(errorMessage)")
                    
                    // Update UI to display Error
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
                            
                            // Handle thinking responses
                            if deltaType == "thinking_delta", let thinking = delta["thinking"] as? String {
                                //                                print("thinking: \(thinking)")
                                // Accumulate thinking content into the buffer
                                self.thinkingBuffer += thinking
                                
                                // Check if needs to update UI
                                let now = Date()
                                if now.timeIntervalSince(self.lastThinkingUpdate) > 0.5 { // 500 milliseconds batch update
                                    self.flushThinkingBuffer()
                                }
                            }
                            // Process normal content
                            else if deltaType == "text_delta", let text = delta["text"] as? String {
                                DispatchQueue.main.async {
                                    self.responseText += text
                                }
                            }
                        }
                    case "message_start", "content_block_start", "content_block_stop", "message_delta", "message_stop":
                        // Record the event type but no special handling is required.
                        print("Event Type: \(type)")
                    default:
                        print("Unknown Type: \(type)")
                    }
                }
                
            } else if isTencentAPI {
                guard line.hasPrefix("data: ") else { continue }
                
                // Extract JSON
                let jsonString = line.dropFirst(6) // 删除"data: "前缀
                
                // Ignore [DONE] Message
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    continue
                }
                
                // Parse JSON
                //                print("hunyuan response content: \(jsonString)")
                
                
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    // Check different formats of response structures
                    if let choices = json["choices"] as? [[String: Any]] {
                        if let firstChoice = choices.first {
                            // Parse Delta format
                            if let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                // Update UI
                                DispatchQueue.main.async {
                                    print("Get hunyuan Content: \(content)")
                                    self.responseText += content
                                }
                            }
                            // Parse none Delta format
                            else if let content = firstChoice["content"] as? String {
                                DispatchQueue.main.async {
                                    print("Get hunyuan Content(!Delta): \(content)")
                                    self.responseText += content
                                }
                            }
                        }
                    }
                    
                    // Handle Search Reference
                    if let searchInfo = json["search_info"] as? [String: Any],
                       let searchResults = searchInfo["search_results"] as? [[String: Any]] {
                        
                        print("Count of Search reference: \(searchResults.count)")
                        let references = searchResults.compactMap { result -> SearchReference? in
                            guard let index = result["index"] as? Int,
                                  let title = result["title"] as? String,
                                  let url = result["url"] as? String else {
                                print("Data format error: \(result)")
                                return nil
                            }
                            
                            return SearchReference(index: index, title: title, url: url)
                        }
                        
                        // Update references data
                        if !references.isEmpty {
                            DispatchQueue.main.async {
                                print("Add \(references.count) references")
                                // Only add new reference
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
                let jsonString = line.dropFirst(6) // Delete "data: " prefix
                
                // Ignore [DONE] message
                if jsonString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" {
                    continue
                }
                
                // Parse JSON
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    // Update UI
                    DispatchQueue.main.async {
                        self.responseText += content
                    }
                }
            }
            
            
        }
    }
    
    // Update thinking buffer
    private func flushThinkingBuffer() {
        guard !thinkingBuffer.isEmpty else { return }
        
        let contentToAdd = thinkingBuffer
        thinkingBuffer = ""
        self.lastThinkingUpdate = Date()
        
        DispatchQueue.main.async {
            self.thinkingText += contentToAdd
        }
    }
    
    // Invoke when get response
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        //        print("Receive response header，status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        
        // Make sure to update remaining thinking content
        if !thinkingBuffer.isEmpty {
            flushThinkingBuffer()
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            print("Receive response header，status code: \(statusCode)")
            
            // For Error status code，add to errorMessage.
            if statusCode >= 400 {
                DispatchQueue.main.async {
                    self.errorMessage = "Error status code: \(statusCode)"
                    self.isLoading = false
                }
            }
        }
        
        completionHandler(.allow)
    }
    
    // Invoke when session is finished
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        // Make sure to update remaining thinking content
        if !thinkingBuffer.isEmpty {
            flushThinkingBuffer()
        }
        
        if let error = error {
            //            print("Error: \(error.localizedDescription)")
            // Check if the error is by user's cancel action
            let nsError = error as NSError
            let isCancelled = nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
            
            if isCancelled {
                print("User cancel the AI answer manually")
                
                // Even if it is a cancel operation, save the current received response
                DispatchQueue.main.async {
                    self.saveCurrentResponse()
                    self.isAnswering = false
                }
            } else {
                print("Error: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        } else {
            print("Session finished")
            // When session finished，make responseText as AI response
            DispatchQueue.main.async {
                self.saveCurrentResponse()
                self.isLoading = false
                self.isAnswering = false
            }
        }
    }
    
    private func saveCurrentResponse(){
        if !self.responseText.isEmpty {
            
            
            // update last AI content
            if let lastIndex = self.chatMessages.lastIndex(where: { $0.character == "ai" }) {
                let updatedMessage = self.chatMessages[lastIndex]
                
                // final Content，including references
                var finalContent = self.responseText
                
                // if references, add to the end of the content
                if !self.searchReferences.isEmpty {
                    finalContent += "\n\n---\n\n"
                    finalContent += "\n\n**参考资料：**\n"
                    for reference in self.searchReferences.sorted(by: { $0.index < $1.index }) {
                        finalContent += "\n[\(reference.index)] \(reference.title): \(reference.url)\n"
                    }
                }
                
                updatedMessage.chat_content = finalContent
                
                // Save the content of thoughts to the attached attributes of the message
                if !self.thinkingText.isEmpty {
                    updatedMessage.thinking_content = self.thinkingText
                }
                
                // Add model information to SwiftData
                if let currentModel = self.modelSettings.selectedModel {
                    updatedMessage.providerName = currentModel.providerName
                    updatedMessage.modelName = currentModel.name
                }
                
                self.chatMessages[lastIndex] = updatedMessage
                
                // Save AI response to SwiftData
                do {
                    try self.modelContext.save()
                    print("AI response saved.")
                    print("After AI answer: ")
                    for message in self.chatMessages {
                        print("ID: \(message.id), SSID: \(message.ssid), character: \(message.character), content: \(message.chat_content)")
                    }
                } catch {
                    print("Fail to save AI response: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Generate Images
    func generateImage(prompt: String) {
        
        // Create an empty aiMessage
        let aiMessage = ChatMessage(
            id: UUID().uuidString,
            ssid: self.currentSession!.id,
            character: "ai",
            chat_title: self.currentSession!.title,
            chat_content: "Generating Images...",
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
            
            // Add to SwiftData
            self.modelContext.insert(aiMessage)
            self.currentSession!.messages.append(aiMessage)
            try? self.modelContext.save()
        }
        
        guard let selectedModel = modelSettings.selectedModel,
              let url = URL(string: selectedModel.baseUrl) else {
            DispatchQueue.main.async {
                self.errorMessage = "Model Configation Error"
                self.isLoading = false
            }
            return
        }
        
        // Config request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(selectedModel.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 打印所有请求头信息（但遮盖API密钥部分内容）
        //        print("====== 请求信息 ======")
        //        print("URL: \(request.url?.absoluteString ?? "未知")")
        //        print("HTTP方法: \(request.httpMethod ?? "未知")")
        //        print("请求头:")
        if let allHTTPHeaderFields = request.allHTTPHeaderFields {
            for (key, value) in allHTTPHeaderFields {
                if key.lowercased() == "authorization" {
                    // Only the first 10 and last 4 characters of the API key are displayed, others replaced with ***
                    let apiKeyPrefix = String(value.prefix(15))
                    let apiKeySuffix = value.count > 4 ? String(value.suffix(4)) : ""
                    print("  \(key): \(apiKeyPrefix)***\(apiKeySuffix)")
                } else {
                    print("  \(key): \(value)")
                }
            }
        }
        
        // Make request
        let requestData: [String: Any] = [
            "model": selectedModel.name.isEmpty ? "dall-e-3" : selectedModel.name,
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024"
        ]
        
        
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            DispatchQueue.main.async {
                self.errorMessage = "Request Error"
                self.isLoading = false
            }
            return
        }
        
        request.httpBody = jsonData
        
        // Session Configation
        let configuration = URLSessionConfiguration.default
        if shouldUseProxy() {
            if let proxyConfig = modelSettings.getProxyConfiguration() {
                configuration.connectionProxyDictionary = proxyConfig.connectionProxyDictionary
            }
        }
        
        // Create session and make request
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            
            // clear activeTask
            self?.activeTask = nil
            
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Fail to request: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No response data"
                }
                return
            }
            
            // Parse JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [[String: Any]],
                   let firstImage = data.first,
                   let imageUrl = firstImage["url"] as? String {
                    
                    // Update AI message
                    DispatchQueue.main.async {
                        if let lastIndex = self.chatMessages.lastIndex(where: { $0.character == "ai" }) {
                            var updatedMessage = self.chatMessages[lastIndex]
                            updatedMessage.chat_content = "Image Generated:"
                            updatedMessage.imageUrl = imageUrl
                            self.chatMessages[lastIndex] = updatedMessage
                            
                            // Save to SwiftData
                            do {
                                try self.modelContext.save()
                                print("AI Image Saved.")
                            } catch {
                                print("Fail to save Image: \(error.localizedDescription)")
                            }
                        }
                    }
                } else if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    if let error = errorJson["error"] as? [String: Any]{
                        if let message = error["message"] as? String {
                            DispatchQueue.main.async {
                                self.errorMessage = "API Error: \(message)"
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Cannot parse API response"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Fail to parse response: \(error.localizedDescription)"
                }
            }
        }
        
        task.resume()
        self.activeTask = task
    }
    
    // check if needs to use Proxy
    func shouldUseProxy() -> Bool {
        guard let model = modelSettings.selectedModel else { return false }
        return model.providerName == "Anthropic" || model.providerName == "OpenAI" || model.providerName == "DALL-E-3"
    }
    
    // Cut Streaming
    func stopStreamResponse() {
        
        // Make sure to update remaining thinking content
        if !thinkingBuffer.isEmpty {
            flushThinkingBuffer()
        }
        
        // Save currently received responses before canceling tasks
        DispatchQueue.main.async {
            self.saveCurrentResponse()
            // Clear temporary response text to avoid duplicate display
            self.responseText = ""
            self.thinkingText = ""
            self.isLoading = false
            print("User stop AI answer streaming manually")
        }
        
        // Cancel active tasks
        if let task = self.activeTask {
            task.cancel()
            self.activeTask = nil
        }
    }
    
}

// ChatViewModel extension，Add file handling function
extension ChatViewModel {
    
    // Handle file request from chatglm
    func handleFileRequest(fileId: String, prompt: String) {
        // Add loading status
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Get selected model or current model
        let apiKey = modelSettings.selectedModel?.apiKey ?? modelSettings.apiKey
        let model = ((modelSettings.selectedModel?.name.isEmpty) != nil) ?
        "glm-4-long" : modelSettings.selectedModel?.name ?? "glm-4-long"
        
        // First get content of the file
        FileUploadManager.shared.getFileContent(fileId: fileId, apiKey: apiKey) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let content):
                // Make request
                var messageContent = prompt
                if !messageContent.isEmpty {
                    messageContent += "\n\n"
                }
                messageContent += "文件内容：\n\(content)"
                
                // Make stream request with uploaded files
                self.streamAnswerWithFileContent(
                    content: messageContent,
                    model: model,
                    apiKey: apiKey
                )
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.errorMessage = "Fail to get content of files: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // Stream Answer with file content
    private func streamAnswerWithFileContent(content: String, model: String, apiKey: String) {
        // check if apiKey is empty
        guard !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "API Key did not exist."
                self.isLoading = false
            }
            return
        }
        
        
        // Create an empty AI message
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
            
            // Add to SwiftData
            self.modelContext.insert(aiMessage)
            self.currentSession!.messages.append(aiMessage)
            try? self.modelContext.save()
        }
        
        // Create request URL
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions") else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid API URL"
                self.isLoading = false
            }
            return
        }
        
        // Make request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Request body
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": content]
            ],
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 32000
        ]
        
        // Transform request body to JSON format
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            DispatchQueue.main.async {
                self.errorMessage = "Request Body data created failed."
                self.isLoading = false
            }
            return
        }
        
        request.httpBody = jsonData
        
        // Create URL session
        let configuration = URLSessionConfiguration.default
        if shouldUseProxy() {
            if let proxyConfig = modelSettings.getProxyConfiguration() {
                configuration.connectionProxyDictionary = proxyConfig.connectionProxyDictionary
            }
        }
        
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        
        // Send request
        let task = session.dataTask(with: request)
        task.resume()
    }
    
    // Multiple files
    func processMultipleFiles(files: [UploadedFile], prompt: String) {
        // Loading status
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        // Get selected model or current model
        let apiKey = modelSettings.selectedModel?.apiKey ?? modelSettings.apiKey
        
        // Files to handle
        var remainingFiles = files.count
        var fileContents: [String] = []
        
        // Get content of each file
        for file in files {
            if let fileId = file.fileId {
                FileUploadManager.shared.getFileContent(fileId: fileId, apiKey: apiKey) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let content):
                        fileContents.append("文件 '\(file.name)' 内容：\n\(content)\n\n")
                    case .failure(let error):
                        print("Fail to get content: \(error.localizedDescription)")
                    }
                    
                    remainingFiles -= 1
                    
                    // When files are uploaded, send request
                    if remainingFiles == 0 {
                        // Make request
                        var messageContent = prompt
                        if !messageContent.isEmpty && !fileContents.isEmpty {
                            messageContent += "\n\n"
                        }
                        
                        // Add content of all files
                        messageContent += fileContents.joined()
                        
                        // Get selected model
                        let model = ((self.modelSettings.selectedModel?.name.isEmpty) != nil) ?
                        "glm-4-long" : self.modelSettings.selectedModel?.name ?? "glm-4-long"
                        
                        // Stream Answer with file content
                        self.streamAnswerWithFileContent(
                            content: messageContent,
                            model: model,
                            apiKey: apiKey
                        )
                    }
                }
            } else {
                remainingFiles -= 1
                
                // When all files uploaded, check if needs to send quest
                if remainingFiles == 0 && !fileContents.isEmpty {
                    // Make request
                    var messageContent = prompt
                    if !messageContent.isEmpty && !fileContents.isEmpty {
                        messageContent += "\n\n"
                    }
                    
                    // Add content of all files
                    messageContent += fileContents.joined()
                    
                    
                    // Get selected model
                    let model = ((self.modelSettings.selectedModel?.name.isEmpty) != nil) ?
                    "glm-4-long" : self.modelSettings.selectedModel?.name ?? "glm-4-long"
                    
                    // Stream Answer with file content
                    self.streamAnswerWithFileContent(
                        content: messageContent,
                        model: model,
                        apiKey: apiKey
                    )
                } else if remainingFiles == 0 {
                    // Invalid file content
                    DispatchQueue.main.async {
                        self.errorMessage = "Invalid files."
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

// Search Reference struct
struct SearchReference: Identifiable {
    let id = UUID()
    let index: Int
    let title: String
    let url: String
}
