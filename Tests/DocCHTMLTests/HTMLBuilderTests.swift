/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import DocCHTML

private func span(@HTMLBuilder contents: () -> [HTMLNode]) -> HTMLNode {
    span(attributes: [], contents: contents())
}

struct HTMLBuilderTests {
    
    @Test func buildEmptyContent() {
        let html = span {}
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span></span>
        """#)
    }
    
    @Test func buildText() {
        let html = span {
            "Some text"
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>Some text</span>
        """#)
    }
    
    @Test func buildSingleNestedElements() {
        let html = span {
            span {
                span {}
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>
            <span></span>
          </span>
        </span>
        """#)
    }
    
    @Test func buildFlatListOfElements() {
        do {
            let html = span {
                span {}
                span {}
                span {}
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span></span><span></span><span></span>
            </span>
            """#)
        }
        
        do {
            let html = span {
                "Before"
                span {}
                "In-between"
                span {}
                "After"
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              Before<span></span>In-between<span></span>After
            </span>
            """#)
        }
    }
    
    // MARK: If expressions (single element)
    
    @Test func buildIfExpressionWithSingleElement() {
        let number = 4
        do {
            let html = span {
                if number.isMultiple(of: 2) {
                    span {}
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span></span>
            </span>
            """#)
        }
        
        do {
            let html = span {
                if number.isMultiple(of: 3) {
                    span {}
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span></span>
            """#)
        }
        
        do {
            let html = span {
                if true {
                    "Always true"
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>Always true</span>
            """#)
        }
        
        do {
            let html = span {
                if false {
                    "Always false"
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span></span>
            """#)
        }
    }
    
    @Test func buildIfElseExpressionWithSingleElement() {
        let number = 4
        do {
            let html = span {
                if number.isMultiple(of: 2) {
                    "Even"
                } else {
                    "Odd"
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>Even</span>
            """#)
        }
        
        do {
            let html = span {
                if number.isMultiple(of: 2) {
                    span { "Even" }
                } else {
                    span { "Odd" }
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span>Even</span>
            </span>
            """#)
        }
    }
    
    @Test func buildIfElseIfElseExpressionWithSingleElement() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 3) && number.isMultiple(of: 5) {
                "AaaBbb"
            } else if number.isMultiple(of: 3)  {
                "Aaa"
            } else if number.isMultiple(of: 5)  {
                "Bbb"
            } else {
                "\(number)"
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>4</span>
        """#)
    }
    
    @Test func buildSwitchExpressionWithSingleElement() {
        let number = 4
        let html = span {
            switch (number.isMultiple(of: 3), number.isMultiple(of: 5)) {
            case (true, true):
                "AaaBbb"
            case (true, false):
                "Aaa"
            case (false, true):
                "Bbb"
            default:
                "\(number)"
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>4</span>
        """#)
    }
    
    // MARK: If expressions (multiple elements)
    
    @Test func buildIfExpressionWithMultipleElements() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 2) {
                "Before"
                span {}
                "After"
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          Before<span></span>After
        </span>
        """#)
    }
    
    @Test func buildIfElseExpressionWithMultipleElements() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 2) {
                "Even"
                span {}
            } else {
                "Odd"
                span {}
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          Even<span></span>
        </span>
        """#)
    }
    
    @Test func buildIfElseIfElseExpressionWithMultipleElements() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 3) && number.isMultiple(of: 5) {
                "AaaBbb"
                span {}
            } else if number.isMultiple(of: 3)  {
                "Aaa"
                span {}
            } else if number.isMultiple(of: 5)  {
                "Bbb"
                span {}
            } else {
                "\(number)"
                span {}
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          4<span></span>
        </span>
        """#)
    }
    
    @Test func buildSwitchExpressionWithMultipleElements() {
        let number = 4
        let html = span {
            switch (number.isMultiple(of: 3), number.isMultiple(of: 5)) {
            case (true, true):
                "AaaBbb"
                span {}
            case (true, false):
                "Aaa"
                span {}
            case (false, true):
                "Bbb"
                span {}
            default:
                "\(number)"
                span {}
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          4<span></span>
        </span>
        """#)
    }
    
    // MARK: If expressions (mixed number of elements)
    
    @Test func buildIfElseExpressionWithMixedNumberOfElements() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 2) {
                "Even"  // two
                span {} // expressions
            } else {
                "Odd" // single expression
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          Even<span></span>
        </span>
        """#)
    }
    
    @Test func buildIfElseIfElseExpressionWithMixedNumberOfElements() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 3) && number.isMultiple(of: 5) {
                "AaaBbb" // single expression
            } else if number.isMultiple(of: 3)  {
                "Aaa"  // two
                span {} // expressions
            } else if number.isMultiple(of: 5)  {
                "Bbb" // single expression
            } else {
                "\(number)" // two
                span {}     // expressions
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          4<span></span>
        </span>
        """#)
    }
    
    @Test func buildSwitchExpressionWithMixedNumberOfElements() {
        let number = 4
        let html = span {
            switch (number.isMultiple(of: 3), number.isMultiple(of: 5)) {
            case (true, true):
                "AaaBbb" // single expression
            case (true, false):
                "Aaa"   // two
                span {}  // expressions
            case (false, true):
                "Bbb" // single expression
            default:
                "\(number)" // two
                span {}     // expressions
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          4<span></span>
        </span>
        """#)
    }
    
    // MARK: Array literals
    
    @Test func buildSingleArrayExpression() {
        do {
            let html = span {
                [span {}, br, span {}]
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span></span><br><span></span>
            </span>
            """#)
        }
        
        do {
            let array = [span {}, br, span {}]
            
            let html = span {
                array
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span></span><br><span></span>
            </span>
            """#)
        }
        
//        do {
//            @HTMLBuilder
//            var array = {
//                "Before"
//                span {}
//                "After"
//            }
//            
//            let html = span {
//                array
//            }
//            
//            #expect(htmlString(for: html, options: .prettyPrint) == #"""
//            <span>
//              <span></span>
//              <span></span>
//              <span></span>
//            </span>
//            """#)
//        }
    }
    
    @Test func buildListOfArrayExpressions() {
        let array = [span {}, br, span {}]
        
        let html = span {
            [span {}]
            []
            array
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span></span><span></span><br><span></span>
        </span>
        """#)
    }
    
    // MARK: If expressions (array literals)
    
    @Test func buildIfExpressionWithArrayElement() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 2) {
                [span {}, br, span {}]
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span></span><br><span></span>
        </span>
        """#)
        
    }
    
    @Test func buildIfElseExpressionWithArrayElement() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 2) {
                [span { "Even" }, br]
            } else {
                [span { "Odd" }, br]
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>Even</span><br>
        </span>
        """#)
    }
    
    @Test func buildIfElseIfElseExpressionWithArrayElement() {
        let number = 4
        let html = span {
            if number.isMultiple(of: 3) && number.isMultiple(of: 5) {
                [span { "AaaBbb" }, br]
            } else if number.isMultiple(of: 3)  {
                [span { "Aaa" }, br]
            } else if number.isMultiple(of: 5)  {
                [span { "Bbb" }, br]
            } else {
                [span { "\(number)" }, br]
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>4</span><br>
        </span>
        """#)
    }
    
    @Test func buildSwitchExpressionWithArrayElement() {
        let number = 4
        let html = span {
            switch (number.isMultiple(of: 3), number.isMultiple(of: 5)) {
            case (true, true):
                [span { "AaaBbb" }, br]
            case (true, false):
                [span { "Aaa" }, br]
            case (false, true):
                [span { "Bbb" }, br]
            default:
                [span { "\(number)" }, br]
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>4</span><br>
        </span>
        """#)
    }
    
    // MARK: For loops
    
    @Test func buildLoopWithSingleElement() {
        let html = span {
            for number in 1...3 {
                span { "\(number)" }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>1</span><span>2</span><span>3</span>
        </span>
        """#)
    }
    
    @Test func buildLoopWithIfExpression() {
        let html = span {
            for number in 1...3 {
                if number.isMultiple(of: 2) {
                    span { "\(number)" }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>2</span>
        </span>
        """#)
    }
    
    @Test func buildLoopWithIfElseExpression() {
        let html = span {
            for number in 1...3 {
                if number.isMultiple(of: 2) {
                    span { "Even" }
                } else {
                    span { "Odd" }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>Odd</span><span>Even</span><span>Odd</span>
        </span>
        """#)
    }
    
    @Test func buildLoopWithIfElseIfElseExpression() {
        let html = span {
            for number in 2...6 {
                if number.isMultiple(of: 3) && number.isMultiple(of: 5) {
                    span { "AaaBbb" }
                } else if number.isMultiple(of: 3)  {
                    span { "Aaa" }
                } else if number.isMultiple(of: 5)  {
                    span { "Bbb" }
                } else {
                    span { "\(number)" }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>2</span><span>Aaa</span><span>4</span><span>Bbb</span><span>Aaa</span>
        </span>
        """#)
    }
    
    @Test func buildLoopWithSwitchExpression() {
        let html = span {
            for number in 2...6 {
                switch (number.isMultiple(of: 3), number.isMultiple(of: 5)) {
                case (true, true):
                    span { "AaaBbb" }
                case (true, false):
                    span { "Aaa" }
                case (false, true):
                    span { "Bbb" }
                default:
                    span { "\(number)" }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>2</span><span>Aaa</span><span>4</span><span>Bbb</span><span>Aaa</span>
        </span>
        """#)
    }
    
    @Test func buildLoopWithArrayExpression() {
        let html = span {
            for number in 2...6 {
                [span { "\(number)" }, br]
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          <span>2</span><br><span>3</span><br><span>4</span><br><span>5</span><br><span>6</span><br>
        </span>
        """#)
    }
    
    // MARK: Mixed expressions
    
    @Test func buildIfExpressionAfterSingleElement() {
        let number = 4
        let html = span {
            "Before"
            br
            
            if number.isMultiple(of: 2) {
                span { "Even" }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          Before<br><span>Even</span>
        </span>
        """#)
    }
    
    @Test func buildIfElseExpressionAfterSingleElement() {
        let number = 7
        let html = span {
            "Before"
            br
            
            if number.isMultiple(of: 2) {
                span { "Even" }
            } else {
                span { "Odd" }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          Before<br><span>Odd</span>
        </span>
        """#)
    }
    
    @Test func buildSwitchExpressionAfterSingleElements() {
        let number = 7
        let html = span {
            "Before"
            br
            
            switch (number.isMultiple(of: 3), number.isMultiple(of: 5)) {
            case (true, true):
                span { "AaaBbb" }
            case (true, false):
                span { "Aaa" }
            case (false, true):
                span { "Bbb" }
            default:
                span { "\(number)" }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          Before<br><span>7</span>
        </span>
        """#)
    }
    
    // MARK: Mixed expressions inside conditionals
    
    @Test func buildMixedExpressionsInsideIfElseExpressions() {
        let number = 7
        do {
            let html = span {
                if number == 1 {
                    "One"
                } else {
                    "Two"
                    br
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              Two<br>
            </span>
            """#)
        }
        
        do {
            let html = span {
                if number == 1 {
                    "One"
                } else if number == 2 {
                    "Two"
                    br
                } else {
                    [span { "Three" }, br, span {}]
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span>Three</span><br><span></span>
            </span>
            """#)
        }
        
        do {
            let html = span {
                if number == 1 {
                    "One"
                } else if number == 2 {
                    "Two"
                    br
                } else if number == 3 {
                    [span { "Three" }, br, span {}]
                } else {
                    for number in 1...3 {
                        span { "\(number)" }
                    }
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span>1</span><span>2</span><span>3</span>
            </span>
            """#)
        }
        
        do {
            let html = span {
                if number == 1 {
                    "One"
                } else if number == 2 {
                    "Two"
                    br
                } else if number == 3 {
                    [span { "Three" }, br, span {}]
                } else if number == 4 {
                    for number in 1...3 {
                        span { "\(number)" }
                    }
                } else {
                    "Before"
                    
                    for number in 1...3 {
                        span { "\(number)" }
                    }
                    
                    "After"
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              Before<span>1</span><span>2</span><span>3</span>After
            </span>
            """#)
        }
    }
    
    @Test func buildMixedExpressionsInsideSwitchExpressions() {
        let number = 7
        do {
            let html = span {
                switch number {
                case 1:
                    "One"
                default:
                    "Two"
                    br
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              Two<br>
            </span>
            """#)
        }
        
        do {
            let html = span {
                switch number {
                case 1:
                    "One"
                case 2:
                    "Two"
                    br
                default:
                    [span { "Three" }, br, span {}]
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span>Three</span><br><span></span>
            </span>
            """#)
        }
        
        do {
            let html = span {
                switch number {
                case 1:
                    "One"
                case 2:
                    "Two"
                    br
                case 3:
                    [span { "Three" }, br, span {}]
                default:
                    for number in 1...3 {
                        span { "\(number)" }
                    }
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              <span>1</span><span>2</span><span>3</span>
            </span>
            """#)
        }
        
        do {
            let html = span {
                switch number {
                case 1:
                    "One"
                case 2:
                    "Two"
                    br
                case 3:
                    [span { "Three" }, br, span {}]
                case 4:
                    for number in 1...3 {
                        span { "\(number)" }
                    }
                default:
                    "Before"
                    
                    for number in 1...3 {
                        span { "\(number)" }
                    }
                    
                    "After"
                }
            }
            
            #expect(htmlString(for: html, options: .prettyPrint) == #"""
            <span>
              Before<span>1</span><span>2</span><span>3</span>After
            </span>
            """#)
        }
    }
    
    @Test func buildNestedIfExpressions() {
        let number = 3
        let html = span {
            if number <= 5 {
                "5"
                br
             
                if number <= 4 {
                    "4"
                    br
                 
                    if number <= 3 {
                        "3"
                        br
                     
                        if number <= 2 {
                            "2"
                            br
                         
                            if number <= 1 {
                                "1"
                                br
                                
                                if number <= 0 {
                                    "0"
                                    br
                                }
                            }
                        }
                    }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == #"""
        <span>
          5<br>4<br>3<br>
        </span>
        """#)
    }
}
