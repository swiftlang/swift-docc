/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation

extension Date {
    package init(dosFileTime: UInt32) {
        let year = 1980 + Int((dosFileTime >> 25) & 0x7f)
        let month = Int((dosFileTime >> 21) & 0xf)
        let day = Int((dosFileTime >> 16) & 0x1f)
        let hour = Int((dosFileTime >> 11) & 0x1f)
        let minute = Int((dosFileTime >> 5) & 0x3f)
        let second = Int((dosFileTime << 1) & 0x3f)

        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )

        self = components.date!
    }

    package var dosFileTime: UInt32 {
        let dosMinTime: UInt32 = 0x0021_0000
        let dosMaxTime: UInt32 = 0xff9f_bf7d
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self
        )
        let year = components.year! - 1980

        if (year & ~0x7f) != 0 {
            return year > 0 ? dosMaxTime : dosMinTime
        }

        var dosTime = (year & 0x7f) << 25
        dosTime |= components.month! << 21
        dosTime |= components.day! << 16
        dosTime |= components.hour! << 11
        dosTime |= components.minute! << 5
        dosTime |= components.second! >> 1

        if dosTime > dosMaxTime {
            return dosMaxTime
        }
        if dosTime < dosMinTime {
            return dosMinTime
        }

        return UInt32(dosTime)
    }
}
