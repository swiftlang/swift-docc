#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(DocCHTML STATIC
  LinkProvider.swift
  MarkupRenderer+Availability.swift
  MarkupRenderer+Breadcrumbs.swift
  MarkupRenderer+Declaration.swift
  MarkupRenderer+Parameters.swift
  MarkupRenderer.swift
  WordBreak.swift
  XMLNode+element.swift)
target_link_libraries(DocCHTML PUBLIC
  SwiftMarkdown::Markdown
  DocC::SymbolKit)
