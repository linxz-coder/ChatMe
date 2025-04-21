//
//  CopyButton.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/11.
//

import SwiftUI
import MarkdownUI

// 复制按钮组件
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
                
                Text(isCopied ? "已复制" : "复制")
                    .font(.system(size: 12))
            }
            .padding(6)
//            .background(Color.white.opacity(0.9))
            .background(Color(light: .white.opacity(0.9), dark: Color(red: 0x18/255, green: 0x18/255, blue: 0x18/255)))
//            .background(Color(light: Color.white.opacity(0.9), dark: Color.black.opacity(0.6)))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
//                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    .stroke(Color(light: Color.gray.opacity(0.2), dark: Color.gray.opacity(0.4)), lineWidth: 1)
            )
//            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            .shadow(color: Color(light: Color.black.opacity(0.1), dark: Color.white.opacity(0.05)), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 复制代码到剪贴板
    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        
        // 显示复制成功状态
        withAnimation {
            isCopied = true
        }
        
        // 2秒后恢复按钮状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
}

//#Preview {
//    CopyButton()
//}
