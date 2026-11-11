#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(DocCCommon STATIC
  FixedSizeBitSet.swift
  JSONDecoding/FastSymbolGraphJSONDecoder.swift
  JSONDecoding/SymbolGraph+FastJSONDecodable.swift
  JSONDecoding/UnsafeRawPointer+HasASCIIPrefix.swift
  Mutex.swift
  SourceLanguage.swift
  TermListItem.swift)
target_link_libraries(DocCCommon PRIVATE
  DocC::SymbolKit)
target_link_libraries(DocCCommon PUBLIC
  SwiftMarkdown::Markdown)
# FIXME(compnerd) workaround leaking dependencies
target_link_libraries(DocCCommon PUBLIC
  libcmark-gfm
  libcmark-gfm-extensions)
set_target_properties(DocCCommon PROPERTIES
  Swift_LANGUAGE_VERSION 6)
