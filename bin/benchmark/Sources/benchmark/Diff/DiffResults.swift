/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
import Foundation

public struct DiffResults: Codable, Equatable {
    public var analysis: [MetricAnalysis]
    
    public struct MetricAnalysis: Codable, Equatable {
        public let metricName: String
        public let metricID: String
        
        public enum Change: Codable, Equatable {
            case same, differentChecksum, differentNumeric(percentage: Double), notApplicable
        }
        public var change: Change
        
        public var before: String?
        public var after: String
        
        public struct Footnote: Codable, Equatable {
            let text: String
            let values: [(String, String)]?
        }
        public var footnotes: [Footnote]?
        
        public var warnings: [String]?
    }
    
    public static var empty: DiffResults {
        return DiffResults(analysis: [])
    }
}

// MARK: Codable

extension DiffResults.MetricAnalysis.Change {
    enum CodingKeys: CodingKey {
        case kind, percentage
    }
    private enum ChangeKind: String, Codable {
        case same, differentChecksum, differentNumeric, notApplicable
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        switch try container.decode(ChangeKind.self, forKey: .kind) {
            case .same:
                self = .same
            case .differentChecksum:
                self = .differentChecksum
            case .differentNumeric:
                self = try .differentNumeric(percentage: container.decode(Double.self, forKey: .percentage))
            case .notApplicable:
                self = .notApplicable
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
            case .same:
                try container.encode(ChangeKind.same, forKey: .kind)
            case .differentChecksum:
                try container.encode(ChangeKind.differentChecksum, forKey: .kind)
            case .differentNumeric(percentage: let value):
                try container.encode(ChangeKind.differentNumeric, forKey: .kind)
                try container.encode(value, forKey: .percentage)
            case .notApplicable:
                try container.encode(ChangeKind.notApplicable, forKey: .kind)
        }
    }
}

extension DiffResults.MetricAnalysis.Footnote {
    public static func == (lhs: DiffResults.MetricAnalysis.Footnote, rhs: DiffResults.MetricAnalysis.Footnote) -> Bool {
        guard lhs.text == rhs.text else { return false }
        
        for (lhsValues, rhsValue) in zip(lhs.values ?? [], rhs.values ?? []) where lhsValues != rhsValue {
            return false
        }
        return true
    }

    enum CodingKeys: CodingKey {
        case text, values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.text = try container.decode(String.self, forKey: .text)
        self.values = try container.decodeIfPresent([[String]].self, forKey: .values)?.map { ($0[0], $0[1]) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(text, forKey: .text)
        try container.encode(values?.map { [$0.0, $0.1]}, forKey: .values)
    }
}
