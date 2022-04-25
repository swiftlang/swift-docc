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
        ("Change", 15),
        ("Before", 20),
        ("After", 20),
    ]
    static var totalWidth: Int {
        return columns.reduce(0, { $0 + $1.width + 3 }) - 1
    }
    
    private(set) var output: String
    init(results: DiffResults) {
        var output = ""
        
        let allWarnings = results.analysis.flatMap { $0.warnings ?? [] }
        for warning in allWarnings {
            output += "\(warning)\n"
        }
        
        output += "┌\(String(repeating: "─", count: Self.totalWidth))┐\n"
        output += Self.formattedRow(columnValues: Self.columns.map { $0.name })
        output += "├\(String(repeating: "─", count: Self.totalWidth))┤\n"
        
        var footnoteCounter = 0
        
        for analysis in results.analysis {
            var change: String
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
            if let footnotes = analysis.footnotes, !footnotes.isEmpty {
                let footNoteSuffix = (footnoteCounter ..< footnoteCounter+footnotes.count).map { Self.superscriptCharacters[$0] }.joined(separator: ",")

                change += footNoteSuffix
                footnoteCounter += footnotes.count
            }
            
            output += Self.formattedRow(columnValues: [analysis.metricName, change, analysis.before ?? "-", analysis.after])
        }
                    
        output += "└\(String(repeating: "─", count: Self.totalWidth))┘\n"
        
        let allFootnotes = results.analysis.flatMap { $0.footnotes ?? [] }
        if !allFootnotes.isEmpty {
            output += "\n"
            for (number, footnote) in zip(1..., allFootnotes) {
                let footnoteNumber = number < 10 ? " \(number): " : "\(number): "
                output += "\(footnoteNumber)\(footnote.text)\n"
                if let values = footnote.values {
                    output += values.map { (key, value) in
                        "    \(key) : \(value)".padding(toLength: 30, withPad: " ", startingAt: 0)
                    }.joined() + "\n"
                }
                output += "\n"
            }
        }
        
        self.output = output
    }
    
    private static let superscriptCharacters = [
        "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹",
        "¹⁰", "¹¹", "¹²", "¹³", "¹⁴", "¹⁵", "¹⁶", "¹⁷", "¹⁸", "¹⁹",
    ]
    
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
    fmt.minimumSignificantDigits = 3
    fmt.maximumSignificantDigits = 4
    fmt.maximumFractionDigits = 8
    fmt.minimumFractionDigits = 1
    return fmt
}()
