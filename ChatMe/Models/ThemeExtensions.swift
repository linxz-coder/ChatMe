//
//  ThemeExtensions.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/20.
//

import Foundation
import Splash

#if !os(Linux)
public extension Theme {
    /// 创建一个与VS Code深色主题匹配的主题
    static func vscodeDark(withFont font: Font) -> Theme {
        return Theme(
            font: font,
            plainTextColor: Color(
                red: 0.9,
                green: 0.9,
                blue: 0.9,
                alpha: 1.0
            ),
            tokenColors: [
                .keyword: Color(red: 0.733, green: 0.486, blue: 0.843, alpha: 1.0),  // 关键字颜色 紫色
                .string: Color(red: 0.867, green: 0.553, blue: 0.165, alpha: 1.0),   // 字符串颜色 橙色
                .type: Color(red: 0.455, green: 0.678, blue: 0.914, alpha: 1.0),     // 类型颜色 蓝色
                .call: Color(red: 215/255, green: 202/255, blue: 134/255, alpha: 1.0),           // 函数调用颜色 黄色
                .number: Color(red: 0.486, green: 0.733, blue: 0.0, alpha: 1.0),     // 数字颜色 绿色
                .comment: Color(red: 0.467, green: 0.467, blue: 0.467, alpha: 1.0),  // 注释颜色 灰色
                .property: Color(red: 0.455, green: 0.678, blue: 0.914, alpha: 1.0), // 属性颜色 蓝色
                .dotAccess: Color(red: 0.455, green: 0.678, blue: 0.914, alpha: 1.0),// 点访问颜色 蓝色
                .preprocessing: Color(red: 0.733, green: 0.486, blue: 0.843, alpha: 1.0), // 预处理颜色 紫色
            ],
            backgroundColor: Color(
                red: 0.15,
                green: 0.15,
                blue: 0.15,
                alpha: 1.0
            )
        )
    }
}
#endif
