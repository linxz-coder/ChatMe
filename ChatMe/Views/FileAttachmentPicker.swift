//
//  FileAttachmentPicker.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/17.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileAttachmentPicker: View {
    @ObservedObject var fileManager = FileUploadManager.shared
    @State private var showFilePicker = false
    
    var body: some View {
        VStack {
            // 文件选择器按钮
            Button {
                showFilePicker = true
            } label: {
                Label{
                    LocalizedText(key: "chooseFiles").font(.subheadline)
                } icon: {
                    Image(systemName: "doc.badge.plus")
                }
                
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: SupportedFileType.allCases.compactMap { type in
                    UTType(filenameExtension: type.rawValue)
                },
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        // 获取安全访问权限
                        if url.startAccessingSecurityScopedResource() {
                            fileManager.addFile(path: url)
                            url.stopAccessingSecurityScopedResource()
                        } else {
                            fileManager.errorMessage = "无法访问文件: \(url.lastPathComponent)"
                        }
                    }
                case .failure(let error):
                    fileManager.errorMessage = "选择文件失败: \(error.localizedDescription)"
                }
            }
            
            // 显示错误信息
            if let errorMessage = fileManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
            
            // 显示已选文件列表
            if !fileManager.uploadedFiles.isEmpty {
                UploadedFilesList()
            }
        }
    }
}

// 已上传文件列表视图
struct UploadedFilesList: View {
    @ObservedObject var fileManager = FileUploadManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已选文件")
                    .font(.headline)
                
                Spacer()
                
                // 清空按钮
                Button {
                    fileManager.removeAllFiles()
                } label: {
                    Text("清空")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            
            // 文件列表
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(fileManager.uploadedFiles.indices, id: \.self) { index in
                        let file = fileManager.uploadedFiles[index]
                        FileItemView(file: file, index: index)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
        .padding(.vertical, 8)
//        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
        
                .background(Color(light: Color(red: 0.95, green: 0.95, blue: 0.95),
                                 dark: Color(red: 0.25, green: 0.25, blue: 0.27)))
        .cornerRadius(8)
    }
}

// 单个文件项视图
struct FileItemView: View {
    let file: UploadedFile
    let index: Int
    @ObservedObject var fileManager = FileUploadManager.shared
    
    // 获取文件大小的易读格式
    private var formattedSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: file.size)
    }
    
    // 获取文件图标
    private var fileIcon: String {
        switch file.type {
        case .pdf:
            return "doc.fill"
        case .docx, .doc:
            return "doc.text.fill"
        case .xls, .xlsx:
            return "tablecells.fill"
        case .ppt, .pptx:
            return "chart.bar.doc.horizontal.fill"
        case .png, .jpg, .jpeg, .bmp, .gif:
            return "photo.fill"
        case .csv:
            return "list.bullet.rectangle.fill"
        case .py:
            return "chevron.left.forwardslash.chevron.right"
        case .txt, .md:
            return "doc.plaintext.fill"
        }
    }
    
    // 根据文件类型获取图标颜色
    private var iconColor: Color {
        switch file.type {
        case .pdf:
            return .red
        case .docx, .doc:
            return .blue
        case .xls, .xlsx:
            return .green
        case .ppt, .pptx:
            return .orange
        case .png, .jpg, .jpeg, .bmp, .gif:
            return .purple
        case .csv:
            return .gray
        case .py:
            return .yellow
        case .txt, .md:
            return .secondary
        }
    }
    
    var body: some View {
        HStack {
            // 文件图标
            Image(systemName: fileIcon)
                .foregroundColor(iconColor)
            
            // 文件名和大小
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack {
                    Text(formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 显示文件状态
                    if file.isUploading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(width: 12, height: 12)
                    } else if file.fileId != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else if let errorMessage = file.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // 删除按钮
            Button {
                fileManager.removeFile(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
//        .background(Color.white)
                .background(Color(light: .white, dark: Color(red: 0.3, green: 0.3, blue: 0.32)))
                .foregroundColor(Color(light: .primary, dark: .white))
        .cornerRadius(4)
    }
}

#Preview {
    FileAttachmentPicker()
}
