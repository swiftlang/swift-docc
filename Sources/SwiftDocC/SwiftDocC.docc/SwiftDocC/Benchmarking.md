# Benchmarking

Produce performance metrics to improve the compilation pipeline and track regressions.

DocC has metric logging built right in; it is disabled by default but it can be enabled easily via an environment variable or when running the included `bin/benchmark.swift` script.

When you are working on a PR to add a feature or fix a bug you should evaluate the performance cost of your code changes.

## Running a benchmark

To benchmark the `convert` command with a given documentation bundle `MyFramework.docc` run:

```
swift bin/benchmark.swift convert MyFramework.docc
```

The automation script will enable metrics logging, do five sequential runs of the `convert` command, and finally save a JSON file with the results on disk.

Provide the `--base-benchmark` option in order to compare the current benchmark with a previous JSON file you already have on disk to evaluate improvements or track that you are not regressing.

```
swift bin/benchmark.swift --base-benchmark baseline-benchmark.json convert MyFramework.docc
```

## Adding a Custom Metric

When you work on a particular feature and you want to track a given custom metric you can temporarily add it to the log.

For example, to add a metric that counts the registered bundles, create a `BundlesCount` class that adopts the ``BenchmarkMetric`` protocol:

```swift
class BundlesCount: BenchmarkMetric {
  static let identifier = "bundles-count"
  static let displayName = "Bundles Count"
  
  var result: MetricValue?
  
  init(context: DocumentationContext) {
    result = .number(Double(context.registeredBundles.count))
  }
}
```

Add your custom metric to the default log by using ``benchmark(add:benchmarkLog:)``:

```swift
benchmark(add: BundlesCount(context: context))
```

## Topics

### Benchmark Log

- ``Benchmark``
- ``Benchmark/main``

### Default Metrics

- ``Benchmark/Duration``
- ``Benchmark/OutputSize``
- ``Benchmark/PeakMemory``
- ``Benchmark/TopicGraphHash``
- ``Benchmark/ExternalTopicsHash``

### Logging Metrics

- ``benchmark(add:benchmarkLog:)``
- ``benchmark(begin:benchmarkLog:)``
- ``benchmark(end:benchmarkLog:)``
- ``benchmark(wrap:benchmarkLog:body:)``

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
