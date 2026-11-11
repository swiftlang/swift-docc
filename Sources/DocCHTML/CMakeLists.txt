#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2026 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(DocCHTML STATIC
  HTMLFormatter.swift
  HTMLNode.swift
  HTMLNode+Attributes.swift
  HTMLNode+fromXMLNode.swift
  HTMLNode+Tags.swift
  LinkProvider.swift
  MarkdownRenderer+Availability.swift
  MarkdownRenderer+Breadcrumbs.swift
  MarkdownRenderer+Declaration.swift
  MarkdownRenderer+Discussion.swift
  MarkdownRenderer+Parameters.swift
  MarkdownRenderer+Relationships.swift
  MarkdownRenderer+Returns.swift
  MarkdownRenderer+Topics.swift
  MarkdownRenderer.swift
  RenderableDirectiveParser.swift
  StaticResources.swift
  SourceLanguage+Attribute.swift
  WordBreak.swift)
target_link_libraries(DocCHTML PRIVATE
  DocCCommon)
target_link_libraries(DocCHTML PUBLIC
  SwiftMarkdown::Markdown
  DocC::SymbolKit)
# FIXME(compnerd) workaround leaking dependencies
target_link_libraries(DocCHTML PUBLIC
  libcmark-gfm
  libcmark-gfm-extensions)
set_target_properties(DocCHTML PROPERTIES
  Swift_LANGUAGE_VERSION 6)

# SwiftPM embeds these files in the code as properties of a `PackageResources` structure (`.embedInCode()`).
# CMake doesn't support package resources, so this generates the same structure, again whenever a file changes.
set(DocCHTML_RESOURCES
  Resources/sidebar.svg)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${DocCHTML_RESOURCES})
foreach(resource IN LISTS DocCHTML_RESOURCES)
  cmake_path(GET resource FILENAME name)
  string(MAKE_C_IDENTIFIER "${name}" name)
  file(READ "${resource}" bytes HEX)
  string(REGEX REPLACE "(..)" "0x\\1," bytes "${bytes}")
  string(APPEND DocCHTML_EMBEDDED_RESOURCES "  static let ${name}: [UInt8] = [${bytes}]\n")
endforeach()
file(CONFIGURE OUTPUT embedded_resources.swift CONTENT "struct PackageResources {\n${DocCHTML_EMBEDDED_RESOURCES}}\n")
target_sources(DocCHTML PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/embedded_resources.swift")
