#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_executable(docc
  main.swift)
target_link_libraries(docc PRIVATE
  DocCCommandLine)
set_target_properties(docc PROPERTIES
  Swift_LANGUAGE_VERSION 5)
target_compile_options(docc PRIVATE
  "SHELL:-swift-version 5"
  "SHELL:-enable-upcoming-feature ConciseMagicFile")

install(TARGETS docc
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
