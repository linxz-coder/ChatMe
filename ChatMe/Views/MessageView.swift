//
//  MessageView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/7.
//

import SwiftUI
import MarkdownUI

struct MessageView: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    @State private var showDot = false
    @Binding var userFinishedInput: Bool
    @State private var isMessageExpanded: Bool = false  // 默认裁剪用户消息
    @State private var isLocalThinkingExpanded: Bool = true
    @State private var imageLoadingID = UUID() // 添加状态变量用于强制重新加载图片
    @ObservedObject var artifactViewModel: ArtifactViewModel
    
    
    // 新增属性，获取当前选中的模型
    private var currentModel: Model? {
        viewModel.modelSettings.selectedModel
    }
    
    // 确保modelIcon函数可用
    private func modelIcon(for provider: String) -> some View {
        let iconName: String
        
        switch provider {
        case "Anthropic":
            iconName = "claude-color"
        case "OpenAI":
            iconName = "openai-color"
        case "DeepSeek":
            iconName = "deepseek-color"
        case "通义千问":
            iconName = "alibaba-color"
        case "DALL-E-3":
            iconName = "dalle-color"
        case "Google":
            iconName = "gemini-color"
        case "XAI":
            iconName = "grok-color"
        case "智谱清言":
            iconName = "chatglm-color"
        case "月之暗面":
            iconName = "kimi-color"
        case "腾讯混元":
            iconName = "tencentcloud-color"
        default:
            iconName = "openai-color"
        }
        
        return Image(iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
    }
    
    // 初始化时从消息加载展开状态
    init(message: ChatMessage, viewModel: ChatViewModel, userFinishedInput: Binding<Bool>, artifactViewModel: ArtifactViewModel) {
        self.message = message
        self.viewModel = viewModel
        self._userFinishedInput = userFinishedInput
        self.artifactViewModel = artifactViewModel
        
        
        // 从消息中初始化本地状态
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            self._isLocalThinkingExpanded = State(initialValue: updatedMessage.isThinkingExpanded)
        } else {
            self._isLocalThinkingExpanded = State(initialValue: true)
        }
    }
    
    private var currentMessageContent: String {
        // 找到viewModel中相应的消息
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            return updatedMessage.chat_content
        }
        
        return message.chat_content
    }
    
    // 获取当前消息的思考内容
    private var currentThinkingContent: String {
        // 如果是正在流式输出的最后一条消息，使用 viewModel 的 thinkingText
        if message.id == viewModel.chatMessages.last?.id &&
            message.character == "ai" &&
            viewModel.isLoading {
            return viewModel.thinkingText
        }
        
        // 否则从消息本身获取已保存的思考内容
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            return updatedMessage.thinking_content
        }
        
        return ""
    }
    
    var body: some View {
        HStack(alignment: .top) {
            // 用户消息
            if message.character == "user" {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    MessageContentView(
                        content: message.chat_content,
                        isExpanded: $isMessageExpanded
                    )
                }
            }
            // AI消息
            else {
                //MARK: - 分情况显示AI头像
                // 使用数据库provider_name对应的模型的图标
                // 首先尝试从消息中获取provider_name
                if let messageProviderName = getProviderNameFromMessage(message), !messageProviderName.isEmpty {
                    // 使用消息自己的provider_name
                    modelIcon(for: messageProviderName)
                        .foregroundStyle(.gray)
                }
                
                // 如果是当前会话中最后一条AI消息(包括刚刚完成生成的消息)
                else if message.id == viewModel.chatMessages.last(where: { $0.character == "ai" })?.id {
                    // 对于当前会话的最后一条AI消息，总是使用当前选中的模型图标
                    if let model = currentModel {
                        modelIcon(for: model.providerName)
                            .foregroundStyle(.gray)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.gray)
                    }
                }
                
                
                else if message.character == "ai" && viewModel.isLoading {
                    if let model = currentModel {
                        modelIcon(for: model.providerName)
                            .foregroundStyle(.gray)
                    } else {
                        // 如果没有选中模型，使用默认图标
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.gray)
                    }
                }
                // 对于消息中没有provider_name的历史消息，使用默认图标
                else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.gray)
                }
                
                //MARK: - 显示回复信息
                if message.id == viewModel.chatMessages.last?.id && message.character == "ai" && viewModel.isLoading && viewModel.responseText.isEmpty && viewModel.thinkingText.isEmpty {
                    HStack{
                        // 展示闪烁的黑点
                        Circle()
                            .fill(Color.black.opacity(showDot ? 1 : 0))
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)
                            .onAppear {
                                // 开始闪烁动画
                                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                                    showDot.toggle()
                                }
                            }
                        
                        if(viewModel.modelSettings.selectedModel?.modelType == .image){
                            Text("图片生成中...")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                } else {
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // 显示思考过程。
                        if message.character == "ai" && !currentThinkingContent.isEmpty {
                            
                            VStack(alignment: .leading) {
                                Button {
                                    // 切换当前消息的本地状态
                                    isLocalThinkingExpanded.toggle()
                                    
                                    // 同时更新消息模型中的状态（可选，用于持久化）
                                    if let index = viewModel.chatMessages.firstIndex(where: { $0.id == message.id }) {
                                        var updatedMessage = viewModel.chatMessages[index]
                                        updatedMessage.isThinkingExpanded = isLocalThinkingExpanded
                                        viewModel.chatMessages[index] = updatedMessage
                                    }
                                } label: {
                                    HStack {
                                        Text("思考过程：")
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: isLocalThinkingExpanded ? "chevron.up" : "chevron.down")
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
                                    .background(Color(
                                        light: Color(rgba: 0xf0f0_f0ff), dark: Color(rgba: 0x2a2a_2aff)
                                    ))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                if isLocalThinkingExpanded {
                                    ScrollView{
                                        Text(currentThinkingContent)
                                            .padding(.init(top: 8, leading: 12, bottom: 8, trailing: 12))
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        // 使用不引起位置变化的转场动画
                                            .transition(.opacity)
                                        // 保持固定高度，避免高度突变
                                            .animation(.linear(duration: 0.2), value: currentThinkingContent)
                                        
                                    }
                                    .frame(maxHeight: 300)
                                }
                            }
                        }
                        
                        // 显示响应文本 - 流式输出
                        if message.id == viewModel.chatMessages.last?.id && message.character == "ai" && viewModel.isLoading && currentMessageContent.isEmpty {
                            Markdown(viewModel.responseText)
                                .markdownTheme(.fancyWithDiff)
                                .markdownCodeSyntaxHighlighter(.splash(theme: .vscodeDark(withFont: .init(size: 12))))
                                .lineSpacing(5)
                                .textSelection(.enabled)
                        } else {
                            if artifactViewModel.hasPreviewableContent{
                                Button{
                                    artifactViewModel.isPreviewEnabled = true
                                }label:{
                                    Text("Artifact View")
                                }
                                Markdown(currentMessageContent)
                                    .markdownTheme(.fancyWithDiff)
                                    .markdownCodeSyntaxHighlighter(.splash(theme: .vscodeDark(withFont: .init(size: 12))))
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                            } else {
                                Markdown(currentMessageContent)
                                    .markdownTheme(.fancyWithDiff)
                                    .markdownCodeSyntaxHighlighter(.splash(theme: .vscodeDark(withFont: .init(size: 12))))
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                            }

                            
                            
                            // 显示图片（如果有）
                            if !message.imageUrl.isEmpty {
                                AsyncImage(url: URL(string: message.imageUrl)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 300, height: 300)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: 500, maxHeight: 500)
                                            .cornerRadius(12)
                                            .contextMenu {
                                                Button {
                                                    // 保存图片到用户选择的位置
                                                    saveImage(imageURL: message.imageUrl)
                                                } label: {
                                                    Label("保存图片", systemImage: "arrow.down.circle")
                                                }.labelStyle(.titleAndIcon)
                                                
                                                Button {
                                                    // 复制图片链接到剪贴板
                                                    copyImageURL(message.imageUrl)
                                                } label: {
                                                    Label("复制图片链接", systemImage: "document.on.document")
                                                }.labelStyle(.titleAndIcon)
                                            }
                                        Text("右键保存图片，以防图片链接失效。")
                                            .font(.footnote)
                                    case .failure:
                                        HStack{
                                            Text("图片加载失败")
                                                .foregroundColor(.red)
                                                .padding()
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(8)
                                            Button {
                                                //加载
                                                imageLoadingID = UUID() // 生成新的ID触发AsyncImage重新加载
                                            } label: {
                                                Text("重新加载")
                                            }.buttonStyle(.bordered)
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .id(imageLoadingID)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    // 保存图片到用户选择的位置
    private func saveImage(imageURL: String) {
        guard let url = URL(string: imageURL) else {
            print("无效的图片URL")
            return
        }
        
        // 从URL获取建议的文件名
        let suggestedFileName = url.lastPathComponent
        
        // 创建保存面板
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = suggestedFileName
        savePanel.allowedContentTypes = [.jpeg, .png]
        
        // 显示保存面板
        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                // 下载图片并保存
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("下载图片失败: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        print("没有接收到图片数据")
                        return
                    }
                    
                    do {
                        try data.write(to: saveURL)
                        print("图片已保存到: \(saveURL.path)")
                    } catch {
                        print("保存图片失败: \(error.localizedDescription)")
                    }
                }.resume()
            }
        }
    }
    
    // 复制图片链接到剪贴板
    private func copyImageURL(_ imageURL: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageURL, forType: .string)
        print("图片URL已复制到剪贴板")
    }
    
    // 从消息中获取供应商名称
    private func getProviderNameFromMessage(_ message: ChatMessage) -> String? {
        // 找到viewModel中相应的消息以获取最新数据
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            // 从ChatService中获取消息时，provider_name应该已经被保存
            // 您需要确保ChatService的getMessages方法正确地检索和设置这个属性
            // 可以通过在ChatMessage结构体中添加providerName属性
            return updatedMessage.providerName
        }
        return nil
    }
}



//扩展代码块
extension Theme {
    
    
    static let fancy = Theme()
        .text {
            ForegroundColor(.text)
        }
        .link {
            ForegroundColor(.link)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: .em(0.8), bottom: .zero)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(2))
                }
        }
        .heading2 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.0625))
                .markdownMargin(top: .em(1.6), bottom: .zero)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.88235))
                }
        }
        .heading3 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.07143))
                .markdownMargin(top: .em(1.6), bottom: .zero)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.64706))
                }
        }
        .heading4 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.083335))
                .markdownMargin(top: .em(1.6), bottom: .zero)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.41176))
                }
        }
        .heading5 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.09091))
                .markdownMargin(top: .em(1.6), bottom: .zero)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.29412))
                }
        }
        .heading6 { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.235295))
                .markdownMargin(top: .em(1.6), bottom: .zero)
                .markdownTextStyle {
                    FontWeight(.semibold)
                }
        }
        .paragraph { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.5))
                .markdownMargin(top: .em(0.8), bottom: .zero)
        }
        .blockquote { configuration in
            configuration.label
                .relativePadding(length: .rem(0.94118))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        RoundedRectangle.container
                            .fill(Color.asideNoteBackground)
                        RoundedRectangle.container
                            .strokeBorder(Color.asideNoteBorder)
                    }
                }
                .markdownMargin(top: .em(1.6), bottom: .zero)
        }
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 0) {
                // 额外信息框：包含语言标签和复制按钮
                HStack {
                    Text(configuration.language ?? "code")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color.secondaryLabel)
                        .padding(.leading, 14)
                    Spacer()
                    CopyButton(code: configuration.content)
                        .padding(.trailing, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(
                    light: Color(rgba: 0xf0f0_f0ff), dark: Color(rgba: 0x2a2a_2aff)
                ))
                .roundedCorners(radius: 15, corners: [.topLeft, .topRight])
                ScrollView(.horizontal) {
                    if configuration.language == "diff" {
                        // 对diff语言特殊处理
                        DiffCodeView(code: configuration.content)
                            .padding(.vertical, 8)
                            .padding(.leading, 14)
                    } else {
                        configuration.label
                            .fixedSize(horizontal: false, vertical: true)
                            .relativeLineSpacing(.em(0.333335))
                            .markdownTextStyle {
                                FontFamilyVariant(.monospaced)
                                FontSize(.rem(1.1))
                            }
                            .padding(.vertical, 8)
                            .padding(.leading, 14)
                    }
                }
                //                .background(Color(
                //                    light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3333_36ff)
                //                ))
                .background(Color(rgba: 0x3333_36ff))
                .roundedCorners(radius: 15, corners: [.bottomLeft, .bottomRight])
                .markdownMargin(top: .em(0.8), bottom: .zero)
            }
        }
        .image { configuration in
            configuration.label
                .frame(maxWidth: .infinity)
                .markdownMargin(top: .em(1.6), bottom: .em(1.6))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.8))
        }
    //            .taskListMarker { _ in
    //              // DocC renders task lists as bullet lists
    //              ListBullet.disc
    //                .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
    //            }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(.horizontalBorders, color: .grid))
                .markdownMargin(top: .em(1.6), bottom: .zero)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .relativeLineSpacing(.em(0.235295))
                .relativePadding(length: .rem(0.58824))
        }
        .thematicBreak {
            Divider()
                .overlay(Color.grid)
                .markdownMargin(top: .em(2.35), bottom: .em(2.35))
        }
}

// 2. 扩展Theme类添加对diff的支持
extension Theme {
    static let fancyWithDiff = fancy
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 0) {
                // 顶部信息栏：包含语言标签和复制按钮
                HStack {
                    Text(configuration.language ?? "code")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color.secondaryLabel)
                        .padding(.leading, 14)
                    Spacer()
                    CopyButton(code: configuration.content)
                        .padding(.trailing, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(
                    light: Color(rgba: 0xf0f0_f0ff), dark: Color(rgba: 0x2a2a_2aff)
                ))
                .roundedCorners(radius: 15, corners: [.topLeft, .topRight])
                
                ScrollView(.horizontal) {
                    if configuration.language?.lowercased() == "diff" {
                        // 特殊处理diff格式的代码
                        DiffCodeView(code: configuration.content)
                            .padding(.vertical, 8)
                            .padding(.leading, 14)
                    } else {
                        // 使用普通的代码高亮处理其他语言
                        configuration.label
                            .fixedSize(horizontal: false, vertical: true)
                            .relativeLineSpacing(.em(0.333335))
                            .markdownTextStyle {
                                FontFamilyVariant(.monospaced)
                                FontSize(.rem(1.1))
                            }
                            .padding(.vertical, 8)
                            .padding(.leading, 14)
                    }
                }
                .background(Color(rgba: 0x3333_36ff))
                .roundedCorners(radius: 15, corners: [.bottomLeft, .bottomRight])
                .markdownMargin(top: .em(0.8), bottom: .zero)
            }
        }
}

extension Shape where Self == RoundedRectangle {
    fileprivate static var container: Self {
        .init(cornerRadius: 15, style: .continuous)
    }
}

extension Color {
    fileprivate static let text = Color(
        light: Color(rgba: 0x1d1d_1fff), dark: Color(rgba: 0xf5f5_f7ff)
    )
    fileprivate static let secondaryLabel = Color(
        light: Color(rgba: 0x6e6e_73ff), dark: Color(rgba: 0x8686_8bff)
    )
    fileprivate static let link = Color(
        light: Color(rgba: 0x0066_ccff), dark: Color(rgba: 0x2997_ffff)
    )
    fileprivate static let asideNoteBackground = Color(
        light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3232_32ff)
    )
    fileprivate static let asideNoteBorder = Color(
        light: Color(rgba: 0x6969_69ff), dark: Color(rgba: 0x9a9a_9eff)
    )
    fileprivate static let codeBackground = Color(
        light: Color(rgba: 0xf5f5_f7ff), dark: Color(rgba: 0x3333_36ff)
    )
    fileprivate static let grid = Color(
        light: Color(rgba: 0xd2d2_d7ff), dark: Color(rgba: 0x4242_45ff)
    )
}


// 定义一个OptionSet，用于指定哪些角需要圆角化 - 类似于UIRectCorner
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomRight = RectCorner(rawValue: 1 << 2)
    static let bottomLeft = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

// 绘制具有指定圆角的形状
struct RoundedCornersShape: Shape {
    var radius: CGFloat = .zero
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let p1 = CGPoint(x: rect.minX, y: corners.contains(.topLeft) ? rect.minY + radius  : rect.minY )
        let p2 = CGPoint(x: corners.contains(.topLeft) ? rect.minX + radius : rect.minX, y: rect.minY )
        
        let p3 = CGPoint(x: corners.contains(.topRight) ? rect.maxX - radius : rect.maxX, y: rect.minY )
        let p4 = CGPoint(x: rect.maxX, y: corners.contains(.topRight) ? rect.minY + radius  : rect.minY )
        
        let p5 = CGPoint(x: rect.maxX, y: corners.contains(.bottomRight) ? rect.maxY - radius : rect.maxY )
        let p6 = CGPoint(x: corners.contains(.bottomRight) ? rect.maxX - radius : rect.maxX, y: rect.maxY )
        
        let p7 = CGPoint(x: corners.contains(.bottomLeft) ? rect.minX + radius : rect.minX, y: rect.maxY )
        let p8 = CGPoint(x: rect.minX, y: corners.contains(.bottomLeft) ? rect.maxY - radius : rect.maxY )
        
        path.move(to: p1)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: p2,
                    radius: radius)
        path.addLine(to: p3)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: p4,
                    radius: radius)
        path.addLine(to: p5)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                    tangent2End: p6,
                    radius: radius)
        path.addLine(to: p7)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                    tangent2End: p8,
                    radius: radius)
        path.closeSubpath()
        
        return path
    }
}

// View扩展，可以像修饰符一样使用：
extension View {
    func roundedCorners(radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornersShape(radius: radius, corners: corners))
    }
}

import SwiftUI
import MarkdownUI

// 扩展MessageView添加对ArtifactViewModel的支持
//extension MessageView {
//    // 添加对ArtifactViewModel的支持(可选参数)
//    init(message: ChatMessage, viewModel: ChatViewModel, userFinishedInput: Binding<Bool>, artifactViewModel: ArtifactViewModel? = nil) {
//        self.message = message
//        self.viewModel = viewModel
//        self._userFinishedInput = userFinishedInput
//        
//        // 从消息中初始化本地状态
//        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
//            self._isLocalThinkingExpanded = State(initialValue: updatedMessage.isThinkingExpanded)
//        } else {
//            self._isLocalThinkingExpanded = State(initialValue: true)
//        }
//        
//        // 如果提供了artifactViewModel，提取代码块
//        if let artifactViewModel = artifactViewModel, message.character == "ai" {
//            artifactViewModel.extractCodeBlocks(from: message.chat_content)
//        }
//    }
//    
//    // 创建自定义主题，包含预览按钮
//    func customMarkdownTheme(artifactViewModel: ArtifactViewModel? = nil) -> Theme {
//        var theme = Theme.fancyWithDiff
//        
//        // 如果提供了artifactViewModel，为代码块添加预览按钮
//        if let vm = artifactViewModel {
//            theme = theme.codeBlock { configuration in
//                VStack(alignment: .leading, spacing: 0) {
//                    // 顶部信息栏：包含语言标签、预览按钮和复制按钮
//                    HStack {
//                        Text(configuration.language ?? "code")
//                            .font(.system(.body, design: .monospaced))
//                            .foregroundColor(Color.secondaryLabel)
//                            .padding(.leading, 14)
//                        Spacer()
//                        
//                        // 如果是HTML代码，显示预览按钮
//                        if configuration.language?.lowercased() == "html" {
//                            PreviewButton(viewModel: vm)
//                                .padding(.trailing, 4)
//                        }
//                        
//                        CopyButton(code: configuration.content)
//                            .padding(.trailing, 8)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.vertical, 8)
//                    .background(Color(
//                        light: Color(rgba: 0xf0f0_f0ff), dark: Color(rgba: 0x2a2a_2aff)
//                    ))
//                    .roundedCorners(radius: 15, corners: [.topLeft, .topRight])
//                    
//                    ScrollView(.horizontal) {
//                        if configuration.language?.lowercased() == "diff" {
//                            // 特殊处理diff格式的代码
//                            DiffCodeView(code: configuration.content)
//                                .padding(.vertical, 8)
//                                .padding(.leading, 14)
//                        } else {
//                            // 使用普通的代码高亮处理其他语言
//                            configuration.label
//                                .fixedSize(horizontal: false, vertical: true)
//                                .relativeLineSpacing(.em(0.333335))
//                                .markdownTextStyle {
//                                    FontFamilyVariant(.monospaced)
//                                    FontSize(.rem(1.1))
//                                }
//                                .padding(.vertical, 8)
//                                .padding(.leading, 14)
//                        }
//                    }
//                    .background(Color(rgba: 0x3333_36ff))
//                    .roundedCorners(radius: 15, corners: [.bottomLeft, .bottomRight])
//                    .markdownMargin(top: .em(0.8), bottom: .zero)
//                    
//                    // 如果是HTML代码，提取到ArtifactViewModel
//                    .onAppear {
//                        if configuration.language?.lowercased() == "html" {
//                            vm.addCodeBlock(CodeBlock(
//                                language: configuration.language ?? "html",
//                                code: configuration.content
//                            ))
//                        }
//                    }
//                }
//            }
//        }
//        
//        return theme
//    }
//}


//#Preview {
//    MessageView()
//}
