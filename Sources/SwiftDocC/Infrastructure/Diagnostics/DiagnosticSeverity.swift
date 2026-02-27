/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 The severity of a diagnostic.

 Diagnostics have a severity in order to give the user an indication of what a message means to them and whether it's immediately actionable or blocking.
 */
public enum DiagnosticSeverity: Int, Codable, CustomStringConvertible {
    /**
     An error.

     Errors should ideally be actionable and give the user a clear indication of what must be done to fix the error. An error severity should be used if further progress can't be made in some process or workflow.
     */
    case error = 1

    /**
     A warning.

     Warnings should ideally be actionable and give the user a clear indication of what must be done to fix the error. A warning severity should be used for issues that don't block progress but the user ought to address as soon as possible.
     */
    case warning = 2

    /**
     Information.

     Information needn't be immediately actionable but should be useful to the user.

     > Note: this maps to `analyzer` style information.
     */
    case information = 3

    @available(*, deprecated, message: "Use either 'DiagnosticNote' or 'Solution' instead. This deprecated API will be removed after 6.5 is released.")
    case hint = 4

    public var description: String {
        switch self {
        case .error:
            return "error"
        case .warning:
            return "warning"
        case .information:
            return "note"
        case .hint:
            return "notice"
        }
    }
}

extension DiagnosticSeverity: Comparable {
    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension DiagnosticSeverity {
    public init?(_ string: String?) {
        switch string {
        case "error":
            self = .error
        case "warning":
            self = .warning
        case "information", "info", "note", "hint", "notice":
            self = .information
        default:
            return nil
        }
    }
}
