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

include(GNUInstallDirs)

# The full toolchain build has find_package config files for all our
# dependencies, but at-desk we don't have that luxury. Set this option to use
# SwiftPM's checkouts instead.
option(SWIFTDOCC_VENDOR_DEPENDENCIES
  "Build dependencies from .build/checkouts instead of using find_package"
  NO)
set(SWIFTDOCC_DEPS_CHECKOUTS "${CMAKE_CURRENT_SOURCE_DIR}/.build/checkouts"
  CACHE PATH "Location of SwiftPM-fetched dependency sources")

if(SWIFTDOCC_VENDOR_DEPENDENCIES)
  include(FetchContent)

  macro(_docc_declare_vendored pkg subdir)
    if(NOT EXISTS "${SWIFTDOCC_DEPS_CHECKOUTS}/${subdir}")
      message(FATAL_ERROR
        "SWIFTDOCC_VENDOR_DEPENDENCIES is ON but ${subdir} was not found at "
        "${SWIFTDOCC_DEPS_CHECKOUTS}. Run `swift package resolve` first.")
    endif()
    # OVERRIDE_FIND_PACKAGE routes both this CMakeLists' `find_package` calls
    # *and* nested calls inside the vendored dependencies (e.g. swift-crypto
    # looking up SwiftASN1) through our local checkouts instead of the network.
    FetchContent_Declare(${pkg}
      SOURCE_DIR "${SWIFTDOCC_DEPS_CHECKOUTS}/${subdir}"
      OVERRIDE_FIND_PACKAGE)
  endmacro()

  # swift-cmark needs to disable testing to build via CMake
  set(BUILD_TESTING NO)

  _docc_declare_vendored(CLMDB          swift-lmdb)
  _docc_declare_vendored(ArgumentParser swift-argument-parser)
  _docc_declare_vendored(SwiftASN1      swift-asn1)
  _docc_declare_vendored(SwiftCrypto    swift-crypto)
  _docc_declare_vendored(cmark-gfm      swift-cmark)
  _docc_declare_vendored(SwiftMarkdown  swift-markdown)
  _docc_declare_vendored(SymbolKit      swift-docc-symbolkit)

  find_package(CLMDB          REQUIRED)
  find_package(ArgumentParser REQUIRED)
  find_package(SwiftASN1      REQUIRED)
  find_package(SwiftCrypto    REQUIRED)
  find_package(cmark-gfm      REQUIRED)

  # swift-markdown's `cmake/modules/CMakeLists.txt` calls `export(TARGETS ...
  # EXPORT_LINK_INTERFACE_LIBRARIES)` on its `Markdown` target, which pulls the
  # private `libcmark-gfm-extensions` link dep into the exported interface and
  # fails unless that dep belongs to a build-tree export. swift-cmark itself
  # already exports `libcmark-gfm` (in `cmarkTargets.cmake`) but not the
  # extensions target, so place it in a throwaway build-tree export to satisfy
  # the check; the generated stub file is never consumed.
  export(TARGETS libcmark-gfm-extensions
    NAMESPACE _docc_vendor_stub::
    FILE "${CMAKE_BINARY_DIR}/_docc_vendor_cmark_extensions_stub.cmake")

  find_package(SwiftMarkdown  REQUIRED)
  find_package(SymbolKit      REQUIRED)

  # LMDB, SymbolKit, and Swift-Markdown are exported into namespaces in the
  # toolchain build, but not when included directly like this. Re-export them
  # into the namespaces that the DocC modules expect.
  if(TARGET CLMDB AND NOT TARGET LMDB::CLMDB)
    add_library(LMDB::CLMDB ALIAS CLMDB)
  endif()
  if(TARGET SymbolKit AND NOT TARGET DocC::SymbolKit)
    add_library(DocC::SymbolKit ALIAS SymbolKit)
  endif()
  if(TARGET Markdown AND NOT TARGET SwiftMarkdown::Markdown)
    add_library(SwiftMarkdown::Markdown ALIAS Markdown)
  endif()
else()
  find_package(ArgumentParser)
  find_package(SwiftASN1)
  find_package(SwiftCrypto)
  find_package(SwiftMarkdown)
  find_package(LMDB)
  find_package(SymbolKit)
  find_package(cmark-gfm)
endif()

# Overridden per-target.
set(CMAKE_Swift_LANGUAGE_VERSION invalid)

# These compile options must apply only to swift-docc's own targets, so they
# are emitted *after* any vendored dependencies have been added. Vendored deps
# do not set `Swift_LANGUAGE_VERSION` and would otherwise fail the `EQUAL`
# generator-expression check on the `ConciseMagicFile` option below.
add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-upcoming-feature ExistentialAny>")
add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:SHELL:-enable-upcoming-feature InternalImportsByDefault>")
# Only enable the `ConciseMagicFile` upcoming feature for Swift 5.
add_compile_options("$<$<AND:$<COMPILE_LANGUAGE:Swift>,$<EQUAL:$<TARGET_PROPERTY:Swift_LANGUAGE_VERSION>,5>>:SHELL:-enable-upcoming-feature ConciseMagicFile>")

add_compile_options("$<$<COMPILE_LANGUAGE:Swift>:-package-name;SwiftDocC>")

add_subdirectory(Sources)
