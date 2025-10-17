#[[
This source file is part of the swift-format open source project

Copyright (c) 2024 Apple Inc. and the DocC project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

cmake_minimum_required(VERSION 3.24)

project(docc
  LANGUAGES Swift)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)
set(CMAKE_Swift_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)

include(GNUInstallDirs)

find_package(ArgumentParser CONFIG)
find_package(SwiftCrypto CONFIG)
find_package(SwiftMarkdown CONFIG)
find_package(LMDB CONFIG)
find_package(SymbolKit CONFIG)
find_package(cmark-gfm CONFIG)

add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:-package-name;SwiftDocC>")

add_subdirectory(Sources)
