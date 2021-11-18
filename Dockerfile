# This source file is part of the Swift.org open source project
#
# Copyright (c) 2021 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors

FROM swift:5.5

# Set up the current build user in the same way done in the Swift.org CI system: 
# https://github.com/apple/swift-docker/blob/main/swift-ci/master/ubuntu/20.04/Dockerfile.

RUN groupadd -g 998 build-user && \
  useradd -m -r -u 42 -g build-user build-user
  
USER build-user

WORKDIR /home/build-user
