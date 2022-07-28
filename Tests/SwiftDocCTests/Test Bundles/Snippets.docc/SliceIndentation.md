# Slice Indentation

This article tests that slices trim extra indentation.

For example, in the following code:

```swift
do {
  middle()
}
```

Slicing the line which contains `middle()` should look like this:

```swift
middle()
```

and not:

```swift
  middle()
```

@Snippet(path: "Snippets/Snippets/MySnippet", slice: "middle")

<!-- Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved. -->
