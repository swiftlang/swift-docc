# benchmark

A collection of CLI tools to gathering and comparing benchmark results for docc.

## Gathering benchmark metrics

There are a few different tools for gathering benchmark metrics for different versions of docc. 

- The default `measure` action gathers benchmarks for the current local checkout and any uncommitted changes. If you already have another benchmark metrics file to compare the results to, you can pass that for the `--base-benchmark` option.
- The `compare-to` action gathers results for both the current local changes and for the specified commit and compares the results. 
- The `measure-commits` action gathers separate benchmarks for a list of commit hashes.

The `compare-to` tool can be a useful first tool in pull requests to compare the changes on a local branch with the branch that the pull request is targeting, without manually needing to switch branches locally.

If the diff results show significant performance changes that you want to investigate further, you can use the (default) `measure` tool and pass the `benchmark-<commit-hash>.json` file for the pull request's target branch for the `--base-benchmark` option to avoid re-measuring the same commit as you iterate on performance in the investigation.

The `measure-commits` can be used to gather benchmark metrics across multiple commits to to track down performance regressions or perform other investigations.

All measuring commands has a few common options and arguments:
- `--repetitions` The number of repetitions to run (defaults to 5)
- `--compute-missing-output-size-metrics` If the benchmark should compute compatible .doccarchive output size metrics for commits before these metrics were introduced in docc. This can be useful for some analysis of historical commits. 
- `--docc-arguments` The docc command (e.g. `convert`) and all its arguments to call each version of docc with when gathering benchmark metrics.

## Analyzing results

The dedicated `diff` action analyses the statistical significance between the metrics across two benchmark files. If you plan on analyzing these results in a script or other automation, use the `--json-output-path` option to specify a path where the tool writes analysis results as a JSON file. This both avoids needing to parse the human friendly output format for information and avoids loosing accuracy due to formatting numbers to a certain number of significant digits.

Both the `compare-to` action and the `measure` action with a `--base-benchmark` value will run the diff analysis on the gathered  benchmark metrics.

For performance investigations across multiple commits, the `render-trend` can visually draw trends of averages for numerical benchmark metrics. This doesn't signify statistically significant changes across commits and it doesn't indicate deviations in the samples. Don't use this alone to draw conclusions. Instead use this as a first step to identify commits of interest to analyze further. 

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
