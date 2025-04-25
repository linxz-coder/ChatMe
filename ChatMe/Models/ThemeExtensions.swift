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
    /// Create a theme that matches the dark theme of VS Code.
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
                .keyword: Color(red: 0.733, green: 0.486, blue: 0.843, alpha: 1.0),  // Keyword purple
                .string: Color(red: 0.867, green: 0.553, blue: 0.165, alpha: 1.0),   // String Orange
                .type: Color(red: 0.455, green: 0.678, blue: 0.914, alpha: 1.0),     // Type Blue
                .call: Color(red: 215/255, green: 202/255, blue: 134/255, alpha: 1.0),           // FunctionCall Yellow
                .number: Color(red: 0.486, green: 0.733, blue: 0.0, alpha: 1.0),     // Number Green
                .comment: Color(red: 0.467, green: 0.467, blue: 0.467, alpha: 1.0),  // Comment Gray
                .property: Color(red: 0.455, green: 0.678, blue: 0.914, alpha: 1.0), // Property Blue
                .dotAccess: Color(red: 0.455, green: 0.678, blue: 0.914, alpha: 1.0),// DotAccess Blue
                .preprocessing: Color(red: 0.733, green: 0.486, blue: 0.843, alpha: 1.0), // Preprocessing Purple
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
