#[[
This source file is part of the Swift open source project

Copyright © 2014 - 2025 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
#]]

add_library(Zip
  Date+DosFileTime.swift
  ZipFileDataSink.swift
  ZipFileDataSource.swift
  ZipFileError.swift
  ZipFileReader.swift
  ZipFileWriter.swift
)
target_link_libraries(Zip PUBLIC
  ZLib
)
set_target_properties(Zip PROPERTIES
  Swift_LANGUAGE_VERSION 6)
