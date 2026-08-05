/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing

/// A parent suite that groups together all of the DocCHTMLTests suites.
///
/// On Linux, FoundationXML is backed by libxml2, which isn't thread-safe by default.
/// The library uses global state that backs the XMLNode type,
/// and it's the caller's responsibility to synchronize access to it [1].
/// It also documents that "xmlCleanupParser is not thread-safe",
/// and memory corruption may occur if other threads make libxml2 calls afterwards [2].
///
/// Swift Testing runs in parallel by default, with multiple XMLNode trees being built and torn down at the same time.
/// On Linux, this causes the tests to intermittently crash with SIGSEGV (signal 11) inside `XMLNode.deinit`.
///
/// To avoid these crashes, the tests that use libxml2 are run serially on Linux.
///
/// [1]: https://gnome.pages.gitlab.gnome.org/libxml2/html/parser_8h.html#a642085a16c74b8352e92a89c348cc9c4
/// [2]: https://gnome.pages.gitlab.gnome.org/libxml2/html/parser_8h.html#a7eb4447bac68a016b428f51cc402369f
#if canImport(FoundationXML)
@Suite(.serialized)
enum DocCHTMLTestSuites {}
#else
@Suite
enum DocCHTMLTestSuites {}
#endif
