//
//  ChatService.swift
//  ChatMe
//
//  Created by 林晓中 on 2024/3/10.
//

import Foundation
import Combine

class ChatService {
    
    // API基础URL
    private let baseURL = "http://127.0.0.1:5001"  // 替换为你的Python API服务器地址
    
    // 创建URLSession，可以配置代理等
    private func createURLSession(with configuration: URLSessionConfiguration? = nil) -> URLSession {
        if let config = configuration {
            return URLSession(configuration: config)
        } else {
            return URLSession.shared
        }
    }
    
    // 添加聊天消息
    func addMessage(message: ChatMessage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/messages") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // 构建请求数据
        let requestData: [String: Any] = [
            "ssid": message.ssid.uuidString,
            "character": message.character,
            "chat_title": message.chat_title,
            "chat_content": message.chat_content,
            "thinking_content": message.thinking_content,
            "is_thinking_expanded": message.isThinkingExpanded ? 1 : 0,
            "image_url": message.imageUrl,
            "sequence": message.sequence,
            "username": message.username,
            "userid": message.userid.uuidString,
            "provider_name": ModelSettingsData.shared.selectedModel?.providerName ?? "",
            "model_name": ModelSettingsData.shared.selectedModel?.name ?? ""
        ]
        
        // 将请求数据转换为JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(.failure(NSError(domain: "JSONSerializationError", code: -2, userInfo: nil)))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let messageId = json["message_id"] as? String {
                    completion(.success(messageId))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 获取会话的所有消息
    func getMessages(forSession sessionId: UUID, completion: @escaping (Result<[ChatMessage], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/sessions/\(sessionId.uuidString)/messages") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            

            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let messagesData = json["messages"] as? [[String: Any]] {
                    
                    let messages = messagesData.compactMap { messageDict -> ChatMessage? in
                        guard let id = messageDict["id"] as? String,
                              let ssidString = messageDict["ssid"] as? String,
                              let ssid = UUID(uuidString: ssidString),
                              let character = messageDict["character"] as? String,
                              let chatTitle = messageDict["chat_title"] as? String,
                              let chatContent = messageDict["chat_content"] as? String,
                              let sequence = messageDict["sequence"] as? Int,
                              let timeString = messageDict["timestamp"] as? String,
                              let username = messageDict["username"] as? String,
                              let useridString = messageDict["userid"] as? String,
                              let userid = UUID(uuidString: useridString) else {
                            return nil
                        }
                        
                        
                        // 创建一个日期格式化器用于解析ISO日期
                        let dateFormatter = ISO8601DateFormatter()
                        let timestamp = dateFormatter.date(from: timeString) ?? Date()
                        
                        // 创建消息对象
                        var message = ChatMessage(
                            ssid: ssid,
                            character: character,
                            chat_title: chatTitle,
                            chat_content: chatContent,
                            sequence: sequence,
                            timestamp: timestamp,
                            username: username,
                            userid: userid
                        )
                        
                        // 设置ID
                        message.id = UUID(uuidString: id) ?? UUID()
                        
                        // 设置思考内容和展开状态（如果有）
                        if let thinkingContent = messageDict["thinking_content"] as? String {
                            message.thinking_content = thinkingContent
                        }
                        
                        if let isThinkingExpanded = messageDict["is_thinking_expanded"] as? Int {
                            message.isThinkingExpanded = isThinkingExpanded == 1
                        }
                        
                                   // 设置图片URL（如果有）
                                   if let imageUrl = messageDict["image_url"] as? String {
                                       message.imageUrl = imageUrl
                                   }
                        
                        //检索供应商名字，以确定图标
                        if let providerName = messageDict["provider_name"] as? String {
                            message.providerName = providerName
                        }

                        if let modelName = messageDict["model_name"] as? String {
                            message.modelName = modelName
                        }
                        
                        return message
                    }
                    
                    completion(.success(messages))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 获取会话列表，限制获取1000个会话
    func getSessions(forUser userId: UUID? = nil, limit: Int = 1000, completion: @escaping (Result<[ChatSession], Error>) -> Void) {
        var urlString = "\(baseURL)/api/sessions?limit=\(limit)"
        if let userId = userId {
            urlString += "&userid=\(userId.uuidString)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let sessionsData = json["sessions"] as? [[String: Any]] {
                    
                    let sessions = sessionsData.compactMap { sessionDict -> ChatSession? in
                        guard let ssidString = sessionDict["ssid"] as? String,
                              let ssid = UUID(uuidString: ssidString),
                              let title = sessionDict["chat_title"] as? String,
                              let createdTimeString = sessionDict["created_time"] as? String,
                              let username = sessionDict["username"] as? String,
                              let useridString = sessionDict["userid"] as? String,
                              let userid = UUID(uuidString: useridString) else {
                            return nil
                        }
                        
                        // 创建一个日期格式化器用于解析ISO日期
                        let dateFormatter = ISO8601DateFormatter()
                        let timestamp = dateFormatter.date(from: createdTimeString) ?? Date()
                        
                        // 创建会话对象
                        return ChatSession(
                            id: ssid,
                            title: title,
                            messages: [],  // 初始为空，如果需要消息可以另外请求
                            timestamp: timestamp,
                            username: username,
                            userid: userid
                        )
                    }
                    
                    completion(.success(sessions))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 更新会话标题
    func updateSessionTitle(sessionId: UUID, newTitle: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/sessions/\(sessionId.uuidString)/title") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // 构建请求数据
        let requestData = ["title": newTitle]
        
        // 将请求数据转换为JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            completion(.failure(NSError(domain: "JSONSerializationError", code: -2, userInfo: nil)))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    completion(.success(true))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    
    // 搜索消息内容
    func searchMessages(query: String, userId: UUID? = nil, completion: @escaping (Result<[ChatMessage], Error>) -> Void) {
        var urlString = "\(baseURL)/api/messages/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let userId = userId {
            urlString += "&userid=\(userId.uuidString)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let messagesData = json["messages"] as? [[String: Any]] {
                    
                    let messages = messagesData.compactMap { messageDict -> ChatMessage? in
                        guard let id = messageDict["id"] as? String,
                              let ssidString = messageDict["ssid"] as? String,
                              let ssid = UUID(uuidString: ssidString),
                              let character = messageDict["character"] as? String,
                              let chatTitle = messageDict["chat_title"] as? String,
                              let chatContent = messageDict["chat_content"] as? String,
                              let sequence = messageDict["sequence"] as? Int,
                              let timeString = messageDict["timestamp"] as? String,
                              let username = messageDict["username"] as? String,
                              let useridString = messageDict["userid"] as? String,
                              let userid = UUID(uuidString: useridString) else {
                            return nil
                        }
                        
                        let dateFormatter = ISO8601DateFormatter()
                        let timestamp = dateFormatter.date(from: timeString) ?? Date()
                        
                        var message = ChatMessage(
                            ssid: ssid,
                            character: character,
                            chat_title: chatTitle,
                            chat_content: chatContent,
                            sequence: sequence,
                            timestamp: timestamp,
                            username: username,
                            userid: userid
                        )
                        
                        message.id = UUID(uuidString: id) ?? UUID()
                        
                        if let thinkingContent = messageDict["thinking_content"] as? String {
                            message.thinking_content = thinkingContent
                        }
                        
                        if let isThinkingExpanded = messageDict["is_thinking_expanded"] as? Int {
                            message.isThinkingExpanded = isThinkingExpanded == 1
                        }
                        
                        return message
                    }
                    
                    completion(.success(messages))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 搜索会话
    func searchSessions(query: String, userId: UUID? = nil, completion: @escaping (Result<[ChatSession], Error>) -> Void) {
        var urlString = "\(baseURL)/api/sessions/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let userId = userId {
            urlString += "&userid=\(userId.uuidString)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let sessionsData = json["sessions"] as? [[String: Any]] {
                    
                    let sessions = sessionsData.compactMap { sessionDict -> ChatSession? in
                        guard let ssidString = sessionDict["ssid"] as? String,
                              let ssid = UUID(uuidString: ssidString),
                              let title = sessionDict["chat_title"] as? String,
                              let createdTimeString = sessionDict["created_time"] as? String,
                              let username = sessionDict["username"] as? String,
                              let useridString = sessionDict["userid"] as? String,
                              let userid = UUID(uuidString: useridString) else {
                            return nil
                        }
                        
                        let dateFormatter = ISO8601DateFormatter()
                        let timestamp = dateFormatter.date(from: createdTimeString) ?? Date()
                        
                        return ChatSession(
                            id: ssid,
                            title: title,
                            messages: [],
                            timestamp: timestamp,
                            username: username,
                            userid: userid
                        )
                    }
                    
                    completion(.success(sessions))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 删除会话
    func deleteSession(sessionId: UUID, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/sessions/\(sessionId.uuidString)") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // 创建DELETE请求
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoDataReturned", code: -3, userInfo: nil)))
                return
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    completion(.success(true))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: -4, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}
