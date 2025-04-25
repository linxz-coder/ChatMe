import Foundation
import WebKit

// Code Types
enum ArtifactType: String {
    case html = "html"
    case css = "css"
    case javascript = "javascript"
    case unknown = "unknown"
}

// CodeBlock struct
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

class ArtifactViewModel: ObservableObject {
    @Published var codeBlocks: [CodeBlock] = []
    @Published var isActive: Bool = false
    @Published var activeTab: String = "preview"
    @Published var isPreviewEnabled: Bool = false
    
    // Extract code blocks from the message content
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
                // Preview is set to false
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
    
    // Add Code Block
    func addCodeBlock(_ codeBlock: CodeBlock) {
        // If a code block of the same type already exists, update it.
        if let index = codeBlocks.firstIndex(where: { $0.artifactType == codeBlock.artifactType }) {
            codeBlocks[index] = codeBlock
        } else {
            // Or add new codeBlock
            codeBlocks.append(codeBlock)
        }
        
        // If contains HTML codeBlock, Activate ArtifactViewModel
        if codeBlocks.contains(where: { $0.artifactType == .html }) {
            isActive = true
        }
    }
    
    // Toggle Preview status
    func togglePreview() {
        isPreviewEnabled.toggle()
    }
    
    // HTML preview
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
    
    // Determine if there is any content that can be previewed
    var hasPreviewableContent: Bool {
        return codeBlocks.contains { $0.artifactType == .html }
    }
}
