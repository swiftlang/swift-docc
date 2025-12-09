#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(DocCHTML STATIC
  LinkProvider.swift
  MarkdownRenderer+Availability.swift
  MarkdownRenderer+Breadcrumbs.swift
  MarkdownRenderer+Parameters.swift
  MarkdownRenderer+Returns.swift
  MarkdownRenderer.swift
  WordBreak.swift
  XMLNode+element.swift)
target_link_libraries(DocCHTML PRIVATE
  DocCCommon)
target_link_libraries(DocCHTML PUBLIC
  SwiftMarkdown::Markdown
  DocC::SymbolKit)
# FIXME(compnerd) workaround leaking dependencies
target_link_libraries(DocCHTML PUBLIC
  libcmark-gfm
  libcmark-gfm-extensions)
