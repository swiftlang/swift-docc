# Concurrency

Perform concurrent work on the DocC model.

DocC is, generally speaking, performing a sequence of operations on a set of documentation topics. Since the compilaton is a pipeline, you mostly do work serially as each stage's input is the previous stage's output.

When working serially becomes a bottleneck, use a suitable method from a small number of `Collection` extensions that synchronously perform concurrent work on multiple threads but keep the complexity of your code manageable.

The preferred way to concurrently perform work is to have a function called from within the main queue, perform concurrent operations inside the function, and return the aggregated results, keeping the concurrency within the local scope of the function.

When you would like to concurrently perform work on a collection of inputs you have a choice between:

 - `Collection.concurrentPerform(batches:block:)` concurrently perform a block of code over the collection elements. A concurrent alternative to `Collection.forEach(_:)`.
 - `Collection.concurrentPerform(batches:block:) -> [Result]` concurrently perform a block over the collection elements and optionally return an arbitrary amount of results returned in no particular order.
 - `Collection.concurrentMap(batches:block:) -> [Result]` concurrently convert the collection elements; the returned results are in the collection's original order. A concurrent alternative to `Collection.map(_:)`.

To concurrently convert a set of elements and preserve the order in the results use:

```swift
let results: [Int] = [1, 2, 3, 4].concurrentMap {
  return $0 * 2
}
```

To return an arbitrary amount of results in no particular order use:

```swift
let errors: [Error] = [1, 2, 3, 4].concurrentPerform { element, results in
  if element % 2 == 0 {
    results.append(MyError.evenInput)
  }
}
```

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
