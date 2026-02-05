#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

cmake_minimum_required(VERSION 3.24)

# FIXME: The C language is enabled as `GNUInstallDirs` requires the language to
# function properly.  We must further enable the language in the initial set to
# ensure that the correct linker is detected.
project(SwiftDocC
  LANGUAGES C Swift)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)
set(CMAKE_Swift_COMPILE_OPTIONS_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
# Overridden per-target.
set(CMAKE_Swift_LANGUAGE_VERSION invalid)

include(GNUInstallDirs)

add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-upcoming-feature ExistentialAny>")
add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-upcoming-feature InternalImportsByDefault>")
# Only enable the `ConciseMagicFile` upcoming feature for Swift 5.
add_compile_options("$<$<AND:$<COMPILE_LANGUAGE:Swift>,$<EQUAL:$<TARGET_PROPERTY:Swift_LANGUAGE_VERSION>,5>>:SHELL:-enable-upcoming-feature ConciseMagicFile>")

find_package(ArgumentParser)
find_package(SwiftASN1)
find_package(SwiftCrypto)
find_package(SwiftMarkdown)
find_package(LMDB)
find_package(SymbolKit)
find_package(cmark-gfm)

add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:-package-name;SwiftDocC>")

add_subdirectory(Sources)
