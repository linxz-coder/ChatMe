//
//  HTMLGrammar.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/21.
//

import Foundation
import Splash

/// HTML语法解析器，用于解析HTML代码
public struct HTMLGrammar: Grammar {
    public var delimiters: CharacterSet
    public var syntaxRules: [SyntaxRule]
    
    public init() {
        var delimiters = CharacterSet.alphanumerics.inverted
        delimiters.remove("_")
        delimiters.remove("-")
        //        delimiters.remove(":")
        delimiters.remove("\"")
        delimiters.remove("'")
        delimiters.remove(".")
        delimiters.remove("#")
//        delimiters.remove(";")
//        delimiters.remove("(")
//        delimiters.remove(")")
        //        delimiters.remove("=")
        self.delimiters = delimiters
        
        syntaxRules = [
            // 注释规则放在最前面，确保注释内容不受其他规则影响
            CommentRule(),
            DocTypeRule(),
            // 数字和像素单位规则（绿色）
            NumberAndUnitRule(),
            // 标签符号规则（白色）
            TagSymbolRule(),

            // 属性值规则（橙色）- 需要在属性规则之前
            AttributeValueRule(),
            // 属性规则（蓝色）
            AttributeRule(),
            
            // 标签关键字规则（紫色）
            TagKeywordRule(),
            
            // CSS选择器规则（黄色）
            CssSelectorRule(),



            // 字符串规则
            StringRule()
        ]
    }
    
    public func isDelimiter(_ delimiterA: Character, mergableWith delimiterB: Character) -> Bool {
        switch (delimiterA, delimiterB) {
        case ("<", "/"), ("/", ">"), ("<", "!"), ("!", "-"), ("-", "-"), ("-", ">"):
            return true
        case ("<", _):
            return false
        case (">", _):
            return false
        case ("-", _), (_, "-"):
            // 特别处理连字符，避免将HTML注释拆分成多个token
            return false
        case ("=", _), (_, "="):
            // 等号作为一个独立的token，不与其他分隔符合并
            return false
        case (":", _), (_, ":"):
            // 冒号作为一个独立的token，不与其他分隔符合并
            return false
        default:
            return true
        }
    }
}

private extension HTMLGrammar {
    
    // HTML注释规则
    struct CommentRule: SyntaxRule {
        var tokenType: TokenType { return .comment }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            print("token: \(token)")
            
            // 尝试检测完整的注释或部分注释
            if token.hasPrefix("<!--") && token.hasSuffix("-->") {
                return true
            }
            
            // 开始部分的注释标记
            if token == "<!--" || token.hasPrefix("<!--") {
                return true
            }
            
            // 结束部分的注释标记
            if token == "-->" || token.hasSuffix("-->") {
                return true
            }
            
            // 注释内容
            let onSameLine = segment.tokens.onSameLine
            let hasOpenComment = onSameLine.contains { $0.hasPrefix("<!--") || $0 == "<!--" }
            let hasCloseComment = onSameLine.contains { $0.hasSuffix("-->") || $0 == "-->" }
            
            if hasOpenComment && !hasCloseComment {
                // 在开始标记之后，结束标记之前的所有内容都是注释
                if let openIndex = onSameLine.firstIndex(where: { $0.hasPrefix("<!--") || $0 == "<!--" }) {
                    let currentIndex = onSameLine.firstIndex(of: token) ?? 0
                    if currentIndex > openIndex {
                        return true
                    }
                }
            }
            
            
            return false
        }
    }
    
    // 标签符号规则（白色）
    struct TagSymbolRule: SyntaxRule {
        var tokenType: TokenType { return .custom("plain") }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 检查是否在注释内
            if isWithinComment(segment) {
                return false
            }
            
            if token == "<" || token == ">" || token == "/>" || token == "{" || token == "}" ||
                token == "</" || token == ":" || token == "[" || token == "]" || token == ";" || token == "];" {
                return true
            }
            
            // 单独处理等号
            if token == "=" {
                return true
            }
            
            return false
        }
        
        // 辅助方法：检查当前token是否在注释内
        private func isWithinComment(_ segment: Segment) -> Bool {
            // 在同一行中查找注释开始和结束标记
            let tokensBefore = segment.tokens.all.prefix(while: { $0 != segment.tokens.current })
            
            let hasOpenComment = tokensBefore.contains(where: {
                $0.hasPrefix("<!--") && !$0.hasSuffix("-->")
            })
            
            let hasCloseComment = tokensBefore.contains(where: {
                $0.hasSuffix("-->") && !$0.hasPrefix("<!--")
            })
            
            // 如果有开始标记但没有结束标记，则认为在注释内
            if hasOpenComment && !hasCloseComment {
                return true
            }
            
            // 检查当前行是否有<!--但没有-->
            let onSameLine = segment.tokens.onSameLine
            let hasOpenCommentOnLine = onSameLine.contains(where: { $0.contains("<!--") })
            let hasCloseCommentOnLine = onSameLine.contains(where: { $0.contains("-->") })
            
            if hasOpenCommentOnLine && !hasCloseCommentOnLine {
                // 检查当前token是否在注释开始之后
                if let openIndex = onSameLine.firstIndex(where: { $0.contains("<!--") }),
                   let currentIndex = onSameLine.firstIndex(of: segment.tokens.current),
                   currentIndex > openIndex {
                    return true
                }
            }
            
            return false
        }
    }
    
    // DOCTYPE规则（预处理标记）
    struct DocTypeRule: SyntaxRule {
        var tokenType: TokenType { return .preprocessing }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 确保它不是注释
            if token.hasPrefix("<!--") || token == "<!--" || token.contains("<!--") {
                return false
            }
            
            // 处理DOCTYPE声明
            //            if token.hasPrefix("<!DOCTYPE") || token == "<!DOCTYPE" {
            if token.hasPrefix("<!DOCTYPE") || token == "<!DOCTYPE" || token == "DOCTYPE" {
                return true
            }
            
            if token == "html" && segment.tokens.previous == "<!DOCTYPE" {
                return true
            }
            
            if segment.tokens.onSameLine.contains("<!DOCTYPE") && segment.tokens.onSameLine.first != ">" {
                return true
            }
            
            return false
        }
    }
    
    // 标签关键字规则（紫色）
    struct TagKeywordRule: SyntaxRule {
        var tokenType: TokenType { return .keyword }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 检查是否在注释内
            if isWithinComment(segment) {
                return false
            }
            
            // 检查是否在属性值内
            if isWithinAttributeValue(segment) {
                return false
            }
            
            // 标签名称，但去除<>符号
            if let previousToken = segment.tokens.previous {
                if previousToken == "<" {
                    return true
                }
                
                // 处理结束标签的情况
                if previousToken == "</" || previousToken.hasSuffix("</") {
                    return true
                }
            }
            
            // 处理没有空格的标签名
            if token.hasPrefix("<") && !token.hasPrefix("<!") && !token.hasPrefix("</") {
                // 排除标签符号，只匹配标签名称部分
                return false
            }
            
            // 处理中文标点后面跟着的结束标签
            if let previousToken = segment.tokens.previous,
               token.hasPrefix("/") && previousToken.hasSuffix("<") {
                return false
            }
            
            // 处理br的情况
            if token == "br" {
                return true
            }
            
            return false
        }
        
        // 辅助方法：检查当前token是否在注释内
        private func isWithinComment(_ segment: Segment) -> Bool {
            return false
        }
        
        // 辅助方法：检查是否在属性值内
        private func isWithinAttributeValue(_ segment: Segment) -> Bool {
            // 检查是否在引号内
            var openQuote = false
            var quoteChar: Character? = nil
            
            for token in segment.tokens.onSameLine.prefix(while: { $0 != segment.tokens.current }) {
                // 处理引号
                if token == "\"" || token == "'" {
                    if let qChar = quoteChar, qChar == token.first {
                        openQuote = !openQuote
                        if !openQuote {
                            quoteChar = nil
                        }
                    } else if !openQuote {
                        openQuote = true
                        quoteChar = token.first
                    }
                }
                
                // 处理包含引号的token
                for char in token {
                    if char == "\"" || char == "'" {
                        if let qChar = quoteChar, qChar == char {
                            openQuote = !openQuote
                            if !openQuote {
                                quoteChar = nil
                            }
                        } else if !openQuote {
                            openQuote = true
                            quoteChar = char
                        }
                    }
                }
            }
            
            return openQuote
        }
    }
    
    // 属性规则（蓝色）
    struct AttributeRule: SyntaxRule {
        var tokenType: TokenType { return .property }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 检查是否在注释内
            if isWithinComment(segment) {
                return false
            }
            
            
            // 属性名通常是独立的单词，后面跟着=
            if let nextToken = segment.tokens.next, nextToken == "=" {
                // 确保不是在标签名位置
                if let previousToken = segment.tokens.previous {
                    if previousToken != "<" && previousToken != "</" {
                        return true
                    }
                }
                else {
                    return true
                }
            }
            
            
            // 处理属性名和等号在同一个token的情况，如"class="
            if token.hasSuffix("=") && token != "=" {
                // 去掉末尾的等号，检查剩余部分是否为有效的属性名
                let attributeName = String(token.dropLast())
                if !attributeName.isEmpty && !attributeName.contains("<") && !attributeName.contains(">") {
                    // 只匹配属性名部分，不包含等号
                    return true
                }
            }
            
            // CSS属性（如margin, padding等）
            if isCssProperty(token) && !isWithinCssSelector(segment) {
                return true
            }
            
            
            return false
        }
        
        // 辅助方法：检查当前token是否为CSS属性
        private func isCssProperty(_ token: String) -> Bool {
            // 常见CSS属性列表
            let cssProperties = [
                "margin", "padding", "border", "color", "background", "font", "text",
                "width", "height", "display", "position", "top", "left", "right", "bottom",
                "flex", "grid", "box-sizing", "overflow", "z-index", "opacity", "transform",
                "transition", "animation", "align", "justify", "gap", "max-width", "min-width",
                "max-height", "min-height","box-shadow","perspective", "line-height", "outline", "cursor", "object-fit", "flex-wrap", "grid-template-columns", "list-style", "flex-direction"
            ]
            
            return cssProperties.contains(where: { token.hasPrefix($0) || token == $0 })
        }
        
        // 辅助方法：检查是否在CSS选择器内
        private func isWithinCssSelector(_ segment: Segment) -> Bool {
            // 在同一行检查是否存在{且在当前token之后
            if let tokenIndex = segment.tokens.onSameLine.firstIndex(where: { $0 == segment.tokens.current }),
               let openBraceIndex = segment.tokens.onSameLine.firstIndex(of: "{"),
               tokenIndex < openBraceIndex {
                return true
            }
            
            return false
        }
        
        // 辅助方法：检查当前token是否在注释内
        private func isWithinComment(_ segment: Segment) -> Bool {
            // 同上面的实现...
            return false
        }
    }
    
    // CSS选择器规则（黄色）
    struct CssSelectorRule: SyntaxRule {
        var tokenType: TokenType { return .call }  // 使用call类型表示黄色
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 检查是否在注释内
            if isWithinComment(segment) {
                return false
            }
            
            //function是黄色
            //如果前一个token是function，本token标黄色
            if let previousToken = segment.tokens.previous, previousToken == "function" {
                return true
            }
            
            //如果后面(，默认就是function
            if let nextToken = segment.tokens.next, nextToken == "(" {
                return true
            }
                
            
            // CSS选择器通常在样式块开始前，以及在{前面
//            if isCssSelector(token) && isBeforeCssBlock(segment) {
//                return true
//            }
            
            if isCssSelector(token) {
                return true
            }
            
            // 处理类选择器和ID选择器
            if (token.hasPrefix(".") || token.hasPrefix("#")) && isBeforeCssBlock(segment) {
                return true
            }
            
            return false
        }
        
        // 辅助方法：检查当前token是否为CSS选择器
        private func isCssSelector(_ token: String) -> Bool {
            // 常见HTML标签和CSS选择器
            let commonSelectors = [
                "body", "html", "div", "span", "header", "footer", "main", "section",
                "article", "nav", "aside", "p", "h1", "h2", "h3", "h4", "h5", "h6",
                "ul", "ol", "li", "a", "img", "button", "input", "form", "table",
                "tr", "td", "th", "thead", "tbody", "container", "wrapper", "content", "keyframes",
                "float", "bounce", "confetti-fall"
            ]
            
            //            return commonSelectors.contains(token) || token.hasPrefix(".") || token.hasPrefix("#")
            return commonSelectors.contains(token) || token.hasPrefix(".") || token.hasPrefix("#") || token == "*"
        }
        
        // 辅助方法：检查当前token是否在CSS块之前
        private func isBeforeCssBlock(_ segment: Segment) -> Bool {
            // 检查同一行上是否有{
            return segment.tokens.onSameLine.contains("{")
        }
        
        // 辅助方法：检查当前token是否在注释内
        private func isWithinComment(_ segment: Segment) -> Bool {
            // 同上面的实现...
            return false
        }
    }
    
    // 属性值规则（橙色）
    struct AttributeValueRule: SyntaxRule {
        var tokenType: TokenType { return .string }  // 使用string类型表示橙色
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 检查是否在注释内
            if isWithinComment(segment) {
                return false
            }
            
            // 关键修改: 如果当前token是引号中的内容，直接匹配为属性值
//            let onSameLine = segment.tokens.onSameLine
            
                        // 处理 CSS 颜色值 (如 #f0f9ff)
            if token.contains("#") && isHexColor(token) {
                            return true
                        }
            

            
            // 处理带引号的属性值
            if (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                (token.hasPrefix("\'") && token.hasSuffix("\'")) {
                return true;
            }
            
            // 处理引号
            if token == "\"" || token == "\'" {
                // 即使没有结束引号，也视为属性值的一部分
                return true;
            }
            
            //凡是包含单引号的，都标橙色
            if token.contains("\'"){
                return true;
            }
            
            // 属性值在等号后面，且不是数字或单位
            if let previousToken = segment.tokens.previous,
               previousToken == "=" || previousToken.hasSuffix("=") {
                return true
            }
            
                   // 新增：处理属性值中的逗号分隔项
                   if token != "," && segment.tokens.onSameLine.contains("=") {
                       // 检查是否在引号内
                       var quoteOpen = false
                       var quoteChar: Character? = nil
                       var foundEquals = false
            
                       for t in segment.tokens.onSameLine.prefix(while: { $0 != token }) {
                           if t == "\"" || t == "'" {
                               if let qChar = quoteChar, qChar == t.first {
                                   quoteOpen = !quoteOpen
                                   if !quoteOpen {
                                       quoteChar = nil
                                   }
                               } else if !quoteOpen {
                                   quoteOpen = true
                                   quoteChar = t.first
                               }
                           } else if t == "=" {
                               foundEquals = true
                           } else if t == "," {
                               // 如果逗号在引号内且在等号后面，那么后面的token也应该是属性值的一部分
                               return true
                           }
                       }
                   }
            
            // CSS值，如border-box, solid等
            if isCssValue(token) && !isNumberOrUnit(token) {
                // 检查前面是否有冒号
                
                //凡是CSS值，非数值都是橙色
                return true
            }
            
            // 处理引号，让引号也显示为橙色
            if token == "\"" || token == "'" {
                // 检查前面是否有等号
                if let previousToken = segment.tokens.previous,
                   previousToken == "=" || previousToken.hasSuffix("=") {
                    return true
                }
                
                // 检查后面是否有属性值
                if let nextToken = segment.tokens.next, nextToken != ">" && nextToken != " " &&
                    !nextToken.hasPrefix("<") && !nextToken.hasPrefix(">") {
                    return true
                }
            }
            
            return false
        }
        
        // 辅助方法：检查是否为十六进制颜色值
        private func isHexColor(_ token: String) -> Bool {
            // 移除前缀 #
            let hexPart = token.hasPrefix("#") ? String(token.dropFirst()) : token

            // 检查是否是有效的十六进制颜色格式：#RGB, #RRGGBB, #RRGGBBAA 等
            let validLengths = [3, 6, 8] // 有效的十六进制颜色长度

            // 检查长度是否正确，并且所有字符都是有效的十六进制字符
            return validLengths.contains(hexPart.count) &&
                   hexPart.allSatisfy { $0.isHexDigit }
        }
        
        
        
        // 辅助方法：检查是否为CSS值
        private func isCssValue(_ token: String) -> Bool {
            // 常见CSS值
            let cssValues = [
                "auto", "none", "inherit", "initial", "unset", "normal", "bold", "italic",
                "underline", "block", "inline", "flex", "grid", "absolute", "relative",
                "fixed", "static", "hidden", "visible", "solid", "dashed", "dotted",
                "border-box", "content-box", "wrap", "nowrap", "center", "left", "right",
                "top", "bottom", "transparent", "sans-serif", "space-between", "sticky", "space-around"
            ]
            
            return cssValues.contains(token) || cssValues.contains(where: { token.hasPrefix($0) })
            
        }
        
        // 辅助方法：检查是否为数字或单位
        private func isNumberOrUnit(_ token: String) -> Bool {
            // 纯数字
            if token == "0" || token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
            
            // 带单位的数值
            let units = ["px", "s", "em", "rem", "%", "vh", "vw", "vmin", "vmax", "pt", "pc", "in", "cm", "mm", "ex", "ch"]
            return units.contains(where: { token.hasSuffix($0) && token.dropLast($0.count).allSatisfy({ $0.isNumber || $0 == "." }) })
        }
        
        // 辅助方法：检查当前token是否在注释内
        private func isWithinComment(_ segment: Segment) -> Bool {
            // 同上面的实现...
            return false
        }
    }
    
    // 数字和像素单位规则（绿色）
    struct NumberAndUnitRule: SyntaxRule {
        var tokenType: TokenType { return .number }  // 使用number类型表示绿色
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 检查是否在注释内
            if isWithinComment(segment) {
                return false
            }
            
            // 通配符选择器 *
            if token == "*" && isInCssContext(segment) {
                return true
            }
            
            
            // 纯数字
            if token == "0" || token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
            
            // 处理单独的百分号
            if token.contains("%") {
                return true
            }
            
            //支持负数
//            if token.first == "-" {
//                let numberPart = token.dropFirst()
//                if numberPart.allSatisfy({ $0.isNumber || $0 == "." }) {
//                    return true
//                }
//            }

            // 允许负号（但不能只有负号）
            if token.first == "-" {
                let numberPart = token.dropFirst()
                if numberPart.isEmpty { return false } // 仅 `"-"` 不是数字
                return numberPart.contains(".") ? isValidDecimal(String(numberPart)) : numberPart.allSatisfy { $0.isNumber }
            }
            
            // 带单位的数值
            let units = ["px", "em", "rem", "%", "vh", "vw", "vmin", "vmax", "pt", "pc", "in", "cm", "mm", "ex", "ch", "s", "deg"].sorted(by: { $0.count > $1.count }) // 按长度降序
            //判断是否以某个单位结尾
            if units.contains(where: { token.hasSuffix($0) }) {
                
                //token里面包含数字的
                let unit = units.first(where: { token.hasSuffix($0) }) ?? ""
                print("unit: \(unit)")
                let numberPart = token.dropLast(unit.count)
                if numberPart.allSatisfy({ $0.isNumber || $0 == "." }) {
                    return true
                }
                
            }
            
            return false
        }
        
        //检查小数格式，两个点就不是小数
        func isValidDecimal(_ str: String) -> Bool {
            let parts = str.split(separator: ".")
            return parts.count <= 2 && parts.allSatisfy { $0.allSatisfy { $0.isNumber } }
        }
        
        // 辅助方法：检查是否在CSS上下文中
        private func isInCssContext(_ segment: Segment) -> Bool {
            // 检查是否在style标签内
            let onSameLine = segment.tokens.onSameLine
            let hasOpenBrace = onSameLine.contains("{")
            let hasCloseBrace = onSameLine.contains("}")
            
            // 如果在同一行上有{或}，可能在CSS上下文中
            if hasOpenBrace || hasCloseBrace {
                return true
            }
            
            // 检查前面的标记是否有style标签
            let allTokens = segment.tokens.all
            if let currentIndex = allTokens.firstIndex(of: segment.tokens.current) {
                let tokensBefore = allTokens.prefix(upTo: currentIndex)
                // 检查是否有<style>标签
                return tokensBefore.contains("style") || tokensBefore.contains("<style>")
            }
            
            return false
        }
        
        // 辅助方法：检查当前token是否在注释内
        private func isWithinComment(_ segment: Segment) -> Bool {
            // 同上面的实现...
            return false
        }
    }
    
    // HTML字符串规则（属性值）
    struct StringRule: SyntaxRule {
        var tokenType: TokenType { return .string }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // 如果已经被其他规则匹配，则跳过
            if segment.tokens.previous == "=" || isNumberOrUnit(token) {
                return false
            }
            
            // 双引号或单引号字符串
            if (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                (token.hasPrefix("'") && token.hasSuffix("'")) {
                return true
            }
            
            // 检查是否在字符串内部
            return isWithinHTMLString(segment)
        }
        
        // 辅助函数：检查是否在HTML字符串内
        private func isWithinHTMLString(_ segment: Segment) -> Bool {
            var doubleQuoteCount = 0
            var singleQuoteCount = 0
            
            for token in segment.tokens.onSameLine {
                if token == "\"" {
                    doubleQuoteCount += 1
                } else if token == "'" {
                    singleQuoteCount += 1
                } else if token.contains("\"") {
                    doubleQuoteCount += token.filter { $0 == "\"" }.count
                } else if token.contains("'") {
                    singleQuoteCount += token.filter { $0 == "'" }.count
                }
            }
            
            // 字符串被视为"未闭合"，如果引号数量是奇数
            return doubleQuoteCount % 2 != 0 || singleQuoteCount % 2 != 0
        }
        
        // 辅助方法：检查是否为数字或单位
        private func isNumberOrUnit(_ token: String) -> Bool {
            // 纯数字
            if token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
            
            // 带单位的数值
            let units = ["px", "em", "rem", "%", "vh", "vw", "vmin", "vmax", "pt", "pc", "in", "cm", "mm", "ex", "ch"]
            return units.contains(where: { token.hasSuffix($0) && token.dropLast($0.count).allSatisfy({ $0.isNumber || $0 == "." }) })
        }
    }
}
