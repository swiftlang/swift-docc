# ``AlternateDeclarations``

This bundle contains a class translated from Objective-C. That class contains one method, which was
written to accept a completion handler. The Swift translation converted this into two methods: one
with the original completion handler parameter, and one that uses `async`/`await`. This bundle
exists to test SymbolKit's "alternate declarations" mechanism and ensure that Swift-DocC converts it
into a Declarations section with both declarations.

<!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
