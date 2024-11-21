#[[
This source file is part of the Swift.org open source project

Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for Swift project authors
#]]

add_executable(docc
  main.swift)
target_link_libraries(docc PRIVATE
  SwiftDocCUtilities)

install(TARGETS docc
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
