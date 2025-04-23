//
//  InputView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI
import SwiftData

struct InputView: View {
    
    @EnvironmentObject var chatViewModel: ChatViewModel
    @Environment(\.modelContext) private var context
    @Binding var message: String
    @Binding var userFinishedInput: Bool
    @EnvironmentObject var settings: ModelSettingsData
    @State private var showAttachmentPanel: Bool = false
    @State private var isWebSearchEnabled: Bool = false
    @ObservedObject var fileManager = FileUploadManager.shared
    var defaultSystemMessage: String = "总是用中文回答问题，如果涉及修改代码，总是用diff格式输出。"
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            // Attachment panel (foldable)
            if showAttachmentPanel {
                FileAttachmentPicker()
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack {
                ZStack(alignment: .leading) {
                    MacTextEditorWithEnter(text: $message, onSubmit: {
                        if !chatViewModel.isLoading {
                            sendMessage()
                        }
                    })
                    .frame(height: message.isEmpty ? 15 : min(15 + CGFloat(message.count / 40) * 20, 200))
                    .padding(10)
                    .background(
                        Rectangle()
                            .fill(Color(light: Color(red: 244/255, green: 244/255, blue: 245/255),
                                        dark: Color(red: 38/255, green: 38/255, blue: 40/255)))
                    )
                    .cornerRadius(10)
                    .disabled(chatViewModel.isLoading) // Disable the input box when AI is responding
                    
                    LocalizedText(key: "askSomeThing")
                        .padding()
                        .frame(width: 200, alignment: .leading)
                        .foregroundStyle(.secondary)
                        .opacity(self.message == "" ? 100 : 0)
                        .allowsHitTesting(false) //Placeholder disables click event
                }
                
                
                // Display send or stop button based on current status
                if chatViewModel.isAnswering {
                    Button {
                        // Invoke the method to stop the response
                        chatViewModel.stopStreamResponse()
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.8)))
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: chatViewModel.isAnswering)
                    .buttonStyle(.plain)
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        LocalizedText(key: "send")
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: chatViewModel.isAnswering)
                }
            }
            
            HStack(spacing: 16) {
                Button {
                    print("Add Files")
                    withAnimation {
                        showAttachmentPanel.toggle()
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15))
                        .foregroundColor(showAttachmentPanel ? .blue : .primary)
                }.buttonStyle(.plain)
                
                Button {
                    print("Search the Internet")
                    withAnimation {
                        isWebSearchEnabled.toggle()
                    }
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                        .foregroundColor(isWebSearchEnabled ? .blue : .primary)
                }.buttonStyle(.plain)
            }
        }.padding()
        
        
    }
    
    private func sendMessage(){
        
        // If AI is responding, do not send messages.
        guard !chatViewModel.isLoading else {
            return
        }
        
        // Make sure the message is not empty
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Get the current message text
        let userInput = message
        
        // clear the input box
        message = ""
        
        // check if user finished input
        userFinishedInput = true
        
        //if no messages, create new session
        if chatViewModel.chatMessages.isEmpty{
            context.createNewSession(chatViewModel: chatViewModel, settings: settings)
            
        }
        
        //Send to SwiftData database
        let messageId = UUID().uuidString
        let ssid = chatViewModel.currentSession!.id
        
        let newMessage = ChatMessage(
            id: messageId,
            ssid: ssid,
            character: "user",
            chat_title: chatViewModel.currentSession!.title,
            chat_content: userInput,
            thinking_content: "",
            isThinkingExpanded: true,
            imageUrl: "",
            sequence: chatViewModel.chatMessages.isEmpty ? 1 : chatViewModel.chatMessages.last!.sequence + 1,
            timestamp: Date(),
            username: "lxz",
            userid: "b5224a80-56ab-42ed-8cf4-394dc9728bbc",
            providerName: settings.selectedModel?.providerName ?? "",
            modelName: settings.selectedModel?.name ?? ""
        )
        
        context.insert(newMessage) //Add to SwiftData
        chatViewModel.chatMessages.append(newMessage)  // Ensure that the local array of chatViewModel is also updated.
        
        //Add message to current session
        chatViewModel.currentSession!.messages.append(newMessage)
        
        
        do {
            try context.save()  // Save all changes to the context
            print("After user message: ")
            for message in chatViewModel.chatMessages {
                print("ID: \(message.id), SSID: \(message.ssid), character: \(message.character), content: \(message.chat_content)")
            }
        } catch {
            print("Save failed: \(error)")
        }
        
        
        var visibleMessage = ""
        
        // If there are file attachments, handle the file upload first, then send the message.
        if !fileManager.uploadedFiles.isEmpty {
            // show upload status
            chatViewModel.isLoading = true
            
            // prepare files to upload
            let apiKey = settings.selectedModel?.apiKey ?? settings.apiKey
            var uploadedFileIds: [String] = []
            var uploadedContents: [String] = []
            var remainingUploads = fileManager.uploadedFiles.count
            
            // Handle the callback after all file uploads are completed.
            let processCompletedUploads = {
                if remainingUploads <= 0 {
                    visibleMessage = userInput.isEmpty ? "Analyze the uploaded file" : userInput
                    var backendPrompt = userInput
                    
                    // 添加文件内容到消息中
                    if !uploadedContents.isEmpty {
                        if !backendPrompt.isEmpty {
                            backendPrompt += "\n\n"
                        }
                        backendPrompt += "Here is the content of the uploaded file.：\n\n"
                        for content in uploadedContents {
                            backendPrompt += "```\n\(content)\n```\n\n"
                        }
                    }
                    
                    // Send a request using the selected model
                    processMessageWithSelectedModel(userInput: backendPrompt, visibleMessage: visibleMessage)
                    
                    // Clear list of files uploaded
                    DispatchQueue.main.async {
                        fileManager.removeAllFiles()
                    }
                }
            }
            
            // Upload each file and obtain the content
            for file in fileManager.uploadedFiles {
                // If the file has been uploaded before, skip the upload step.
                if let fileId = file.fileId {
                    // Retrieve the content of the uploaded file
                    fileManager.getFileContent(fileId: fileId, apiKey: apiKey) { result in
                        switch result {
                        case .success(let content):
                            uploadedContents.append(content)
                        case .failure(let error):
                            print("Get file failed: \(error.localizedDescription)")
                        }
                        
                        remainingUploads -= 1
                        processCompletedUploads()
                    }
                } else {
                    // Upload new file
                    fileManager.uploadFileToZhipuAI(file: file, apiKey: apiKey) { result in
                        switch result {
                        case .success(let fileId):
                            uploadedFileIds.append(fileId)
                            
                            // get content of files
                            fileManager.getFileContent(fileId: fileId, apiKey: apiKey) { contentResult in
                                switch contentResult {
                                case .success(let content):
                                    uploadedContents.append(content)
                                case .failure(let error):
                                    print("Get Content of file failed: \(error.localizedDescription)")
                                }
                                
                                remainingUploads -= 1
                                processCompletedUploads()
                            }
                        case .failure(let error):
                            print("Upload Failed: \(error.localizedDescription)")
                            remainingUploads -= 1
                            processCompletedUploads()
                        }
                    }
                }
            }
        } else {
            // No file attachment, send the message directly.
            processMessageWithSelectedModel(userInput: userInput, visibleMessage: visibleMessage)
        }
    }
    
    // Process messages based on the selected model
    private func processMessageWithSelectedModel(userInput: String, visibleMessage: String) {
        // Send a request using the selected model
        if let model = settings.selectedModel {
            // Check if it is an image generation model
            if model.modelType == .image {
                // For image models, directly call the image generation method
                chatViewModel.generateImage(prompt: userInput)
            } else {
                chatViewModel.streamAnswer(
                    requestURL: model.baseUrl,
                    apiKey: model.apiKey,
                    requestModel: model.name.isEmpty ? model.providerName : model.name,
                    systemMessage: defaultSystemMessage,
                    userMessage: userInput,
                    userMessageWithoutFile: visibleMessage,
                    enableWebSearch: isWebSearchEnabled
                )
            }
        } else {
            // If no model is selected, use the current settings.
            chatViewModel.streamAnswer(
                requestURL: settings.baseURL,
                apiKey: settings.apiKey,
                requestModel: settings.modelName,
                systemMessage: defaultSystemMessage,
                userMessage: userInput,
                userMessageWithoutFile: visibleMessage,
                enableWebSearch: isWebSearchEnabled
            )
        }
        
    }
    
}




#Preview {
    // Create a sample SwiftData environment for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatMessage.self, ChatSession.self, configurations: config)
    
    // Create the required environment objects
    let modelSettings = ModelSettingsData.shared
    let chatViewModel = ChatViewModel(
        modelSettings: modelSettings,
        modelContext: container.mainContext
    )
    
    // Create sample session
    let session = ChatSession(
        id: UUID().uuidString,
        title: "Sample Chat",
        messages: [],
        timestamp: Date(),
        username: "Test User",
        userid: UUID().uuidString
    )
    
    // Set current session
    chatViewModel.currentSession = session
    
    // Create different input states
    return VStack(spacing: 20) {
        Text("Input View Preview")
            .font(.headline)
        
        // Empty input
        VStack(alignment: .leading) {
            Text("Empty Input State")
                .font(.subheadline)
            
            InputView(
                message: .constant(""),
                userFinishedInput: .constant(false)
            )
            .background(Color(light: .white, dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
            .border(Color.gray.opacity(0.3))
        }
        
        // Input with text
        VStack(alignment: .leading) {
            Text("Input With Text")
                .font(.subheadline)
            
            InputView(
                message: .constant("Hello, I'd like to know how to create a responsive layout in SwiftUI"),
                userFinishedInput: .constant(false)
            )
            .background(Color(light: .white, dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
            .border(Color.gray.opacity(0.3))
        }
        
        // Input while AI is responding
        VStack(alignment: .leading) {
            Text("While AI is Responding")
                .font(.subheadline)
            
            let customViewModel = chatViewModel
            let _ = { customViewModel.isLoading = true; customViewModel.isAnswering = false  }()//can be set to true
            
            InputView(
                message: .constant("Tell me about SwiftUI animations"),
                userFinishedInput: .constant(true)
            )
            .environmentObject(customViewModel)
            .background(Color(light: .white, dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
            .border(Color.gray.opacity(0.3))
        }
    }
    .padding()
    .frame(width: 600, height: 600)
    .environmentObject(modelSettings)
    .environmentObject(chatViewModel)
    .environmentObject(LocalizationManager.shared)
    .modelContainer(container)
}
