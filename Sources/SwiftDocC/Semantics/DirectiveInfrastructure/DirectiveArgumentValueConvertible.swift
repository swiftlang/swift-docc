/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

protocol DirectiveArgumentValueConvertible {
    /// Instantiates an instance of the conforming directive argument value type from a string representation.
    /// - Parameter rawDirectiveArgumentValue: A string representation of the directive argument value.
    init?(rawDirectiveArgumentValue: String)
    
    static func allowedValues() -> [String]?
}

extension RawRepresentable where Self: DirectiveArgumentValueConvertible, RawValue == String {
    init?(rawDirectiveArgumentValue: String) {
        self.init(rawValue: rawDirectiveArgumentValue)
    }
}

extension RawRepresentable where Self: DirectiveArgumentValueConvertible, Self: CaseIterable, Self.RawValue == String {
    static func allowedValues() -> [String]? {
        return Self.allCases.map { allowedArgument in
            allowedArgument.rawValue
        }
    }
}

extension String: DirectiveArgumentValueConvertible {
    init?(rawDirectiveArgumentValue: String) {
        self.init(rawDirectiveArgumentValue)
    }
    
    static func allowedValues() -> [String]? {
        return nil
    }
}

extension URL: DirectiveArgumentValueConvertible {
    init?(rawDirectiveArgumentValue: String) {
        self.init(string: rawDirectiveArgumentValue)
    }
    
    static func allowedValues() -> [String]? {
        return nil
    }
}

extension Bool: DirectiveArgumentValueConvertible {
    init?(rawDirectiveArgumentValue: String) {
        self.init(rawDirectiveArgumentValue)
    }
    
    static func allowedValues() -> [String]? {
        return ["true", "false"]
    }
}

extension Int: DirectiveArgumentValueConvertible {
    init?(rawDirectiveArgumentValue: String) {
        self.init(rawDirectiveArgumentValue)
    }
    
    static func allowedValues() -> [String]? {
        return nil
    }
}
