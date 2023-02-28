/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type that encapsulate the possible formatting options for diagnostics.
public struct DiagnosticFormattingOptions: OptionSet {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// Problem fix-its should be included when printing diagnostics to a file or output stream.
    @available(*, deprecated, renamed: "formatConsoleOutputForTools")
    public static let showFixits = formatConsoleOutputForTools

    /// Output to the console should be formatted for an IDE or other tool to parse.
    public static let formatConsoleOutputForTools = DiagnosticFormattingOptions(rawValue: 1 << 0)

    /// All of the available formatting options.
    public static let all: DiagnosticFormattingOptions = [.formatConsoleOutputForTools]
}
