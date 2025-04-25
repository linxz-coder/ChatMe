//
//  WebView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/12.
//

import SwiftUI
import WebKit

// The WebView component is used to render HTML content.
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
