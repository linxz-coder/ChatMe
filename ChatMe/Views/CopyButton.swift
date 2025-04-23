//
//  CopyButton.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/11.
//

import SwiftUI
import MarkdownUI

// Copy Button Component
struct CopyButton: View {
    let code: String
    @State private var isCopied = false
    
    var body: some View {
        Button {
            copyToClipboard(code)
        } label: {
            HStack(spacing: 1) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                if isCopied {
                    LocalizedText(key: "copied")
                        .font(.system(size: 12))
                } else {
                    LocalizedText(key: "copy")
                        .font(.system(size: 12))
                }
            }
            .padding(6)
            .background(Color(light: .white.opacity(0.9), dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(light: Color.gray.opacity(0.2), dark: Color.gray.opacity(0.4)), lineWidth: 1)
            )
            .shadow(color: Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.05)), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Copy code to the clipboard
    private func copyToClipboard(_ text: String) {
#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
#else
        UIPasteboard.general.string = text
#endif
        
        // show copied status
        withAnimation {
            isCopied = true
        }
        
        // 2 seconds later restore button status
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

#Preview {
    // sample diff code
    let sampleDiffCode = """
       diff --git a/src/components/Button.js b/src/components/Button.js
       index 8a4e9b5..3f21c67 100644
       --- a/src/components/Button.js
       +++ b/src/components/Button.js
       @@ -10,11 +10,14 @@ class Button extends Component {
         
         render() {
           const { onClick, className, children } = this.props;
       -    const buttonClass = className || 'default-btn';
       +    const buttonClass = className || 'primary-btn';
           
           return (
       -      <button className={buttonClass} onClick={onClick}>
       -        {children}
       -      </button>
       +      <button 
       +        className={buttonClass} 
       +        onClick={onClick}
       +        aria-label={this.props.label || 'Button'}>
       +          {children}
       +      </button>
           );
         }
       """
    CopyButton(code: sampleDiffCode)
        .environmentObject(LocalizationManager.shared)
        .frame(width: 300, height: 300)
}
