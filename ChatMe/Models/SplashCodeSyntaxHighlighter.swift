import MarkdownUI
import Splash
import SwiftUI

struct SplashCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    private let theme: Splash.Theme  // Save theme
    
    init(theme: Splash.Theme) {
        self.theme = theme
    }
    
    func highlightCode(_ content: String, language: String?) -> Text {
        guard let language = language else {
            return Text(content)
        }
        
        print("Hightlight code language: \(language)")
        
        // HTML Comment Preprocessing
        var processedContent = content
        if ["html", "xml", "xhtml", "svg"].contains(language.lowercased()) {
            // Use regular expressions to find all HTML comments
            processedContent = preprocessHTMLComments(content)
        }
        
        
        // Choose different Grammar based on language
        let grammar: Grammar
        switch language.lowercased() {
        case "html", "xml", "xhtml", "svg", "css", "javascript":
            grammar = HTMLGrammar()
        default:
            grammar = SwiftGrammar()
        }
        
        // Create a new highlighter using the selected syntax
        let syntaxHighlighter = SyntaxHighlighter(
            format: TextOutputFormat(theme: theme),
            grammar: grammar
        )
        
        return syntaxHighlighter.highlight(processedContent)
    }
    
    // Preprocess HTML comments to ensure they are treated as a single unit.
    private func preprocessHTMLComments(_ html: String) -> String {
        // Simple implementation: Replace annotations with special tags so that they are treated as a single token
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
