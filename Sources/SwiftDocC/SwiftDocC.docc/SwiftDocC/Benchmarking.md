# Benchmarking

Produce performance metrics to improve the compilation pipeline and track regressions.

DocC has metric logging built right in; it is disabled by default but it can be enabled easily via an environment variable or when running the tools in the `bin/benchmark` Swift package.

When you are working on a PR to add a feature or fix a bug you should evaluate the performance cost of your code changes.

## Running a benchmark

To benchmark the `convert` command with a given documentation bundle `MyFramework.docc` run:

```
swift run --package-path bin/benchmark benchmark --docc-arguments convert MyFramework.docc
```

The tool will enable metrics logging, do five sequential runs of the `convert` command with the given inputs and options, and write the results to a JSON file on disk.

For pull requests where you want to compare the local changes against another version of the—the HEAD commits of the branch that the pull request is targeting—you can use the `compare-against-commit` tool:

```
swift run --package-path bin/benchmark benchmark compare-to <commit-ish> --docc-arguments convert MyFramework.docc
```

This tool will gather metrics for both the local changes (same as the default `measure` tool) and for the other commit of docc, write both results to JSON files on disk, and perform a statistical analysis comparing the two benchmark results. 

If the analysis shows results that you want to investigate further and you want to continue comparing to the same baseline results from the other commit, you can switch to the `measure` tool and pass the `benchmark-<commit-hash>.json` file for the `--base-benchmark` argument.

```
swift run --package-path bin/benchmark benchmark measure --base-benchmark benchmark-<commit-hash>.json --docc-arguments convert MyFramework.docc
```

This will only gather new metrics for the local changes, as you iterate, but will still compare the new metrics against the results from the other commit and output the comparison of the two benchmark results.   

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
- ``Benchmark/DataDirectoryOutputSize``
- ``Benchmark/IndexDirectoryOutputSize``
- ``Benchmark/PeakMemory``
- ``Benchmark/TopicGraphHash``
- ``Benchmark/ExternalTopicsHash``

### Logging Metrics

- ``benchmark(add:benchmarkLog:)``
- ``benchmark(begin:benchmarkLog:)``
- ``benchmark(end:benchmarkLog:)``
- ``benchmark(wrap:benchmarkLog:body:)``

<!-- Copyright (c) 2021-2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
