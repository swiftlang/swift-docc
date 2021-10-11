# Default Code Listing Syntax

This is an abstract.

```
// With no language set, this should highlight to 'swift' because the 'CDDefaultCodeListingLanguage' key is set to 'swift'.
func foo()
```

    /// This is a non fenced code listing and should also default to the 'CDDefaultCodeListingLanguage' language.
    func foo()

```objective-c
/// This is a fenced code block with an explicit language set, and it should override the default language for the bundle.
- (void)foo;
```

<!-- Copyright (c) 2021 Apple Inc and the Swift Project authors. All Rights Reserved. -->
