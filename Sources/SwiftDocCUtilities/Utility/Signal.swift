/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A handler that intercepts system signal-events.
#if !os(Windows)
public struct Signal {
    /// List of all system signals that interrupt the program execution.
    public static let all = [SIGHUP, SIGINT, SIGQUIT, SIGABRT, SIGKILL, SIGALRM, SIGTERM]
    
    /// Intercepts the given list of signals and invokes `callback` instead of interrupting execution.
    public static func on(_ signals: [Int32], callback: @convention(c) @escaping (Int32) -> Void) {
        var signalAction = sigaction()
        
        // Different libraries name the `sigaction` fields and handler type differently.
        #if canImport(Musl)
        signalAction.__sa_handler = unsafeBitCast(callback, to: sigaction.__Unnamed_union___sa_handler.self)
        #elseif os(Linux)
        signalAction.__sigaction_handler = unsafeBitCast(callback, to: sigaction.__Unnamed_union___sigaction_handler.self)
        #elseif os(Android)
        signalAction.sa_handler = callback
        #elseif os(FreeBSD) || os(OpenBSD)
        signalAction.__sigaction_u.__sa_handler = callback
        #else
        signalAction.__sigaction_u = unsafeBitCast(callback, to: __sigaction_u.self)
        #endif
        
        withUnsafePointer(to: &signalAction) { (pointer) in
            for signal in signals {
                sigaction(signal, pointer, nil)
            }
        }
    }
}
#endif
