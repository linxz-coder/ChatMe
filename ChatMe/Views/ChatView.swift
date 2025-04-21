//
//  ChatView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/2/27.
//

import SwiftUI

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
                                //                                createNewSession()
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
//                    if artifactViewModel.isActive {
                    if artifactViewModel.isActive && artifactViewModel.isPreviewEnabled {
                        ArtifactPreview(viewModel: artifactViewModel)
                        //                        .frame(width: geometry.size.width * 0.5)
                            .frame(width: geometry.size.width * (1 - dividerPosition))
                            .transition(.move(edge: .trailing))
                    }
                }
                
                // 添加可拖动分隔栏，仅当预览窗口激活时显示
//                if artifactViewModel.isActive {
                if artifactViewModel.isActive && artifactViewModel.isPreviewEnabled {
                    // 分隔栏定位
                    //                    Rectangle()
                    //                        .fill(Color.gray.opacity(0.5))
                    //                        .frame(width: isDragging ? 4 : 2, height: geometry.size.height)
                    //                        .position(x: geometry.size.width * dividerPosition, y: geometry.size.height / 2)
                    
                    // 分隔栏 - 更容易选中的版本
                    ZStack {
                        // 主分隔线
                        //                        Rectangle()
                        //                                                     .fill(Color.white.opacity(0.6))
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
            .onChange(of: chatViewModel.responseText) { newContent in
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

//#Preview {
//    ChatView()
//}
