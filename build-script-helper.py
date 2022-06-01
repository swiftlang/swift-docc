#!/usr/bin/env python3

"""
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 ------------------------------------------------------------------------------
 This is a helper script for the main swift repository's build-script.py that
 knows how to build and install Swift-DocC given a swift workspace.
"""

from __future__ import print_function

import argparse
import sys
import os, platform
import subprocess

def printerr(message):
  print(message, file=sys.stderr)

def main(argv_prefix = []):
  args = parse_args(argv_prefix + sys.argv[1:])
  run(args)

def parse_args(args):
  parser = argparse.ArgumentParser(prog='build-script-helper.py')

  parser.add_argument('--package-path', default='')
  parser.add_argument('-v', '--verbose', action='store_true', help='Log the executed commands.')
  parser.add_argument('--prefix', help='The install path.')
  parser.add_argument('--configuration', default='debug')
  parser.add_argument('--build-dir', default=None)
  parser.add_argument('--multiroot-data-file', help='Path to an Xcode workspace to create a unified build of Swift-DocC with other projects.')
  parser.add_argument('--toolchain', required=True, help='The toolchain to use when building this package.')
  parser.add_argument('--update', action='store_true', help='Update all SwiftPM dependencies.')
  parser.add_argument('--no-local-deps', action='store_true', help='Use normal remote dependencies when building.')
  parser.add_argument('build_actions', help='Extra actions to perform. Can be any number of the following', choices=['all', 'build', 'test', 'generate-xcodeproj', 'install'], nargs="*", default=['build'])
  parser.add_argument('--install-dir', default=None, help='The location to install the docc executable to.')
  parser.add_argument('--copy-doccrender-from', default=None, help='The location to copy an existing Swift-DocC-Render template from.')
  parser.add_argument('--copy-doccrender-to', default=None, help='The location to install an existing Swift-DocC-Render template to.')
  
  parsed = parser.parse_args(args)

  parsed.swift_exec = os.path.join(parsed.toolchain, 'bin', 'swift')

  # Convert package_path to absolute path, relative to root of repo.
  repo_path = os.path.dirname(__file__)
  parsed.package_path = os.path.realpath(
                        os.path.join(repo_path, parsed.package_path))

  if not parsed.build_dir:
    parsed.build_dir = os.path.join(parsed.package_path, '.build')

  return parsed

def run(args):
  package_name = os.path.basename(args.package_path)

  env = dict(os.environ)
  # Use local dependencies (i.e. checked out next to swift-docc).
  if not args.no_local_deps:
    env['SWIFTCI_USE_LOCAL_DEPS'] = "1"

  if args.update:
    print("** Updating dependencies of %s **" % package_name)
    try:
      update_swiftpm_dependencies(package_path=args.package_path,
        swift_exec=args.swift_exec,
        build_path=args.build_dir,
        env=env,
        verbose=args.verbose)
    except subprocess.CalledProcessError as e:
      printerr('FAIL: Updating dependencies of %s failed' % package_name)
      printerr('Executing: %s' % ' '.join(e.cmd))
      sys.exit(1)

  # The test action creates its own build. No need to build if we are just testing.
  if should_run_action('build', args.build_actions):
    print("** Building %s **" % package_name)
    try:
      invoke_swift(action='build',
        products=['docc'],
        env=env,
        args=args,
        swiftpm_args=get_swiftpm_options('build', args))
    except subprocess.CalledProcessError as e:
      printerr('FAIL: Building %s failed' % package_name)
      printerr('Executing: %s' % ' '.join(e.cmd))
      sys.exit(1)

  if should_run_action('generate-xcodeproj', args.build_actions):
    print("** Generating Xcode project for %s **" % package_name)
    try:
      generate_xcodeproj(args.package_path,
        swift_exec=args.swift_exec,
        env=env,
        verbose=args.verbose)
    except subprocess.CalledProcessError as e:
      printerr('FAIL: Generating the Xcode project failed')
      printerr('Executing: %s' % ' '.join(e.cmd))
      sys.exit(1)

  if should_run_action('test', args.build_actions):
    print("** Testing %s **" % package_name)
    try:
      invoke_swift(action='test',
        products=['SwiftDocCPackageTests'],
        env=env,
        args=args,
        swiftpm_args=get_swiftpm_options('test', args))
    except subprocess.CalledProcessError as e:
      printerr('FAIL: Testing %s failed' % package_name)
      printerr('Executing: %s' % ' '.join(e.cmd))
      sys.exit(1)
  
  if should_run_action('install', args.build_actions):
    print("** Installing %s **" % package_name)
    
    try:
      invoke_swift(action='build',
        products=['docc'],
        env=env,
        args=args,
        swiftpm_args=get_swiftpm_options('install', args))
      install(args, env)
    except subprocess.CalledProcessError as e:
      printerr('FAIL: Installing %s failed' % package_name)
      printerr('Executing: %s' % ' '.join(e.cmd))
      sys.exit(1)

def should_run_action(action_name, selected_actions):
  if action_name in selected_actions:
    return True
  elif "all" in selected_actions:
    return True
  else:
    return False

def update_swiftpm_dependencies(package_path, swift_exec, build_path, env, verbose):
  args = [swift_exec, 'package', '--package-path', package_path, '--build-path', build_path, 'update']
  check_call(args, env=env, verbose=verbose)
  
def get_swiftpm_options(action, args):
  swiftpm_args = [
    '--package-path', args.package_path,
    '--build-path', args.build_dir,
    '--configuration', args.configuration,
  ]

  # Pass the verbose flag for "install" builds to get more information to investigate a CI build failure. (rdar://85912344)
  if args.verbose or action == 'install':
    swiftpm_args += ['--verbose']

  if platform.system() == 'Darwin':
    swiftpm_args += [
      # Relative library rpath for swift; will only be used when /usr/lib/swift
      # is not available.
      '-Xlinker', '-rpath', '-Xlinker', '@executable_path/../lib/swift/macosx',
    ]
  else:
    swiftpm_args += [
      # Library rpath for swift, dispatch, Foundation, etc. when installing
      '-Xlinker', '-rpath', '-Xlinker', '$ORIGIN/../lib/swift/linux',
    ]

  if action == 'install':
    # When tests are run on the host machine, `docc` is located in the build directory; to find
    # its linked libraries (Swift runtime dependencies), `docc` needs to link against the host
    # machine's toolchain libraries. When installing docc on the target machine, the `docc`
    # executable will be located in the toolchain, so it should find its linked libraries at a relative path.
    swiftpm_args += ['-Xswiftc', '-no-toolchain-stdlib-rpath']
    
  if action == 'test':
    swiftpm_args += ['--parallel']
  
  return swiftpm_args

def invoke_swift(action, products, env, args, swiftpm_args):
  # Until rdar://53881101 is implemented, we cannot request a build of multiple
  # targets simultaneously. For now, just build one product after the other.
  for product in products:
    invoke_swift_single_product(action, product, env, args, swiftpm_args)

def invoke_swift_single_product(action, product, env, args, swiftpm_args):
  call = [args.swift_exec, action] + swiftpm_args
  
  if platform.system() != 'Darwin':
    call.extend(['--enable-test-discovery'])
  if args.multiroot_data_file:
    call.extend(['--multiroot-data-file', args.multiroot_data_file])
  if action == 'test':
    call.extend(['--test-product', product])
  else:
    call.extend(['--product', product])

  # Tell Swift-DocC that we are building in a build-script environment so that
  # it does not need to be rebuilt if it has already been built before.
  env['SWIFT_BUILD_SCRIPT_ENVIRONMENT'] = '1'

  check_call(call, env=env, verbose=args.verbose)
  
def generate_xcodeproj(package_path, swift_exec, env, verbose):
  package_name = os.path.basename(package_path)
  xcodeproj_path = os.path.join(package_path, '%s.xcodeproj' % package_name)
  args = [swift_exec, 'package', '--package-path', package_path, 'generate-xcodeproj', '--output', xcodeproj_path]
  check_call(args, env=env, verbose=verbose)

def install(args, env):
  docc_install_dir=args.install_dir
  if docc_install_dir is None:
    fatal_error("Missing required '--install-dir' argument.")
  verbose=args.verbose
  # Find the docc executable location
  docc_path = docc_bin_path(
    swift_exec=os.path.join(os.path.join(args.toolchain, 'bin'), 'swift'),
    args=args,
    env=env,
    verbose=verbose
  )
  
  create_intermediate_directories(os.path.dirname(docc_install_dir), verbose=verbose)
  check_and_sync(
    file_path=docc_path,
    install_path=docc_install_dir,
    verbose=verbose
  )

  # Copy the content of the build_dir into the install dir with a call like
  # rsync -a src/ dest
  copy_render_from=args.copy_doccrender_from
  copy_render_to=args.copy_doccrender_to
    
  if copy_render_from is not None:
    if copy_render_to is None:
      fatal_error("Missing required '--copy-doccrender-to' argument since '--copy-doccrender-from' was passed.")
    from_dir_with_trailing_slash = os.path.join(copy_render_from, '')
    create_intermediate_directories(copy_render_to, verbose=verbose)
    check_and_sync(
      file_path=from_dir_with_trailing_slash,
      install_path=copy_render_to,
      verbose=verbose
    )

def docc_bin_path(swift_exec, args, env, verbose):
  cmd = [
    swift_exec,
    'build',
    '--show-bin-path',
    '--package-path', args.package_path,
    '--build-path', args.build_dir,
    '--configuration', args.configuration,
    '--product', 'docc'
  ]
  if verbose:
    print(' '.join([escape_cmd_arg(arg) for arg in cmd]))
  return os.path.join(
    subprocess.check_output(cmd, env=env).strip().decode(), 'docc')

def create_intermediate_directories(dir_path, verbose):
  cmd = ["mkdir", "-p", dir_path]
  print("-- note: creating intermediate directories %s: %s" % (dir_path, " ".join(cmd)))
  result = check_call(cmd, verbose=verbose)
  if result != 0:
    fatal_error("creating intermediate directories failed with exit status %d" % (result,))

def check_and_sync(file_path, install_path, verbose):
  cmd = ["rsync", "-a", file_path, install_path]
  print("-- note: installing %s: %s" % (os.path.basename(file_path), " ".join(cmd)))
  result = check_call(cmd, verbose=verbose)
  if result != 0:
    fatal_error("install failed with exit status %d" % (result,))
    
def check_call(cmd, verbose, env=os.environ, **kwargs):
  if verbose:
    print(' '.join([escape_cmd_arg(arg) for arg in cmd]))
  return subprocess.check_call(cmd, env=env, stderr=subprocess.STDOUT, **kwargs)

def fatal_error(message):
  print(message, file=sys.stderr)
  sys.exit(1)

def escape_cmd_arg(arg):
  if '"' in arg or ' ' in arg:
    return '"%s"' % arg.replace('"', '\\"')
  else:
    return arg

if __name__ == '__main__':
  main()
