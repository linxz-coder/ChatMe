//
//  WebView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/12.
//

import SwiftUI
import WebKit

// WebView组件用于渲染HTML内容
struct WebView: NSViewRepresentable {
    let htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
