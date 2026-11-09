#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(ZLib
  ZLib.swift
)

set_target_properties(ZLib PROPERTIES
  Swift_LANGUAGE_VERSION 6)

target_compile_options(ZLib PUBLIC
  "-I${CMAKE_CURRENT_SOURCE_DIR}/../CZLib"
)

target_link_libraries(ZLib PUBLIC
  ZLIB::ZLIB
)

if(BUILD_SHARED_LIBS)
  install(TARGETS ZLib
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
