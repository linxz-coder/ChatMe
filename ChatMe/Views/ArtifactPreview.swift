//
//  ArtifactPreview.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/12.
//

import SwiftUI

// Code Highlight View
struct CodeHighlightView: View {
    let codeBlock: CodeBlock
    
    var body: some View {
        ScrollView {
            Text(codeBlock.code)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// Artifact preview component
struct ArtifactPreview: View {
    @ObservedObject var viewModel: ArtifactViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(["preview", "html", "css", "javascript"], id: \.self) { tab in
                    if hasTab(tab) {
                        Button(action: {
                            viewModel.activeTab = tab
                        }) {
                            Text(tab.uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .background(viewModel.activeTab == tab ? Color(NSColor.gray).opacity(0.3) : Color.clear)
                        .cornerRadius(5)
                    }
                }
                Spacer()
                
                // Add preview control button
                if viewModel.activeTab == "preview" && viewModel.hasPreviewableContent {
                    PreviewButton(viewModel: viewModel)
                }
            }
            .padding(10)
            .background(Color(NSColor.lightGray).opacity(0.1))
            
            // Content Area
            Group {
                if viewModel.activeTab == "preview" && viewModel.hasPreviewableContent {
                    if hasHTMLContent() {
                        WebView(htmlContent: viewModel.buildPreviewContent())
                    }
                } else {
                    if let codeBlock = getCodeBlockForTab(viewModel.activeTab) {
                        CodeHighlightView(codeBlock: codeBlock)
                    } else {
                        Text("没有可用的\(viewModel.activeTab)代码")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Determine if there is a specific type of tab
    private func hasTab(_ tab: String) -> Bool {
        if tab == "preview" {
            return viewModel.hasPreviewableContent
        }
        
        let type = ArtifactType(rawValue: tab) ?? .unknown
        return viewModel.codeBlocks.contains { $0.artifactType == type }
    }
    
    // Retrieve HTML content
    private func hasHTMLContent() -> Bool {
        return viewModel.codeBlocks.contains { $0.artifactType == .html }
    }
    
    // Obtain specific types of code
    private func getCodeForType(_ type: ArtifactType) -> String {
        return viewModel.codeBlocks.first { $0.artifactType == type }?.code ?? ""
    }
    
    // Retrieve the code block corresponding to the current tag
    private func getCodeBlockForTab(_ tab: String) -> CodeBlock? {
        let type = ArtifactType(rawValue: tab) ?? .unknown
        return viewModel.codeBlocks.first { $0.artifactType == type }
    }
}


#Preview{
    let viewModel = ArtifactViewModel()
    // Add sample HTML code
    let htmlCodeBlock = CodeBlock(
        language: "html",
        code: """
           <!DOCTYPE html>
           <html>
           <head>
               <style>
                   body { 
                       font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                       margin: 20px;
                       line-height: 1.5;
                   }
                   h1 { color: #0066cc; }
                   .container { 
                       padding: 15px;
                       border-radius: 8px;
                       background-color: #f2f2f7;
                   }
               </style>
           </head>
           <body>
               <div class="container">
                   <h1>Artifact Preview</h1>
                   <p>This is an HTML preview example used to test the functionality of the ArtifactPreview component.</p>
                   <ul>
                       <li>HTML Preview</li>
                       <li>Code highlighting</li>
                       <li>Multi-tab switching</li>
                   </ul>
               </div>
           </body>
           </html>
           """
    )
    
    // CSS Code Sample
    let cssCodeBlock = CodeBlock(
        language: "css",
        code: """
           body {
               font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, 
                            Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
               background-color: #f5f5f7;
               color: #333;
               line-height: 1.6;
           }
           
           .container {
               max-width: 1200px;
               margin: 0 auto;
               padding: 20px;
               box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
               border-radius: 8px;
               background-color: white;
           }
           
           @media (max-width: 768px) {
               .container {
                   padding: 10px;
               }
           }
           """
    )
    
    // JavaScript Code Sample
    let jsCodeBlock = CodeBlock(
        language: "javascript",
        code: """
           
           function initApp() {
               const app = document.getElementById('app');
               
               
               document.addEventListener('DOMContentLoaded', () => {
                   console.log('应用已初始化');
                   setupEventListeners();
               });
               
               
               function setupEventListeners() {
                   const buttons = document.querySelectorAll('.action-button');
                   buttons.forEach(button => {
                       button.addEventListener('click', handleButtonClick);
                   });
               }
               
               
               function handleButtonClick(event) {
                   const buttonId = event.target.id;
                   console.log(`按钮 ${buttonId} 被点击了`);
                   
                   
                   if (buttonId === 'save-button') {
                       saveData();
                   } else if (buttonId === 'load-button') {
                       loadData();
                   }
               }
           }
           
           
           initApp();
           """
    )
    
    // Correctly return View
    return ArtifactPreview(viewModel: {
        viewModel.codeBlocks = [htmlCodeBlock, cssCodeBlock, jsCodeBlock]
        viewModel.activeTab = "preview"
        return viewModel
    }())
}
