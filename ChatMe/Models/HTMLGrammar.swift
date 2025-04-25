//
//  HTMLGrammar.swift
//  ChatMe
//
//  Created by 凡学子 on 2025/3/21.
//

import Foundation
import Splash

/// HTML parser for parsing HTML code
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
            // Put comment rules at the forefront to ensure that comment content is not affected by other rules
            CommentRule(),
            DocTypeRule(),
            // Digital and Pixel Unit Rules (Green)
            NumberAndUnitRule(),
            // Tag Symbol Rules (White)
            TagSymbolRule(),
            
            // Attribute Value Rules (Orange) - Must be before the Attribute Rules
            AttributeValueRule(),
            // Attribute Rule（Blue）
            AttributeRule(),
            
            // Tag keyword rules (purple)
            TagKeywordRule(),
            
            // CSS Selector Rules (Yellow)
            CssSelectorRule(),
            
            // String rules
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
            // Special handling of hyphens to avoid splitting HTML comments into multiple tokens
            return false
        case ("=", _), (_, "="):
            // The equal sign is treated as an independent token and is not merged with other separators.
            return false
        case (":", _), (_, ":"):
            // The colon is treated as an independent token and is not merged with other separators.
            return false
        default:
            return true
        }
    }
}

private extension HTMLGrammar {
    
    // HTML Comment Rules
    struct CommentRule: SyntaxRule {
        var tokenType: TokenType { return .comment }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            //            print("token: \(token)")
            
            // Attempt to detect complete comments or partial comments
            if token.hasPrefix("<!--") && token.hasSuffix("-->") {
                return true
            }
            
            // Comment markers at the beginning section
            if token == "<!--" || token.hasPrefix("<!--") {
                return true
            }
            
            // End section comment marker
            if token == "-->" || token.hasSuffix("-->") {
                return true
            }
            
            // Comment content
            let onSameLine = segment.tokens.onSameLine
            let hasOpenComment = onSameLine.contains { $0.hasPrefix("<!--") || $0 == "<!--" }
            let hasCloseComment = onSameLine.contains { $0.hasSuffix("-->") || $0 == "-->" }
            
            if hasOpenComment && !hasCloseComment {
                // Before the start tag and after the end tag, all content is a comment.
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
    
    // Tag Symbol Rules (White)
    struct TagSymbolRule: SyntaxRule {
        var tokenType: TokenType { return .custom("plain") }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Check if it is within the comment
            if isWithinComment(segment) {
                return false
            }
            
            if token == "<" || token == ">" || token == "/>" || token == "{" || token == "}" ||
                token == "</" || token == ":" || token == "[" || token == "]" || token == ";" || token == "];" {
                return true
            }
            
            // Handle the equal sign separately
            if token == "=" {
                return true
            }
            
            return false
        }
        
        // Check if the current token is within a comment
        private func isWithinComment(_ segment: Segment) -> Bool {
            // Find the start and end comments on the same line
            let tokensBefore = segment.tokens.all.prefix(while: { $0 != segment.tokens.current })
            
            let hasOpenComment = tokensBefore.contains(where: {
                $0.hasPrefix("<!--") && !$0.hasSuffix("-->")
            })
            
            let hasCloseComment = tokensBefore.contains(where: {
                $0.hasSuffix("-->") && !$0.hasPrefix("<!--")
            })
            
            // If there is a start tag but no end tag, it is considered to be within a comment.
            if hasOpenComment && !hasCloseComment {
                return true
            }
            
            // Check if the current line has <!-- but not -->
            let onSameLine = segment.tokens.onSameLine
            let hasOpenCommentOnLine = onSameLine.contains(where: { $0.contains("<!--") })
            let hasCloseCommentOnLine = onSameLine.contains(where: { $0.contains("-->") })
            
            if hasOpenCommentOnLine && !hasCloseCommentOnLine {
                // Check if the current token is after the start of a comment
                if let openIndex = onSameLine.firstIndex(where: { $0.contains("<!--") }),
                   let currentIndex = onSameLine.firstIndex(of: segment.tokens.current),
                   currentIndex > openIndex {
                    return true
                }
            }
            
            return false
        }
    }
    
    // DOCTYPE rule (preprocessing tag)
    struct DocTypeRule: SyntaxRule {
        var tokenType: TokenType { return .preprocessing }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Ensure that it is not a comment.
            if token.hasPrefix("<!--") || token == "<!--" || token.contains("<!--") {
                return false
            }
            
            // Process the DOCTYPE declaration
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
    
    // Tag keyword rules (purple)
    struct TagKeywordRule: SyntaxRule {
        var tokenType: TokenType { return .keyword }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Check if it is within the comment
            if isWithinComment(segment) {
                return false
            }
            
            // Check if within attribute value
            if isWithinAttributeValue(segment) {
                return false
            }
            
            // Tag name, but remove <> symbols
            if let previousToken = segment.tokens.previous {
                if previousToken == "<" {
                    return true
                }
                
                // Handle the case of ending tags
                if previousToken == "</" || previousToken.hasSuffix("</") {
                    return true
                }
            }
            
            // Handle tag names without spaces
            if token.hasPrefix("<") && !token.hasPrefix("<!") && !token.hasPrefix("</") {
                // Exclude tag symbols, only match the tag name part
                return false
            }
            
            // Handle the end tag following Chinese punctuation.
            if let previousToken = segment.tokens.previous,
               token.hasPrefix("/") && previousToken.hasSuffix("<") {
                return false
            }
            
            // Handle the br case
            if token == "br" {
                return true
            }
            
            return false
        }
        
        // Check if the current token is within a comment
        private func isWithinComment(_ segment: Segment) -> Bool {
            return false
        }
        
        // Check if within attribute value
        private func isWithinAttributeValue(_ segment: Segment) -> Bool {
            // Check if within quotes
            var openQuote = false
            var quoteChar: Character? = nil
            
            for token in segment.tokens.onSameLine.prefix(while: { $0 != segment.tokens.current }) {
                // Handle quotes
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
                
                // Process tokens containing quotation marks
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
    
    // Attribute Rules (Blue)
    struct AttributeRule: SyntaxRule {
        var tokenType: TokenType { return .property }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Check if it is within the comment
            if isWithinComment(segment) {
                return false
            }
            
            
            // Attribute names are typically single words followed by an equals sign.
            if let nextToken = segment.tokens.next, nextToken == "=" {
                // Ensure that it is not at the position of the tag name.
                if let previousToken = segment.tokens.previous {
                    if previousToken != "<" && previousToken != "</" {
                        return true
                    }
                }
                else {
                    return true
                }
            }
            
            
            // Handle the case where the attribute name and the equal sign are in the same token, such as "class=".
            if token.hasSuffix("=") && token != "=" {
                // Remove the trailing equals sign and check if the remaining part is a valid attribute name.
                let attributeName = String(token.dropLast())
                if !attributeName.isEmpty && !attributeName.contains("<") && !attributeName.contains(">") {
                    // Only match the part of the attribute name, not including the equal sign
                    return true
                }
            }
            
            // CSS properties (such as margin, padding, etc.)
            if isCssProperty(token) && !isWithinCssSelector(segment) {
                return true
            }
            
            
            return false
        }
        
        // Check if the current token is a CSS property
        private func isCssProperty(_ token: String) -> Bool {
            // List of Common CSS Properties
            let cssProperties = [
                "margin", "padding", "border", "color", "background", "font", "text",
                "width", "height", "display", "position", "top", "left", "right", "bottom",
                "flex", "grid", "box-sizing", "overflow", "z-index", "opacity", "transform",
                "transition", "animation", "align", "justify", "gap", "max-width", "min-width",
                "max-height", "min-height","box-shadow","perspective", "line-height", "outline", "cursor", "object-fit", "flex-wrap", "grid-template-columns", "list-style", "flex-direction"
            ]
            
            return cssProperties.contains(where: { token.hasPrefix($0) || token == $0 })
        }
        
        // Check if it is within a CSS selector
        private func isWithinCssSelector(_ segment: Segment) -> Bool {
            // Check on the same line for the existence of {and after the current token}
            if let tokenIndex = segment.tokens.onSameLine.firstIndex(where: { $0 == segment.tokens.current }),
               let openBraceIndex = segment.tokens.onSameLine.firstIndex(of: "{"),
               tokenIndex < openBraceIndex {
                return true
            }
            
            return false
        }
        
        // Check if the current token is within a comment
        private func isWithinComment(_ segment: Segment) -> Bool {
            return false
        }
    }
    
    // CSS Selector Rules (Yellow)
    struct CssSelectorRule: SyntaxRule {
        var tokenType: TokenType { return .call }  // Use call type to represent yellow
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Check if it is within the comment
            if isWithinComment(segment) {
                return false
            }
            
            //Function is yellow.
            //If the previous token is function, this token is marked yellow.
            if let previousToken = segment.tokens.previous, previousToken == "function" {
                return true
            }
            
            //If the following (, default is function
            if let nextToken = segment.tokens.next, nextToken == "(" {
                return true
            }
            
            if isCssSelector(token) {
                return true
            }
            
            // Handling class selectors and ID selectors
            if (token.hasPrefix(".") || token.hasPrefix("#")) && isBeforeCssBlock(segment) {
                return true
            }
            
            return false
        }
        
        // Check if the current token is a CSS selector
        private func isCssSelector(_ token: String) -> Bool {
            // Common HTML tags and CSS selectors
            let commonSelectors = [
                "body", "html", "div", "span", "header", "footer", "main", "section",
                "article", "nav", "aside", "p", "h1", "h2", "h3", "h4", "h5", "h6",
                "ul", "ol", "li", "a", "img", "button", "input", "form", "table",
                "tr", "td", "th", "thead", "tbody", "container", "wrapper", "content", "keyframes",
                "float", "bounce", "confetti-fall"
            ]
            
            return commonSelectors.contains(token) || token.hasPrefix(".") || token.hasPrefix("#") || token == "*"
        }
        
        // Check if the current token is before the CSS block
        private func isBeforeCssBlock(_ segment: Segment) -> Bool {
            // Check if there is a { on the same line.
            return segment.tokens.onSameLine.contains("{")
        }
        
        // Check if the current token is within a comment
        private func isWithinComment(_ segment: Segment) -> Bool {
            return false
        }
    }
    
    // Attribute Value Rules (Orange)
    struct AttributeValueRule: SyntaxRule {
        var tokenType: TokenType { return .string }  // Use the string type to represent orange
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Check if it is within the comment
            if isWithinComment(segment) {
                return false
            }
            
            // Process CSS color values (such as #f0f9ff)
            if token.contains("#") && isHexColor(token) {
                return true
            }
            
            // Handle quoted attribute values
            if (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                (token.hasPrefix("\'") && token.hasSuffix("\'")) {
                return true;
            }
            
            // Handle quotes
            if token == "\"" || token == "\'" {
                // Even if there is no ending quotation mark, it is considered as part of the attribute value.
                return true;
            }
            
            //All text containing single quotes should be marked in orange.
            if token.contains("\'"){
                return true;
            }
            
            // Attribute values are after the equal sign and are not numbers or units.
            if let previousToken = segment.tokens.previous,
               previousToken == "=" || previousToken.hasSuffix("=") {
                return true
            }
            
            // Process comma-separated items in attribute values
            if token != "," && segment.tokens.onSameLine.contains("=") {
                // Check if it is within quotes
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
                        // If the comma is inside the quotes and after the equal sign, then the token after it should also be part of the attribute value.
                        return true
                    }
                }
            }
            
            // CSS，such as border-box, solid, etc
            if isCssValue(token) && !isNumberOrUnit(token) {
                //All CSS values where non-numeric are orange
                return true
            }
            
            // Handle quotes, making the quotes also display in orange
            if token == "\"" || token == "'" {
                // Check if there is an equal sign in front
                if let previousToken = segment.tokens.previous,
                   previousToken == "=" || previousToken.hasSuffix("=") {
                    return true
                }
                
                // Check if there is an attribute value behind
                if let nextToken = segment.tokens.next, nextToken != ">" && nextToken != " " &&
                    !nextToken.hasPrefix("<") && !nextToken.hasPrefix(">") {
                    return true
                }
            }
            
            return false
        }
        
        // Check if it is a hexadecimal color value
        private func isHexColor(_ token: String) -> Bool {
            // Remove prefix #
            let hexPart = token.hasPrefix("#") ? String(token.dropFirst()) : token
            
            // Check if it is a valid hexadecimal color format: #RGB, #RRGGBB, #RRGGBBAA, etc.
            let validLengths = [3, 6, 8] // Effective hexadecimal color length
            
            // Check if the length is correct and all characters are valid hexadecimal characters.
            return validLengths.contains(hexPart.count) &&
            hexPart.allSatisfy { $0.isHexDigit }
        }
        
        
        
        // Check if it is a CSS value
        private func isCssValue(_ token: String) -> Bool {
            // CSS Values
            let cssValues = [
                "auto", "none", "inherit", "initial", "unset", "normal", "bold", "italic",
                "underline", "block", "inline", "flex", "grid", "absolute", "relative",
                "fixed", "static", "hidden", "visible", "solid", "dashed", "dotted",
                "border-box", "content-box", "wrap", "nowrap", "center", "left", "right",
                "top", "bottom", "transparent", "sans-serif", "space-between", "sticky", "space-around"
            ]
            
            return cssValues.contains(token) || cssValues.contains(where: { token.hasPrefix($0) })
            
        }
        
        // Check if it is a number or unit
        private func isNumberOrUnit(_ token: String) -> Bool {
            // Pure numbers
            if token == "0" || token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
            
            // Value with units
            let units = ["px", "s", "em", "rem", "%", "vh", "vw", "vmin", "vmax", "pt", "pc", "in", "cm", "mm", "ex", "ch"]
            return units.contains(where: { token.hasSuffix($0) && token.dropLast($0.count).allSatisfy({ $0.isNumber || $0 == "." }) })
        }
        
        // Check whether the current token is within the comment
        private func isWithinComment(_ segment: Segment) -> Bool {
            return false
        }
    }
    
    // Number and pixel unit rules (green)
    struct NumberAndUnitRule: SyntaxRule {
        var tokenType: TokenType { return .number }  // Use the number type to represent green
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // Check if it is within the comment
            if isWithinComment(segment) {
                return false
            }
            
            // Wildcard selector *
            if token == "*" && isInCssContext(segment) {
                return true
            }
            
            
            // pure number
            if token == "0" || token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
            
            // Handle the percentage sign individually
            if token.contains("%") {
                return true
            }
            
            // Negative signs are allowed (but not only negative signs)
            if token.first == "-" {
                let numberPart = token.dropFirst()
                if numberPart.isEmpty { return false } // 仅 `"-"` 不是数字
                return numberPart.contains(".") ? isValidDecimal(String(numberPart)) : numberPart.allSatisfy { $0.isNumber }
            }
            
            // Values with units
            let units = ["px", "em", "rem", "%", "vh", "vw", "vmin", "vmax", "pt", "pc", "in", "cm", "mm", "ex", "ch", "s", "deg"].sorted(by: { $0.count > $1.count }) // 按长度降序
            //Determine if it ends with a certain unit
            if units.contains(where: { token.hasSuffix($0) }) {
                
                //The token contains numbers.
                let unit = units.first(where: { token.hasSuffix($0) }) ?? ""
                //                print("unit: \(unit)")
                let numberPart = token.dropLast(unit.count)
                if numberPart.allSatisfy({ $0.isNumber || $0 == "." }) {
                    return true
                }
                
            }
            
            return false
        }
        
        //Check the decimal format, two dots are not a decimal.
        func isValidDecimal(_ str: String) -> Bool {
            let parts = str.split(separator: ".")
            return parts.count <= 2 && parts.allSatisfy { $0.allSatisfy { $0.isNumber } }
        }
        
        // Check if it is in the CSS context
        private func isInCssContext(_ segment: Segment) -> Bool {
            // Check if it is within the style tag
            let onSameLine = segment.tokens.onSameLine
            let hasOpenBrace = onSameLine.contains("{")
            let hasCloseBrace = onSameLine.contains("}")
            
            // If there are { or } on the same line, it may be in the CSS context.
            if hasOpenBrace || hasCloseBrace {
                return true
            }
            
            // Check if there is a style tag in the previous marker.
            let allTokens = segment.tokens.all
            if let currentIndex = allTokens.firstIndex(of: segment.tokens.current) {
                let tokensBefore = allTokens.prefix(upTo: currentIndex)
                // Check if there is a <style> tag
                return tokensBefore.contains("style") || tokensBefore.contains("<style>")
            }
            
            return false
        }
        
        // Check if the current token is within a comment
        private func isWithinComment(_ segment: Segment) -> Bool {
            return false
        }
    }
    
    // HTML String Rules (Attribute Values)
    struct StringRule: SyntaxRule {
        var tokenType: TokenType { return .string }
        
        func matches(_ segment: Segment) -> Bool {
            let token = segment.tokens.current
            
            // If it has already been matched by other rules, skip.
            if segment.tokens.previous == "=" || isNumberOrUnit(token) {
                return false
            }
            
            // Double quotes or single quotes string
            if (token.hasPrefix("\"") && token.hasSuffix("\"")) ||
                (token.hasPrefix("'") && token.hasSuffix("'")) {
                return true
            }
            
            // Check if it is within the string
            return isWithinHTMLString(segment)
        }
        
        // Check if it is within the HTML string
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
            
            // The string is considered "unclosed" if the number of quotation marks is odd.
            return doubleQuoteCount % 2 != 0 || singleQuoteCount % 2 != 0
        }
        
        // Check if it is a number or unit
        private func isNumberOrUnit(_ token: String) -> Bool {
            // pure number
            if token.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
            
            // Values with units
            let units = ["px", "em", "rem", "%", "vh", "vw", "vmin", "vmax", "pt", "pc", "in", "cm", "mm", "ex", "ch"]
            return units.contains(where: { token.hasSuffix($0) && token.dropLast($0.count).allSatisfy({ $0.isNumber || $0 == "." }) })
        }
    }
}
