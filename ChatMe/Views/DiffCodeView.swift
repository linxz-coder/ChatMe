//
//  DiffCodeView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/20.
//

import SwiftUI
import MarkdownUI

// A view component specifically designed for rendering diff format code.
struct DiffCodeView: View {
    let code: String
    // Cache attribute string to improve performance
    @State private var attributedString: AttributedString?
    
    var body: some View {
        
        ScrollView(.horizontal, showsIndicators: false) {
            if let attributedText = attributedString {
                Text(attributedText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                ProgressView()
                    .onAppear {
                        createAttributedString()
                    }
            }
        }
    }
    
    private func createAttributedString() {
        DispatchQueue.global(qos: .userInitiated).async {
            let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            var result = AttributedString()
            
            for (index, line) in lines.enumerated() {
                var lineAttr = AttributedString(line)
                
                // According to row content to set color
                if line.hasPrefix("+") {
                    lineAttr.foregroundColor = Color(red: 0.514, green: 0.716, blue: 0.431, opacity: 1.0)
                } else if line.hasPrefix("-") {
                    lineAttr.foregroundColor = Color(red: 0.867, green: 0.553, blue: 0.165)
                } else {
                    lineAttr.foregroundColor = Color(red: 0.9, green: 0.9, blue: 0.9)
                }
                
                result.append(lineAttr)
                
                // Do not add a newline character at the end of the last line.
                if index < lines.count - 1 {
                    result.append(AttributedString("\n"))
                }
            }
            
            DispatchQueue.main.async {
                self.attributedString = result
            }
        }
    }
    
    
    private func lineColor(for line: String) -> Color {
        if line.hasPrefix("+") {
            // Add Row - Green
            return Color(red: 0.514, green: 0.716, blue: 0.431, opacity: 1.0)
        } else if line.hasPrefix("-") {
            // Delete Row - Orange
            return Color(red: 0.867, green: 0.553, blue: 0.165)
        } else {
            // unchanged - White
            return Color(red: 0.9, green: 0.9, blue: 0.9)
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
    
    
    
    DiffCodeView(code: sampleDiffCode)
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
        .cornerRadius(8)
        .padding()
}
