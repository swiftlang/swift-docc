/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

/// A logger that runs benchmarks and stores the results.
public class Benchmark: Encodable {
    /// True if the process is supposed to run benchmarks.
    public let isEnabled: Bool
    
    /// If defined, filter the metrics to log with that value.
    public let metricsFilter: String?
    
    /// Creates a new benchmark log that can store metric results.
    /// - Parameters:
    ///   - isEnabled: If `true`, store metrics in the data model.
    ///   - metricsFilter: If set, filter the logged metrics with this string.
    ///   If `nil`, all metrics are stored in the log.
    init(isEnabled: Bool = true, metricsFilter: String? = nil) {
        self.isEnabled = isEnabled
        self.metricsFilter = metricsFilter
    }
    
    /// The shared instance to use for logging.
    public static let main: Benchmark = Benchmark(
        isEnabled: ProcessInfo.processInfo.environment["DOCC_BENCHMARK"] == "YES",
        metricsFilter: ProcessInfo.processInfo.environment["DOCC_BENCHMARK_FILTER"]
    )

    /// The benchmark timestamp.
    public let date = Date()

    /// The benchmark platform name.
    #if os(macOS)
    public let platform = "macOS"
    #elseif os(iOS)
    public let platform = "iOS"
    #elseif os(Linux)
    public let platform = "Linux"
    #elseif os(Android)
    public let platform = "Android"
    #elseif os(FreeBSD)
    public let platform = "FreeBSD"
    #elseif os(OpenBSD)
    public let platform = "OpenBSD"
    #else
    public let platform = "unsupported"
    #endif

    /// The list of metrics included in this benchmark.
    public var metrics: [any BenchmarkMetric] = []
    
    enum CodingKeys: String, CodingKey {
        case date, metrics, arguments, platform
    }
    
    /// Prepare the gathered measurements into a benchmark results.
    ///
    /// The prepared benchmark results are sorted in a stable order that's suitable for presentation.
    ///
    /// - Returns: The prepared benchmark results for all the gathered metrics.
    public func results() -> BenchmarkResults? {
        guard isEnabled else { return nil }
        
        let metrics = metrics.compactMap { log -> BenchmarkResults.Metric? in
            guard let result = log.result else {
                return nil
            }
            let id = (log as? (any DynamicallyIdentifiableMetric))?.identifier ?? type(of: log).identifier
            let displayName = (log as? (any DynamicallyIdentifiableMetric))?.displayName ?? type(of: log).displayName
            return .init(id: id, displayName: displayName, value: result)
        }
        
        return BenchmarkResults(
            platformName: platform,
            timestamp: date,
            doccArguments: Array(CommandLine.arguments.dropFirst()),
            unorderedMetrics: metrics
        )
    }
    
    public func encode(to encoder: any Encoder) throws {
        try results()?.encode(to: encoder)
    }
}

private extension Benchmark {
    func shouldLogMetricType(_ metricType: any BenchmarkMetric.Type) -> Bool {
        return isEnabled && (metricsFilter == nil || metricType.identifier.hasPrefix(metricsFilter!))
    }
}

/// Logs a one-off metric value.
/// - Parameters:
///   - metric: The one-off metric
///   - log: The log to add the metric to.
public func benchmark<E>(add metric: @autoclosure () -> E, benchmarkLog log: Benchmark = .main) where E: BenchmarkMetric {
    guard log.shouldLogMetricType(E.self) else { return }

    log.metrics.append(metric())
}

/// Begins the given metric.
/// - Parameters:
///   - metric: The metric to begin measuring.
///   - log: The log that may filter out the metric.
public func benchmark<E>(begin metric: @autoclosure () -> E, benchmarkLog log: Benchmark = .main) -> E? where E: BenchmarkBlockMetric {
    guard log.shouldLogMetricType(E.self) else { return nil }

    let metric = metric()
    metric.begin()
    return metric
}

/// Ends the given metric and adds it to the log.
/// - Parameters:
///   - metric: The metric to end and log.
///   - log: The log to add the metric to.
public func benchmark<E>(end metric: @autoclosure () -> E?, benchmarkLog log: Benchmark = .main) where E: BenchmarkBlockMetric {
    guard log.shouldLogMetricType(E.self), let metric = metric() else { return }

    metric.end()
    log.metrics.append(metric)
}

@discardableResult
/// Measures a metric around the given closure.
/// - Parameters:
///   - metric: The metric to measure and log.
///   - log: The log to add the metric to.
///   - body: The closure around which to measure the metric.
/// - Returns: The return value from the closure.
public func benchmark<E, Result>(wrap metric: @autoclosure () -> E, benchmarkLog log: Benchmark = .main, body: () throws -> Result) rethrows -> Result where E: BenchmarkBlockMetric {
    if log.shouldLogMetricType(E.self) {
        let event = metric()
        event.begin()
        let result = try body()
        event.end()
        log.metrics.append(event)
        return result
    } else {
        return try body()
    }
}
