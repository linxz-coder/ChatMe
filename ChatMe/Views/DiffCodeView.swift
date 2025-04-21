//
//  DiffCodeView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/20.
//

import SwiftUI
import MarkdownUI

// 专门用于渲染diff格式代码的视图组件
struct DiffCodeView: View {
    let code: String
    // 缓存属性字符串以提高性能
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
                
                // 根据行内容设置颜色
                if line.hasPrefix("+") {
                    lineAttr.foregroundColor = Color(red: 0.514, green: 0.716, blue: 0.431, opacity: 1.0)
                } else if line.hasPrefix("-") {
                    lineAttr.foregroundColor = Color(red: 0.867, green: 0.553, blue: 0.165)
                } else {
                    lineAttr.foregroundColor = Color(red: 0.9, green: 0.9, blue: 0.9)
                }
                
                result.append(lineAttr)
                
                // 不在最后一行添加换行符
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
            // 添加行 - 绿色
            return Color(red: 0.514, green: 0.716, blue: 0.431, opacity: 1.0)
        } else if line.hasPrefix("-") {
            // 删除行 - 橙色
            return Color(red: 0.867, green: 0.553, blue: 0.165)
        } else {
            // 普通行 - 白色
            return Color(red: 0.9, green: 0.9, blue: 0.9)
        }
    }
}
