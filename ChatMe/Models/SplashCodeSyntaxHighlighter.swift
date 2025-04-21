import MarkdownUI
import Splash
import SwiftUI

struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let theme: Splash.Theme  // 存储主题
    
    init(theme: Splash.Theme) {
        self.theme = theme
    }
    
    func highlightCode(_ content: String, language: String?) -> Text {
        guard let language = language else {
            return Text(content)
        }
        
        print("高亮代码语言: \(language)")
        
        // HTML注释预处理
        var processedContent = content
        if ["html", "xml", "xhtml", "svg"].contains(language.lowercased()) {
            // 使用正则表达式查找所有HTML注释
            processedContent = preprocessHTMLComments(content)
        }
        
        
        // 根据语言选择不同的Grammar
        let grammar: Grammar
        switch language.lowercased() {
        case "html", "xml", "xhtml", "svg", "css", "javascript":
            grammar = HTMLGrammar()
        default:
            grammar = SwiftGrammar()
        }
        
        // 创建一个新的高亮器，使用选定的语法
        let syntaxHighlighter = SyntaxHighlighter(
            format: TextOutputFormat(theme: theme),
            grammar: grammar
        )
        
        return syntaxHighlighter.highlight(processedContent)
    }
    
    // 预处理HTML注释，确保它们被视为单个单元
    private func preprocessHTMLComments(_ html: String) -> String {
        // 简单的实现：用特殊标记替换注释，以便它们被视为单个token
        let pattern = "<!--[\\s\\S]*?-->"
        let regex = try? NSRegularExpression(pattern: pattern)
        
        guard let regex = regex else { return html }
        
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let modifiedString = regex.stringByReplacingMatches(
            in: html,
            options: [],
            range: range,
            withTemplate: "<!---COMMENT-PLACEHOLDER--->"
        )
        
        return modifiedString
    }
}

extension CodeSyntaxHighlighter where Self == SplashCodeSyntaxHighlighter {
    static func splash(theme: Splash.Theme) -> Self {
        SplashCodeSyntaxHighlighter(theme: theme)
    }
}
