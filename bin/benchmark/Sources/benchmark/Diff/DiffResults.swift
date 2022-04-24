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
        
//        public enum FormattedValue: Codable, Equatable {
//            case average(String)
//            case text(String)
//            case missingMetric
//        }
        public var before: String?
        public var after: String
        
        public struct Footnote: Codable, Equatable {
            let text: String
            let values: [String: Double]?
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

//extension DiffResults.MetricAnalysis.FormattedValue {
//    enum CodingKeys: CodingKey {
//        case kind, value, standardDeviation
//    }
//    private enum FormattedValueKind: String, Codable {
//        case average, text, missingValue
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        switch try container.decode(FormattedValueKind.self, forKey: .kind) {
//            case .average:
//                self = try .average(
//                    container.decode(String.self, forKey: .value),
//                    standardDeviation: container.decode(Double.self, forKey: .standardDeviation)
//                )
//            case .text:
//                self = try .text(container.decode(String.self, forKey: .value))
//            case .missingValue:
//                self = .missingMetric
//        }
//    }
//
//    public func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//
//        switch self {
//            case .average(let value, let standardDeviation):
//                try container.encode(FormattedValueKind.average, forKey: .kind)
//                try container.encode(value, forKey: .value)
//                try container.encode(standardDeviation, forKey: .standardDeviation)
//            case .text(let value):
//                try container.encode(FormattedValueKind.text, forKey: .kind)
//                try container.encode(value, forKey: .value)
//            case .missingMetric:
//                try container.encode(FormattedValueKind.missingMetric, forKey: .kind)
//        }
//    }
//}
