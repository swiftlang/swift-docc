/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A task scheduler that throttles execution within a given time interval.
///
/// Schedule blocks of work with ``schedule(block:)`` and `Throttle` will
/// execute only the latest scheduled task in the last amount of seconds
/// you set via ``init(interval:)``.
public class Throttle {
    private let throttleQueue = DispatchQueue(label: "com.throttlequeue")
    private var currentTimer: DispatchSourceTimer?
    
    let timeoutInterval: DispatchTimeInterval
    
    /// Creates a new throttle that performs work after waiting the given timeout interval.
    ///
    /// - Parameter interval: The time period to wait before performing work.
    public init(interval: DispatchTimeInterval) {
        timeoutInterval = interval
    }
    
    /// Schedule a block for execution.
    ///
    /// Scheduling a `block`, executes it after the pre-set interval of time for the current `Throttle` instance.
    /// If you schedule a new block before the throttle interval has passed,
    /// the previous block is canceled in favor of the latest one.
    public func schedule(block: @escaping ()->Void) {
        throttleQueue.sync {
            if let currentTimer = currentTimer {
                currentTimer.cancel()
            }

            currentTimer = DispatchSource.makeTimerSource()
            currentTimer?.schedule(wallDeadline: .now() + timeoutInterval)
            currentTimer?.setEventHandler {
                block()
            }
            currentTimer?.resume()
        }
    }
}
