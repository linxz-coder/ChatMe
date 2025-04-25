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
        
        let dynamicColor = Color(light: Color(red: 244/255, green: 244/255, blue: 245/255),
                                 dark: Color(red: 38/255, green: 38/255, blue: 40/255))
        textView.backgroundColor = NSColor(dynamicColor)
        
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        
        // Disable the default line break behavior
        textView.isAutomaticLinkDetectionEnabled = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Only update when the text is different, to prevent the cursor position from being reset
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
                // Check if the Shift key has been pressed
                if event?.modifierFlags.contains(.shift) == true {
                    // If Shift+Enter is pressed, it allows the insertion of a line break.
                    return false
                } else {
                    // If Enter is pressed, send the message
                    onSubmit()
                    return true
                }
            }
            return false
        }
    }
}
