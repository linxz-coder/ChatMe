//
//  ArtifactMessageView.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/12.
//
import SwiftUI
import MarkdownUI

struct ArtifactMessageView: View {
    let message: ChatMessage //Must be at the front
    @ObservedObject var viewModel: ChatViewModel
    @Binding var userFinishedInput: Bool
    @ObservedObject var artifactViewModel: ArtifactViewModel
    
    var body: some View {
        if message.character == "user" {
            // 用户消息
            MessageView(
                message: message,
                viewModel: viewModel,
                userFinishedInput: $userFinishedInput,
                artifactViewModel: artifactViewModel
            )
        } else {
            // AI消息
            VStack(alignment: .leading, spacing: 0) {
                MessageView(
                    message: message,
                    viewModel: viewModel,
                    userFinishedInput: $userFinishedInput,
                    artifactViewModel: artifactViewModel
                )
                
                // 分析消息中的代码块
                .onAppear {
                    if message.character == "ai" {
                        artifactViewModel.extractCodeBlocks(from: message.chat_content)
                    }
                }
                .onChange(of: message.chat_content) { _ in
                    if message.character == "ai" {
                        artifactViewModel.extractCodeBlocks(from: message.chat_content)
                    }
                }
            }
        }
    }
}
