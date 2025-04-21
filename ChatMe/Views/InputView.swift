//
//  InputView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI

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
            
            // 附件面板（可折叠）
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
                    .disabled(chatViewModel.isLoading) // 当AI正在响应时禁用输入框
                    
                    LocalizedText(key: "askSomeThing")
                        .padding()
                        .frame(width: 200, alignment: .leading)
                        .foregroundStyle(.secondary)
                        .opacity(self.message == "" ? 100 : 0)
                        .allowsHitTesting(false) //占位符禁用点击事件
                }
                
                
                // 根据当前状态显示发送或停止按钮
                if chatViewModel.isAnswering {
                    Button {
                        // 调用停止响应的方法
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
                    print("添加附件")
                    withAnimation {
                        showAttachmentPanel.toggle()
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15))
                        .foregroundColor(showAttachmentPanel ? .blue : .primary)
                }.buttonStyle(.plain)
                
                Button {
                    print("联网搜索")
                    withAnimation {
                        isWebSearchEnabled.toggle()
                    }
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                        .foregroundColor(isWebSearchEnabled ? .blue : .primary)
                }.buttonStyle(.plain)
                
                //                Button {
                //                    print("表情")
                //                } label: {
                //                    Image(systemName: "leaf")
                //                        .font(.system(size: 15))
                //                }.buttonStyle(.plain)
            }
        }.padding()
        
        
    }
    
    private func sendMessage(){
        
        // 如果AI正在响应，不允许发送消息
        guard !chatViewModel.isLoading else {
            return
        }
        
        // 确保消息不为空
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // 获取当前消息文本
        let userInput = message
        
        // 清空输入框
        message = ""
        
        // 标记用户已完成输入
        userFinishedInput = true
        
        //如果没有聊天记录，创建新会话
        if chatViewModel.chatMessages.isEmpty{
            context.createNewSession(chatViewModel: chatViewModel, settings: settings)
            
        }
        
        
        //发送到swfitData数据库
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
        
        context.insert(newMessage) //添加到数据库
        chatViewModel.chatMessages.append(newMessage)  // 确保chatViewModel的本地数组也被更新
        
        //将消息添加到当前会话
        chatViewModel.currentSession!.messages.append(newMessage)
        
        
        do {
            try context.save()  // 保存上下文的所有更改
            print("添加用户消息后")
            for message in chatViewModel.chatMessages {
                print("ID: \(message.id), SSID: \(message.ssid), 角色: \(message.character), 内容: \(message.chat_content)")
            }
        } catch {
            print("保存数据时出错: \(error)")
        }
        
        
        var visibleMessage = ""
        
        // 如果有文件附件，先处理文件上传，再发送消息
        if !fileManager.uploadedFiles.isEmpty {
            // 显示上传状态
            chatViewModel.isLoading = true
            
            // 准备上传所有文件
            let apiKey = settings.selectedModel?.apiKey ?? settings.apiKey
            var uploadedFileIds: [String] = []
            var uploadedContents: [String] = []
            var remainingUploads = fileManager.uploadedFiles.count
            
            // 处理所有文件上传完成后的回调
            let processCompletedUploads = {
                if remainingUploads <= 0 {
                    visibleMessage = userInput.isEmpty ? "分析上传的文件" : userInput
                    var backendPrompt = userInput
                    
                    // 添加文件内容到消息中
                    if !uploadedContents.isEmpty {
                        if !backendPrompt.isEmpty {
                            backendPrompt += "\n\n"
                        }
                        backendPrompt += "以下是上传文件的内容：\n\n"
                        for content in uploadedContents {
                            backendPrompt += "```\n\(content)\n```\n\n"
                        }
                    }
                    
                    // 使用选定的模型信息发送请求
                    processMessageWithSelectedModel(userInput: backendPrompt, visibleMessage: visibleMessage)
                    
                    // 清空已上传文件列表
                    DispatchQueue.main.async {
                        fileManager.removeAllFiles()
                    }
                }
            }
            
            // 上传每个文件并获取内容
            for file in fileManager.uploadedFiles {
                // 如果文件已经上传过，跳过上传步骤
                if let fileId = file.fileId {
                    // 获取已上传文件的内容
                    fileManager.getFileContent(fileId: fileId, apiKey: apiKey) { result in
                        switch result {
                        case .success(let content):
                            uploadedContents.append(content)
                        case .failure(let error):
                            print("获取文件内容失败: \(error.localizedDescription)")
                        }
                        
                        remainingUploads -= 1
                        processCompletedUploads()
                    }
                } else {
                    // 上传新文件
                    fileManager.uploadFileToZhipuAI(file: file, apiKey: apiKey) { result in
                        switch result {
                        case .success(let fileId):
                            uploadedFileIds.append(fileId)
                            
                            // 获取文件内容
                            fileManager.getFileContent(fileId: fileId, apiKey: apiKey) { contentResult in
                                switch contentResult {
                                case .success(let content):
                                    uploadedContents.append(content)
                                case .failure(let error):
                                    print("获取文件内容失败: \(error.localizedDescription)")
                                }
                                
                                remainingUploads -= 1
                                processCompletedUploads()
                            }
                        case .failure(let error):
                            print("上传文件失败: \(error.localizedDescription)")
                            remainingUploads -= 1
                            processCompletedUploads()
                        }
                    }
                }
            }
        } else {
            // 没有文件附件，直接发送消息
            processMessageWithSelectedModel(userInput: userInput, visibleMessage: visibleMessage)
        }
    }
    
    // 根据选定的模型处理消息
    private func processMessageWithSelectedModel(userInput: String, visibleMessage: String) {
        // 使用选定的模型信息发送请求
        if let model = settings.selectedModel {
            // 检查是否为图片生成模型
            if model.modelType == .image {
                // 对于图片模型，直接调用图片生成方法
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
            // 如果没有选定模型，使用当前设置
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




//#Preview {
//    InputView(chatViewModel: ChatViewModel(modelSettings: ModelSettingsData()),
//              message: .constant(""),
//              userFinishedInput: .constant(false))
//    .environmentObject(ModelSettingsData())
//    .environmentObject(LocalizationManager.shared)
//}
