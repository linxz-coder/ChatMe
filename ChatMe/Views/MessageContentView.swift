//
//  MessageContentView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/21.
//

import SwiftUI

// 消息内容视图（处理消息展开/折叠逻辑）
struct MessageContentView: View {
    let content: String
    @Binding var isExpanded: Bool
    
    // 估计消息行数的阈值
    private let lineThreshold = 20
    private let charsPerLine = 40
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // 估计消息行数
            let estimatedLineCount = (content.count + charsPerLine - 1) / charsPerLine
            
            if estimatedLineCount > lineThreshold && !isExpanded {
                // 折叠状态：只显示部分内容
                let shortContent = String(content.prefix(lineThreshold * charsPerLine))
                Text(shortContent + "...")
                    .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                                    .background(Color(light: Color(red: 242/255, green: 242/255, blue: 242/255),dark: Color(red: 0x32/255, green: 0x32/255, blue: 0x32/255)))
                    .cornerRadius(12)
                
                Button("查看完整消息") {
                    isExpanded = true
                }
                .font(.footnote)
                .foregroundColor(Color(light: .blue, dark: .cyan))
            } else {
                // 展开状态：显示全部内容
                Text(content)
                    .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
                    .background(Color(light: Color(red: 242/255, green: 242/255, blue: 242/255),dark: Color(red: 0x32/255, green: 0x32/255, blue: 0x32/255)))
                    .cornerRadius(12)
                    .textSelection(.enabled)
                
                if estimatedLineCount > lineThreshold {
                    Button("折叠消息") {
                        isExpanded = false
                    }
                    .font(.footnote)
                    .foregroundColor(Color(light: .blue, dark: .cyan))
                }
            }
        }
    }
}

//#Preview {
//    MessageContentView()
//}
