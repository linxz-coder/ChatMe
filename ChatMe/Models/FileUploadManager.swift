//
//  FileUploadManager.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/17.
//

import Foundation
import SwiftUI

// 支持的文件类型枚举
enum SupportedFileType: String, CaseIterable {
    case pdf = "pdf"
    case docx = "docx"
    case doc = "doc"
    case xls = "xls"
    case xlsx = "xlsx"
    case ppt = "ppt"
    case pptx = "pptx"
    case png = "png"
    case jpg = "jpg"
    case jpeg = "jpeg"
    case csv = "csv"
    case py = "py"
    case txt = "txt"
    case md = "md"
    case bmp = "bmp"
    case gif = "gif"
    
    // 获取所有支持的文件类型的UTI
    static var allUTIs: [String] {
        var utis: [String] = []
        for type in allCases {
            switch type {
            case .pdf:
                utis.append("com.adobe.pdf")
            case .docx:
                utis.append("org.openxmlformats.wordprocessingml.document")
            case .doc:
                utis.append("com.microsoft.word.doc")
            case .xls:
                utis.append("com.microsoft.excel.xls")
            case .xlsx:
                utis.append("org.openxmlformats.spreadsheetml.sheet")
            case .ppt:
                utis.append("com.microsoft.powerpoint.ppt")
            case .pptx:
                utis.append("org.openxmlformats.presentationml.presentation")
            case .png:
                utis.append("public.png")
            case .jpg, .jpeg:
                utis.append("public.jpeg")
            case .csv:
                utis.append("public.comma-separated-values-text")
            case .py:
                utis.append("public.python-script")
            case .txt:
                utis.append("public.plain-text")
            case .md:
                utis.append("net.daringfireball.markdown")
            case .bmp:
                utis.append("com.microsoft.bmp")
            case .gif:
                utis.append("com.compuserve.gif")
            }
        }
        return utis
    }
    
    // 根据文件UTI返回文件类型
    static func fromUTI(_ uti: String) -> SupportedFileType? {
        switch uti {
        case "com.adobe.pdf":
            return .pdf
        case "org.openxmlformats.wordprocessingml.document":
            return .docx
        case "com.microsoft.word.doc":
            return .doc
        case "com.microsoft.excel.xls":
            return .xls
        case "org.openxmlformats.spreadsheetml.sheet":
            return .xlsx
        case "com.microsoft.powerpoint.ppt":
            return .ppt
        case "org.openxmlformats.presentationml.presentation":
            return .pptx
        case "public.png":
            return .png
        case "public.jpeg":
            return .jpg
        case "public.comma-separated-values-text":
            return .csv
        case "public.python-script":
            return .py
        case "public.plain-text":
            return .txt
        case "net.daringfireball.markdown":
            return .md
        case "com.microsoft.bmp":
            return .bmp
        case "com.compuserve.gif":
            return .gif
        default:
            return nil
        }
    }
    
    // 是否是图片类型
    var isImage: Bool {
        switch self {
        case .png, .jpg, .jpeg, .bmp, .gif:
            return true
        default:
            return false
        }
    }
}

// 上传文件模型
struct UploadedFile: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let type: SupportedFileType
    var fileId: String? // 智谱AI返回的文件ID
    var isUploading: Bool = false
    var uploadProgress: Double = 0.0
    var errorMessage: String? = nil
    
    static func == (lhs: UploadedFile, rhs: UploadedFile) -> Bool {
        return lhs.id == rhs.id
    }
}

class FileUploadManager: ObservableObject {
    @Published var uploadedFiles: [UploadedFile] = []
    @Published var isUploading: Bool = false
    @Published var errorMessage: String? = nil
    
    // 单例模式
    static let shared = FileUploadManager()
    
    private init() {}
    
    // 检查文件大小是否符合要求
    private func validateFileSize(size: Int64, fileType: SupportedFileType) -> Bool {
        if fileType.isImage {
            // 图片限制5MB
            return size <= 5 * 1024 * 1024
        } else {
            // 其他文件限制50MB
            return size <= 50 * 1024 * 1024
        }
    }
    
    // 添加文件到列表
    func addFile(path: URL) {
        // 检查总文件数限制
        if uploadedFiles.count >= 100 {
            errorMessage = "文件数量已达上限(100个)"
            return
        }
        
        // 获取文件信息
        let fileName = path.lastPathComponent
        let fileExtension = path.pathExtension.lowercased()
        
        // 验证文件类型
        guard let fileType = SupportedFileType(rawValue: fileExtension) else {
            errorMessage = "不支持的文件类型: .\(fileExtension)"
            return
        }
        
        // 获取文件大小
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // 验证文件大小
            if !validateFileSize(size: fileSize, fileType: fileType) {
                if fileType.isImage {
                    errorMessage = "图片大小超过限制(5MB)"
                } else {
                    errorMessage = "文件大小超过限制(50MB)"
                }
                return
            }
            
            // 创建新文件对象并添加到列表
            let newFile = UploadedFile(
                name: fileName,
                path: path,
                size: fileSize,
                type: fileType
            )
            
            DispatchQueue.main.async {
                self.uploadedFiles.append(newFile)
                self.errorMessage = nil
            }
            
        } catch {
            errorMessage = "读取文件信息失败: \(error.localizedDescription)"
        }
    }
    
    // 移除文件
    func removeFile(at index: Int) {
        guard index < uploadedFiles.count else { return }
        
        DispatchQueue.main.async {
            self.uploadedFiles.remove(at: index)
        }
    }
    
    // 移除所有文件
    func removeAllFiles() {
        DispatchQueue.main.async {
            self.uploadedFiles.removeAll()
        }
    }
    
    // 上传文件到智谱AI
    func uploadFileToZhipuAI(file: UploadedFile, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 更新文件状态为上传中
        if let index = uploadedFiles.firstIndex(where: { $0.id == file.id }) {
            var updatedFile = uploadedFiles[index]
            updatedFile.isUploading = true
            uploadedFiles[index] = updatedFile
        }
        
        // 设置请求URL
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/files") else {
            if let index = uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = uploadedFiles[index]
                updatedFile.isUploading = false
                updatedFile.errorMessage = "无效的上传URL"
                uploadedFiles[index] = updatedFile
            }
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置Authorization头
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 设置Content-Type为multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var data = Data()
        
        // 添加purpose字段
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"purpose\"\r\n\r\n".data(using: .utf8)!)
        data.append("file-extract\r\n".data(using: .utf8)!) // 或者根据需要使用"batch"、"retrieval"等
        
        // 添加文件数据
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.name)\"\r\n".data(using: .utf8)!)
        
        // 设置文件类型
        let mimeType: String
        switch file.type {
        case .pdf:
            mimeType = "application/pdf"
        case .docx, .doc:
            mimeType = "application/msword"
        case .xls, .xlsx:
            mimeType = "application/vnd.ms-excel"
        case .ppt, .pptx:
            mimeType = "application/vnd.ms-powerpoint"
        case .png:
            mimeType = "image/png"
        case .jpg, .jpeg:
            mimeType = "image/jpeg"
        case .csv:
            mimeType = "text/csv"
        case .py, .txt, .md:
            mimeType = "text/plain"
        case .bmp:
            mimeType = "image/bmp"
        case .gif:
            mimeType = "image/gif"
        }
        
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        
        // 读取文件数据
        do {
            let fileData = try Data(contentsOf: file.path)
            data.append(fileData)
            data.append("\r\n".data(using: .utf8)!)
        } catch {
            if let index = uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                var updatedFile = uploadedFiles[index]
                updatedFile.isUploading = false
                updatedFile.errorMessage = "读取文件数据失败: \(error.localizedDescription)"
                uploadedFiles[index] = updatedFile
            }
            completion(.failure(error))
            return
        }
        
        // 添加结束标记
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 设置请求体
        request.httpBody = data
        
        // 打印请求详情以便调试
        print("上传文件: \(file.name)")
        print("URL: \(url.absoluteString)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Body大小: \(data.count) 字节")
        
        // 创建上传任务
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("上传错误: \(error.localizedDescription)")
                if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                    var updatedFile = self.uploadedFiles[index]
                    updatedFile.isUploading = false
                    updatedFile.errorMessage = "上传失败: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        self.uploadedFiles[index] = updatedFile
                    }
                }
                completion(.failure(error))
                return
            }
            
            // 打印响应状态和数据
            if let httpResponse = response as? HTTPURLResponse {
                print("响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                        var updatedFile = self.uploadedFiles[index]
                        updatedFile.isUploading = false
                        updatedFile.errorMessage = "服务器返回错误: \(httpResponse.statusCode)"
                        DispatchQueue.main.async {
                            self.uploadedFiles[index] = updatedFile
                        }
                    }
                    
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("服务器错误详情: \(errorString)")
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: ["message": errorString])))
                    } else {
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: nil)))
                    }
                    return
                }
            }
            
            // 解析响应数据
            guard let data = data else {
                print("没有返回数据")
                if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                    var updatedFile = self.uploadedFiles[index]
                    updatedFile.isUploading = false
                    updatedFile.errorMessage = "没有接收到响应数据"
                    DispatchQueue.main.async {
                        self.uploadedFiles[index] = updatedFile
                    }
                }
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            // 打印返回数据以便调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("响应数据: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 检查json结构，看id在哪个层级
                    if let fileId = json["id"] as? String {
                        // 直接在顶层
                        print("文件上传成功，ID: \(fileId)")
                        
                        if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                            var updatedFile = self.uploadedFiles[index]
                            updatedFile.isUploading = false
                            updatedFile.fileId = fileId
                            DispatchQueue.main.async {
                                self.uploadedFiles[index] = updatedFile
                            }
                        }
                        
                        completion(.success(fileId))
                    } else if let data = json["data"] as? [String: Any], let fileId = data["id"] as? String {
                        // 在data子对象中
                        print("文件上传成功，ID: \(fileId)")
                        
                        if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                            var updatedFile = self.uploadedFiles[index]
                            updatedFile.isUploading = false
                            updatedFile.fileId = fileId
                            DispatchQueue.main.async {
                                self.uploadedFiles[index] = updatedFile
                            }
                        }
                        
                        completion(.success(fileId))
                    } else {
                        // 找不到ID
                        print("无法从响应中找到文件ID")
                        print("完整响应: \(json)")
                        
                        if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                            var updatedFile = self.uploadedFiles[index]
                            updatedFile.isUploading = false
                            updatedFile.errorMessage = "解析响应失败，无法找到文件ID"
                            DispatchQueue.main.async {
                                self.uploadedFiles[index] = updatedFile
                            }
                        }
                        
                        completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": "无法从响应中找到文件ID"])))
                    }
                } else {
                    print("无法解析JSON响应")
                    
                    if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                        var updatedFile = self.uploadedFiles[index]
                        updatedFile.isUploading = false
                        updatedFile.errorMessage = "解析响应失败"
                        DispatchQueue.main.async {
                            self.uploadedFiles[index] = updatedFile
                        }
                    }
                    
                    let errorMessage = String(data: data, encoding: .utf8) ?? "无法解析响应数据"
                    completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": errorMessage])))
                }
            } catch {
                print("JSON解析错误: \(error.localizedDescription)")
                
                if let index = self.uploadedFiles.firstIndex(where: { $0.id == file.id }) {
                    var updatedFile = self.uploadedFiles[index]
                    updatedFile.isUploading = false
                    updatedFile.errorMessage = "解析响应失败: \(error.localizedDescription)"
                    DispatchQueue.main.async {
                        self.uploadedFiles[index] = updatedFile
                    }
                }
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 从智谱AI获取文件内容
    func getFileContent(fileId: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // 设置请求URL
        guard let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/files/\(fileId)/content") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // 设置Authorization头
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 打印请求信息用于调试
        print("获取文件内容请求:")
        print("URL: \(url.absoluteString)")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print("获取文件内容错误: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // 打印响应状态
            if let httpResponse = response as? HTTPURLResponse {
                print("文件内容响应状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("服务器错误详情: \(errorString)")
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: ["message": errorString])))
                    } else {
                        completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode, userInfo: nil)))
                    }
                    return
                }
            }
            
            // 解析响应数据
            guard let data = data else {
                print("没有返回文件内容数据")
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            // 打印部分返回数据以便调试
            if let responsePreview = String(data: data.prefix(200), encoding: .utf8) {
                print("文件内容响应预览: \(responsePreview)...")
            }
            
            do {
                // 尝试解析为JSON
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 直接尝试获取content字段
                    if let content = json["content"] as? String {
                        print("成功获取文件内容")
                        completion(.success(content))
                        return
                    }
                    
                    // 尝试从data字段中获取content
                    if let dataObj = json["data"] as? [String: Any],
                       let content = dataObj["content"] as? String {
                        print("成功从data字段获取文件内容")
                        completion(.success(content))
                        return
                    }
                    
                    // 如果找不到content字段，返回整个JSON作为字符串
                    print("未找到标准content字段，返回完整JSON")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        completion(.success(jsonString))
                    } else {
                        completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": "无法从响应中获取文件内容"])))
                    }
                } else {
                    // 如果不是JSON，尝试直接作为文本返回
                    if let content = String(data: data, encoding: .utf8) {
                        print("响应不是JSON格式，作为文本返回")
                        completion(.success(content))
                    } else {
                        completion(.failure(NSError(domain: "ParseError", code: -1, userInfo: ["message": "无法解析响应数据"])))
                    }
                }
            } catch {
                print("解析文件内容错误: \(error.localizedDescription)")
                
                // 如果JSON解析失败，尝试作为纯文本返回
                if let content = String(data: data, encoding: .utf8) {
                    print("JSON解析失败，作为纯文本返回")
                    completion(.success(content))
                } else {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
}
