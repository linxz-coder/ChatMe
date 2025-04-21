// 1. 创建ArtifactViewModel.swift文件，但避免Color扩展冲突
//import SwiftUI
import Foundation
import WebKit

// 预览内容类型
enum ArtifactType: String {
    case html = "html"
    case css = "css"
    case javascript = "javascript"
    case unknown = "unknown"
}

// 代码块模型
struct CodeBlock: Identifiable {
    let id = UUID()
    let language: String
    let code: String
    var complete: Bool = true
    
    var artifactType: ArtifactType {
        switch language.lowercased() {
        case "html": return .html
        case "css": return .css
        case "js", "javascript": return .javascript
        default: return .unknown
        }
    }
}

// Artifact视图模型
class ArtifactViewModel: ObservableObject {
    @Published var codeBlocks: [CodeBlock] = []
    @Published var isActive: Bool = false
    @Published var activeTab: String = "preview"
    @Published var isPreviewEnabled: Bool = false // 新增：控制预览是否启用
    
    // 从消息内容中提取代码块
    func extractCodeBlocks(from message: String) {
        let regex = try! NSRegularExpression(pattern: "```(?:(html|css|js|javascript)?\\s*\\n)([\\s\\S]*?)(?:```|$)", options: [])
        let nsString = message as NSString
        let matches = regex.matches(in: message, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var extractedBlocks: [CodeBlock] = []
        
        for match in matches {
            let languageRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let language = languageRange.location != NSNotFound ? nsString.substring(with: languageRange) : "unknown"
            let code = codeRange.location != NSNotFound ? nsString.substring(with: codeRange).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let isComplete = match.range.location + match.range.length < nsString.length && nsString.substring(with: NSRange(location: match.range.location + match.range.length - 3, length: 3)) == "```"
            
            extractedBlocks.append(CodeBlock(
                language: language,
                code: code,
                complete: isComplete
            ))
        }
        
        if !extractedBlocks.isEmpty && extractedBlocks.contains(where: { $0.artifactType == .html }){
            DispatchQueue.main.async {
                self.codeBlocks = extractedBlocks
                self.isActive = true
                // 默认不启用预览，但代码块已准备好
                self.isPreviewEnabled = false
            }
        } else {
            DispatchQueue.main.async {
                self.codeBlocks = []
                self.isActive = false
                self.isPreviewEnabled = false
            }
        }
    }
    
    // 添加单个代码块
    func addCodeBlock(_ codeBlock: CodeBlock) {
        // 如果已经存在相同类型的代码块，则更新它
        if let index = codeBlocks.firstIndex(where: { $0.artifactType == codeBlock.artifactType }) {
            codeBlocks[index] = codeBlock
        } else {
            // 否则添加新代码块
            codeBlocks.append(codeBlock)
        }
        
        // 如果包含HTML代码块，激活ArtifactViewModel
        if codeBlocks.contains(where: { $0.artifactType == .html }) {
            isActive = true
        }
    }
    
    // 切换预览状态
    func togglePreview() {
        isPreviewEnabled.toggle()
    }
    
    // 构建HTML预览内容
    func buildPreviewContent() -> String {
        let html = codeBlocks.first(where: { $0.artifactType == .html })?.code ?? ""
        let css = codeBlocks.first(where: { $0.artifactType == .css })?.code ?? ""
        let js = codeBlocks.first(where: { $0.artifactType == .javascript })?.code ?? ""
        
        return """
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              \(css)
            </style>
          </head>
          <body>
            \(html)
            <script>
              \(js)
            </script>
          </body>
        </html>
        """
    }
    
    // 判断是否有可预览内容
    var hasPreviewableContent: Bool {
//        return codeBlocks.contains { $0.artifactType == .html || $0.artifactType == .swiftui }
        return codeBlocks.contains { $0.artifactType == .html }
    }
}
