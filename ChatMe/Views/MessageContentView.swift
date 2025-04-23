//
//  MessageContentView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/21.
//

import SwiftUI

// Message Content View (handles message expand/collapse logic)
struct MessageContentView: View {
    let content: String
    @Binding var isExpanded: Bool
    
    // Estimated threshold for message line count
    private let lineThreshold = 20
    private let charsPerLine = 40
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Estimated number of message lines
            let estimatedLineCount = (content.count + charsPerLine - 1) / charsPerLine
            
            if estimatedLineCount > lineThreshold && !isExpanded {
                // Folded state: Only shows part of the content
                let shortContent = String(content.prefix(lineThreshold * charsPerLine))
                Text(shortContent + "...")
                    .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                    .background(Color(light: Color(red: 242/255, green: 242/255, blue: 242/255),dark: Color(red: 0x32/255, green: 0x32/255, blue: 0x32/255)))
                    .cornerRadius(12)
                Button {
                    isExpanded = true
                } label: {
                    LocalizedText(key: "showFullMessages")
                }
                .font(.footnote)
                .foregroundColor(Color(light: .blue, dark: .cyan))
            } else {
                // Expanded state: Show all content
                Text(content)
                    .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                    .background(Color(light: Color(red: 242/255, green: 242/255, blue: 242/255),dark: Color(red: 0x32/255, green: 0x32/255, blue: 0x32/255)))
                    .cornerRadius(12)
                    .textSelection(.enabled)
                
                if estimatedLineCount > lineThreshold {
                    Button {
                        isExpanded = false
                    } label: {
                        LocalizedText(key: "collapse")
                    }
                    .font(.footnote)
                    .foregroundColor(Color(light: .blue, dark: .cyan))
                }
            }
        }
    }
}

#Preview {
    let longSampleContent = """
       This is a very long message content that will demonstrate the collapse/expand functionality of the MessageContentView component.
       
       The component is designed to automatically collapse messages that exceed a certain length threshold (currently set to 20 lines) to improve readability in the chat interface.
       
       When collapsed, the component shows a truncated version of the message followed by "..." and a "Show Full Message" button that allows the user to expand and view the entire content.
       
       When expanded, the component displays the entire message content and shows a "Collapse" button that allows the user to return to the collapsed view.
       
       This behavior is particularly useful for long messages that contain detailed explanations, code snippets, or extensive information that might otherwise dominate the chat interface.
       
       By implementing this collapsible behavior, we can maintain a cleaner chat UI while still allowing users to access the complete content when needed.
       
       The component also applies appropriate styling including text selection, background colors for both light and dark mode, and rounded corners to match the app's visual design language.
       
       To estimate whether a message exceeds the threshold, the component calculates an approximate line count based on the message length and an estimated average character count per line.
       
       While this estimation isn't perfect (as it doesn't account for varying character widths or line wrapping based on actual layout), it provides a reasonable heuristic for determining when to apply the collapse/expand behavior.
       
       For future improvements, we could consider implementing a more accurate line counting mechanism that takes into account the actual rendered text layout.
       """
    
    MessageContentView(content: longSampleContent, isExpanded: .constant(false))
    
        .frame(width: 800, height: 600)
        .environmentObject(LocalizationManager.shared)
}
