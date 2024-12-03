/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A shim for `os.Logger` that does nothing.
///
/// This type allows calling code to avoid using `#if canImport(os)` throughout the implementation.
package struct NoOpLoggerShim : @unchecked Sendable {
    package init() {}
    
    package var isEnabled: Bool { false }
    
    package enum Level {
        case `default`, info, debug, error, fault
    }
    
    package func log(_ message: NoOpLogMessage) {}
    package func log(level: Level, _ message: NoOpLogMessage) {}
    
    package func trace(_ message: NoOpLogMessage) {}
    package func debug(_ message: NoOpLogMessage) {}
    package func info(_ message: NoOpLogMessage) {}
    package func warning(_ message: NoOpLogMessage) {}
    package func error(_ message: NoOpLogMessage) {}
    package func critical(_ message: NoOpLogMessage) {}
    package func fault(_ message: NoOpLogMessage) {}
}

/// A shim for `os.OSSignposter` that does nothing, except for running the passed interval task.
///
/// This type allows calling code to avoid using `#if canImport(os)` throughout the implementation.
package struct NoOpSignposterShim : @unchecked Sendable {
    package init() {}
    
    package var isEnabled: Bool { false }
    
    package struct ID {
        static var exclusive = ID()
    }
    package func makeSignpostID() -> ID { ID() }
    
    package struct IntervalState {}
    
    // Without messages
    
    package func beginInterval(_ name: StaticString, id: ID = .exclusive) -> IntervalState {
        IntervalState()
    }
    package func endInterval(_ name: StaticString, _ state: IntervalState) {}
        
    package func withIntervalSignpost<T>(_ name: StaticString, id: ID = .exclusive, around task: () throws -> T) rethrows -> T {
        try task()
    }

    package func emitEvent(_ name: StaticString, id: ID = .exclusive) {}
    
    // With messages
    
    package func beginInterval(_ name: StaticString, id: ID = .exclusive, _ message: NoOpLogMessage) -> IntervalState {
        self.beginInterval(name, id: id)
    }
    package func endInterval(_ name: StaticString, _ state: IntervalState, _ message: NoOpLogMessage) {}
        
    package func withIntervalSignpost<T>(_ name: StaticString, id: ID = .exclusive, _ message: NoOpLogMessage, around task: () throws -> T) rethrows -> T {
        try self.withIntervalSignpost(name, id: id, around: task)
    }

    package func emitEvent(_ name: StaticString, id: ID = .exclusive, _ message: NoOpLogMessage) {}
}

// MARK: Message

package struct NoOpLogMessage: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
    package let interpolation: Interpolation
    
    package init(stringInterpolation: Interpolation) {
        interpolation = stringInterpolation
    }
    package init(stringLiteral value: String) {
        self.init(stringInterpolation: .init(literalCapacity: 0, interpolationCount: 0))
    }
    
    package struct Interpolation: StringInterpolationProtocol {
        package init(literalCapacity: Int, interpolationCount: Int) {}

        package mutating func appendLiteral(_ literal: String) {}
        
        // Append string
        package mutating func appendInterpolation(_ argumentString: @autoclosure @escaping () -> String, align: NoOpLogStringAlignment = .none, privacy: NoOpLogPrivacy = .auto) {}
        package mutating func appendInterpolation(_ value: @autoclosure @escaping () -> some CustomStringConvertible, align: NoOpLogStringAlignment = .none, privacy: NoOpLogPrivacy = .auto) {}
        
        // Append booleans
        package mutating func appendInterpolation(_ boolean: @autoclosure @escaping () -> Bool, format: NoOpLogBoolFormat = .truth, privacy: NoOpLogPrivacy = .auto) {}
        
        // Append integers
        package mutating func appendInterpolation(_ number: @autoclosure @escaping () -> some FixedWidthInteger, format: NoOpLogIntegerFormatting = .decimal, align: NoOpLogStringAlignment = .none, privacy: NoOpLogPrivacy = .auto) {}
        
        // Append float/double
        package mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Float, format: NoOpLogFloatFormatting = .fixed, align: NoOpLogStringAlignment = .none, privacy: NoOpLogPrivacy = .auto) {}
        package mutating func appendInterpolation(_ number: @autoclosure @escaping () -> Double, format: NoOpLogFloatFormatting = .fixed, align: NoOpLogStringAlignment = .none, privacy: NoOpLogPrivacy = .auto) {}
        
        // Add more interpolations here as needed
    }
    
    package struct NoOpLogStringAlignment {
        package static var none: Self { .init() }
        package static func right(columns: @autoclosure @escaping () -> Int) -> Self { .init() }
        package static func left(columns: @autoclosure @escaping () -> Int) -> Self { .init() }
    }
    
    package struct NoOpLogPrivacy {
        package enum Mask {
            case hash, none
        }
        package static var `public`: Self { .init() }
        package static var `private`: Self { .init() }
        package static var sensitive: Self { .init() }
        package static var auto: Self { .init() }
        package static func `private`(mask: Mask) -> Self { .init() }
        package static func sensitive(mask: Mask) -> Self { .init() }
        package static func auto(mask: Mask) -> Self { .init() }
    }
    
    package enum NoOpLogBoolFormat {
        case truth, answer
    }
    
    public struct NoOpLogIntegerFormatting {
        package static var decimal: Self { .init() }
        package static var hex: Self { .init() }
        package static var octal: Self { .init() }
        package static func decimal(explicitPositiveSign: Bool = false) -> Self { .init() }
        package static func decimal(explicitPositiveSign: Bool = false, minDigits: @autoclosure @escaping () -> Int) -> Self { .init() }
        package static func hex(explicitPositiveSign: Bool = false, includePrefix: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func hex(explicitPositiveSign: Bool = false, includePrefix: Bool = false, uppercase: Bool = false, minDigits: @autoclosure @escaping () -> Int) -> Self { .init() }
        package static func octal(explicitPositiveSign: Bool = false, includePrefix: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func octal(explicitPositiveSign: Bool = false, includePrefix: Bool = false, uppercase: Bool = false, minDigits: @autoclosure @escaping () -> Int) -> Self { .init() }
    }
    
    package struct NoOpLogFloatFormatting {
        package static var fixed: Self { .init() }
        package static var hex: Self { .init() }
        package static var exponential: Self { .init() }
        package static var hybrid: Self { .init() }
        package static func fixed(precision: @autoclosure @escaping () -> Int, explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func fixed(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func hex(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func exponential(precision: @autoclosure @escaping () -> Int, explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func exponential(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func hybrid(precision: @autoclosure @escaping () -> Int, explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
        package static func hybrid(explicitPositiveSign: Bool = false, uppercase: Bool = false) -> Self { .init() }
    }
}
