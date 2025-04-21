//
//  MacTextEditorWithEnter.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/6.
//

import SwiftUI

struct MacTextEditorWithEnter: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
//        textView.backgroundColor = NSColor(red: 244/255, green: 244/255, blue: 245/255, alpha: 1)
         let dynamicColor = Color(light: Color(red: 244/255, green: 244/255, blue: 245/255),
                                 dark: Color(red: 38/255, green: 38/255, blue: 40/255))
         textView.backgroundColor = NSColor(dynamicColor)

        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        
        // 禁用默认的换行行为
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // 只有在文本不同时才更新，防止光标位置重置
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        
        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                // 检查是否按下了Shift键
                if event?.modifierFlags.contains(.shift) == true {
                    // 如果按下Shift+Enter，允许插入换行符
                    return false
                } else {
                    // 如果只按下Enter，发送消息
                    onSubmit()
                    return true
                }
            }
            return false
        }
    }
}
