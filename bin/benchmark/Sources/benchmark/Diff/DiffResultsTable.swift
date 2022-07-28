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
            var colorInfo: [ColumnColorInfo] = []
            switch analysis.change {
                case .same:
                    change = "no change"
                case .differentChecksum:
                    change = "change"
                case .differentNumeric(let percentage):
                    change = percentageFormatter.string(from: NSNumber(value: percentage))!
                    // The colorInfo will be overwritten below if there are warnings
                    colorInfo = [ColumnColorInfo(index: 1, color: percentage < 0 ? .green : .red, upTo: change.endIndex)]
                case .notApplicable:
                    change = "n/a"
            }
            if analysis.warnings != nil {
                colorInfo = [ColumnColorInfo(index: 1, color: .yellow, upTo: change.endIndex)]
            }
            if let footnotes = analysis.footnotes, !footnotes.isEmpty {
                let footNoteSuffix = (footnoteCounter ..< footnoteCounter+footnotes.count).map { Self.superscript($0 + 1) }.joined(separator: ",")

                change += footNoteSuffix
                footnoteCounter += footnotes.count
            }
            
            output += Self.formattedRow(columnValues: [analysis.metricName, change, analysis.before ?? "-", analysis.after], colorInfo: colorInfo)
        }
                    
        output += "└\(String(repeating: "─", count: Self.totalWidth))┘\n"
        
        let allFootnotes = results.analysis.flatMap { $0.footnotes ?? [] }
        if !allFootnotes.isEmpty {
            output += "\n"
            for (number, footnote) in zip(1..., allFootnotes) {
                let footnoteNumber = number < 10 ? " \(number): " : "\(number): "
                let footnoteTextLines = footnote.text.components(separatedBy: .newlines)
                
                output += "\(footnoteNumber)\(footnoteTextLines[0])\n"
                for line in footnoteTextLines.dropFirst() {
                    output += "    \(line)\n"
                }
                if let values = footnote.values {
                    var footnoteOutput = values.dropLast().map { (key, value) in
                        "    \(key) : \(value)".padding(toLength: 30, withPad: " ", startingAt: 0)
                    }.joined()
                    if let (key, value) = values.last {
                        footnoteOutput += "    \(key) : \(value)"
                    }
                    output += footnoteOutput.styled(.dim) + "\n"
                }
                output += "\n"
            }
        }
        
        self.output = output
    }
    
    private static let superscriptCharacters = [
        "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹",
    ]
    
    static func superscript(_ number: Int) -> String {
        guard number > 0 else { return "" }
        
        var result = ""
        var number = number
        var digit = 0
        while number >= 10 {
            (number, digit) = number.quotientAndRemainder(dividingBy: 10)
            result = superscriptCharacters[digit] + result
        }
        result = superscriptCharacters[number] + result
        return result
    }
    
    private struct ColumnColorInfo {
        let index: Int
        let color: BasicTerminalColor
        let upTo: String.Index
    }
    
    private static func formattedRow(columnValues: [String], colorInfo: [ColumnColorInfo] = []) -> String {
        let values: [String] = columnValues.enumerated().map { (index, value) in
            let row = value.padding(toLength: Self.columns[index].width, withPad: " ", startingAt: 0)
            if let colorInfo = colorInfo.first(where: { $0.index == index }) {
                return String(row[..<colorInfo.upTo]).colored(colorInfo.color) + String(row[colorInfo.upTo...])
            }
            return row
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

// MARK: Very minimal terminal output helpers

private let supportsBasicColorOutput: Bool = {
    guard let term = ProcessInfo.processInfo.environment["TERM"] else { return false}
    return term != "dumb"
}()

enum BasicTerminalColor {
    case red, green, yellow
    
    var escapeCode: String {
        switch self {
            case .red: return "\u{001B}[31m"
            case .green: return "\u{001B}[32m"
            case .yellow: return "\u{001B}[33m"
        }
    }
}

enum BasicTerminalStyle {
    case bold, dim
    
    var escapeCode: String {
        switch self {
            case .bold: return "\u{001B}[1m"
            case .dim: return "\u{001B}[2m"
        }
    }
}

extension String {
    func colored(_ color: BasicTerminalColor) -> String {
        guard supportsBasicColorOutput else { return self }
        return color.escapeCode + self + "\u{001B}[39m" // reset to default color
    }
    
    func styled(_ style: BasicTerminalStyle) -> String {
        guard supportsBasicColorOutput else { return self }
        return style.escapeCode + self + "\u{001B}[22m" // reset to default text weight
    }
}
