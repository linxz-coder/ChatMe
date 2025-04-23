//
//  MessageView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/7.
//

import SwiftUI
import MarkdownUI
import SwiftData

struct MessageView: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    @State private var showDot = false
    @Binding var userFinishedInput: Bool
    @State private var isMessageExpanded: Bool = false  // Default crop user message
    @State private var isLocalThinkingExpanded: Bool = true
    @State private var imageLoadingID = UUID() // Add a status variable to force reload the image
    @ObservedObject var artifactViewModel: ArtifactViewModel
    
    
    // Get Selected Model
    private var currentModel: Model? {
        viewModel.modelSettings.selectedModel
    }
    
    // Ensure the modelIcon function is available
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
    
    // Initialization: Load expanded state from message
    init(message: ChatMessage, viewModel: ChatViewModel, userFinishedInput: Binding<Bool>, artifactViewModel: ArtifactViewModel) {
        self.message = message
        self.viewModel = viewModel
        self._userFinishedInput = userFinishedInput
        self.artifactViewModel = artifactViewModel
        
        
        // Initialize local state from the message
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            self._isLocalThinkingExpanded = State(initialValue: updatedMessage.isThinkingExpanded)
        } else {
            self._isLocalThinkingExpanded = State(initialValue: true)
        }
    }
    
    private var currentMessageContent: String {
        // Find the current message in the viewModel.
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            return updatedMessage.chat_content
        }
        
        return message.chat_content
    }
    
    // Obtain the current message's thinking content
    private var currentThinkingContent: String {
        // If it is streaming, use the viewModel's thinkingText
        if message.id == viewModel.chatMessages.last?.id &&
            message.character == "ai" &&
            viewModel.isLoading {
            return viewModel.thinkingText
        }
        
        // Otherwise, obtain the saved thinking content
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            return updatedMessage.thinking_content
        }
        
        return ""
    }
    
    var body: some View {
        HStack(alignment: .top) {
            // User Message
            if message.character == "user" {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    MessageContentView(
                        content: message.chat_content,
                        isExpanded: $isMessageExpanded
                    )
                }
            }
            // AI Message
            else {
                //MARK: - Display AI avatars by case
                // Firstly, try to obtain the provider_name from the message.
                if let messageProviderName = getProviderNameFromMessage(message), !messageProviderName.isEmpty {
                    modelIcon(for: messageProviderName)
                        .foregroundStyle(.gray)
                }
                
                // If it is the last AI message in the current session (including the message just generated)
                else if message.id == viewModel.chatMessages.last(where: { $0.character == "ai" })?.id {
                    // For the last AI message in the current session, always use the currently selected model icon.
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
                        // If no model is selected, use the default icon.
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.gray)
                    }
                }
                // For historical messages that do not contain provider_name in the message, use the default icon.
                else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.gray)
                }
                
                //MARK: - Display Answer Contents
                if message.id == viewModel.chatMessages.last?.id && message.character == "ai" && viewModel.isLoading && viewModel.responseText.isEmpty && viewModel.thinkingText.isEmpty {
                    HStack{
                        // Displaying flickering black dots
                        Circle()
                            .fill(Color.black.opacity(showDot ? 1 : 0))
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)
                            .onAppear {
                                // Start flickering animation
                                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                                    showDot.toggle()
                                }
                            }
                        
                        if(viewModel.modelSettings.selectedModel?.modelType == .image){
                            LocalizedText(key: "generatingImages...")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                } else {
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Display thinking process
                        if message.character == "ai" && !currentThinkingContent.isEmpty {
                            
                            VStack(alignment: .leading) {
                                Button {
                                    // Switch the status of the current message
                                    isLocalThinkingExpanded.toggle()
                                    
                                    // update the status in the message model (for persistence)
                                    if let index = viewModel.chatMessages.firstIndex(where: { $0.id == message.id }) {
                                        let updatedMessage = viewModel.chatMessages[index]
                                        updatedMessage.isThinkingExpanded = isLocalThinkingExpanded
                                        viewModel.chatMessages[index] = updatedMessage
                                    }
                                } label: {
                                    HStack {
                                        LocalizedText(key: "thinkingProcess: ")
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
                                        // Use transition animations that do not cause a change in position.
                                            .transition(.opacity)
                                        // Maintain a fixed height, avoid sudden changes in height.
                                            .animation(.linear(duration: 0.2), value: currentThinkingContent)
                                        
                                    }
                                    .frame(maxHeight: 300)
                                }
                            }
                        }
                        
                        // Display response text - Streaming
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
                            
                            
                            
                            // Display pictures (if any)
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
                                                    // Save the image to the location selected by the user.
                                                    saveImage(imageURL: message.imageUrl)
                                                } label: {
                                                    Label {
                                                        LocalizedText(key: "save_image")
                                                    } icon: {
                                                        Image(systemName: "arrow.down.circle")
                                                    }
                                                }.labelStyle(.titleAndIcon)
                                                
                                                Button {
                                                    // Copy the image link to the clipboard
                                                    copyImageURL(message.imageUrl)
                                                } label: {
                                                    
                                                    Label {
                                                        LocalizedText(key: "copy_image_url")
                                                    } icon: {
                                                        Image(systemName: "document.on.document")
                                                    }
                                                }.labelStyle(.titleAndIcon)
                                            }
                                        LocalizedText(key: "rightClickToSave")
                                            .font(.footnote)
                                    case .failure:
                                        HStack{
                                            LocalizedText(key: "imageFailed")
                                                .foregroundColor(.red)
                                                .padding()
                                                .background(Color.red.opacity(0.1))
                                                .cornerRadius(8)
                                            Button {
                                                //Reload
                                                imageLoadingID = UUID() // Generate a new ID to trigger AsyncImage to reload
                                            } label: {
                                                LocalizedText(key: "reload")
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
    
    // Save the image to the location selected by the user.
    private func saveImage(imageURL: String) {
        guard let url = URL(string: imageURL) else {
            print("Image URL Failed")
            return
        }
        
        // Extract suggested filename from URL
        let suggestedFileName = url.lastPathComponent
        
        // Create Save Panel
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = suggestedFileName
        savePanel.allowedContentTypes = [.jpeg, .png]
        
        // Display Save Panel
        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                // Download the image and save
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("Image Downloaded Failed: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let data = data else {
                        print("No Image Data")
                        return
                    }
                    
                    do {
                        try data.write(to: saveURL)
                        print("Image is saved to: \(saveURL.path)")
                    } catch {
                        print("Image saved failed: \(error.localizedDescription)")
                    }
                }.resume()
            }
        }
    }
    
    // Copy the image link to the clipboard
    private func copyImageURL(_ imageURL: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(imageURL, forType: .string)
        print("Image copyed to clipboard.")
    }
    
    // Extract provider name from the message
    private func getProviderNameFromMessage(_ message: ChatMessage) -> String? {
        //Find the corresponding message in viewModel to obtain the latest data
        if let updatedMessage = viewModel.chatMessages.first(where: { $0.id == message.id }) {
            return updatedMessage.providerName
        }
        return nil
    }
}

//Extensions
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
                // Information area：Code Language and Copy Button
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
                        // Special handling for diff language
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

// Extensions Theme for Diff
extension Theme {
    static let fancyWithDiff = fancy
        .codeBlock { configuration in
            VStack(alignment: .leading, spacing: 0) {
                // Code Language and Copy Button
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
                        // Diff Code
                        DiffCodeView(code: configuration.content)
                            .padding(.vertical, 8)
                            .padding(.leading, 14)
                    } else {
                        // Code Highlighter for other languages
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


// Define an OptionSet to specify which corners need to be rounded - similar to UIRectCorner
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomRight = RectCorner(rawValue: 1 << 2)
    static let bottomLeft = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

// Draw a shape with specified rounded corners
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

// View extension
extension View {
    func roundedCorners(radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornersShape(radius: radius, corners: corners))
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
    
    // Create a sample chat message
    let sampleMessage = ChatMessage(
        id: UUID().uuidString,
        ssid: "test-session",
        character: "ai", // AI message
        chat_title: "Sample Chat",
        chat_content: """
           Here's a code example in Swift:
           
           ```swift
           import SwiftUI
           
           struct ContentView: View {
               var body: some View {
                   Text("Hello, World!")
                       .padding()
               }
           }
           ```
           
           And here's an example using diff format:
           
           ```diff
           - let oldValue = "Previous text"
           + let newValue = "Updated text"
             let unchangedLine = "This line remains the same"
           ```
           """,
        thinking_content: "I'm considering various code examples that would be useful for a beginner Swift developer. A simple SwiftUI example seems appropriate.",
        isThinkingExpanded: true,
        imageUrl: "",
        sequence: 1,
        timestamp: Date(),
        username: "Test User",
        userid: UUID().uuidString,
        providerName: "OpenAI",
        modelName: "GPT-4"
    )
    
    // Create and configure ArtifactViewModel
    let artifactViewModel = ArtifactViewModel()
    
    return MessageView(
        message: sampleMessage,
        viewModel: chatViewModel,
        userFinishedInput: .constant(true),
        artifactViewModel: artifactViewModel
    )
    .frame(width: 600, height: 600) // Set a reasonable preview width
    .environmentObject(modelSettings)
    .environmentObject(LocalizationManager.shared)
}
