#[[
This source file is part of the swift-format open source project

Copyright (c) 2024 Apple Inc. and the DocC project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_executable(docc
  main.swift)
target_link_libraries(docc PRIVATE
  SwiftDocCUtilities)

install(TARGETS docc
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
