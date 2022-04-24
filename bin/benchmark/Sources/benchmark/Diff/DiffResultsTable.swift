/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import Foundation

struct DiffResultsTable {
    static var columns: [(name: String, width: Int)] = [
        ("Metric", 40),
        ("Change", 10),
        ("Before", 20),
        ("After", 20),
    ]
    static var totalWidth: Int {
        return columns.reduce(0, { $0 + $1.width + 3 }) - 1
    }
    
    private(set) var output: String
    init(results: DiffResults) {
        var output = ""
        output.reserveCapacity((Self.totalWidth + 1) * (4 + results.analysis.count))
        
        output += "┌\(String(repeating: "─", count: Self.totalWidth))┐\n"
        output += Self.formattedRow(columnValues: Self.columns.map { $0.name })
        output += "├\(String(repeating: "─", count: Self.totalWidth))┤\n"
        
        for analysis in results.analysis {
            let change: String
            switch analysis.change {
                case .same:
                    change = "no change"
                case .differentChecksum:
                    change = "change"
                case .differentNumeric(let percentage):
                    change = percentageFormatter.string(from: NSNumber(value: percentage / 100.0))!
                case .notApplicable:
                    change = "n/a"
            }
            
            output += Self.formattedRow(columnValues: [analysis.metricName, change, analysis.before ?? "-", analysis.after])
        }
                    
        output += "└\(String(repeating: "─", count: Self.totalWidth))┘\n"
        
        self.output = output
    }
    
    private static func formattedRow(columnValues: [String]) -> String {
        let values = columnValues.enumerated().map { (index, value) in
            value.padding(toLength: Self.columns[index].width, withPad: " ", startingAt: 0)
        }
        return "│ \(values.joined(separator: " │ ")) │\n"
    }
}

private let percentageFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .percent
    fmt.alwaysShowsDecimalSeparator = true
    fmt.positivePrefix = fmt.plusSign
    fmt.maximumFractionDigits = 2
    fmt.minimumFractionDigits = 2
    return fmt
}()
