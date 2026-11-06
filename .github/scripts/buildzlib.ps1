#
# This source file is part of the Swift.org open source project
#
# Copyright (c) 2026 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See https://swift.org/LICENSE.txt for license information
# See https://swift.org/CONTRIBUTORS.txt for Swift project authors
#

<#
.SYNOPSIS
    Fetches a pinned zlib release and builds it as a static library on Windows.

.DESCRIPTION
    Downloads the source tarball for a specific zlib release then configures
    and builds with CMake (Visual Studio generator by default, or whatever
    -Generator specifies). Only the static target is built. Output goes to
    <OutDir>\include and <OutDir>\lib.

.PARAMETER WorkDir
    Scratch directory for the download, extracted source and build tree.

.PARAMETER OutDir
    Where the headers and zlib static library are installed.

.PARAMETER Config
    Release or Debug.

.PARAMETER Arch
    Target architecture for the Visual Studio generator: x64, Win32 or ARM64.

.PARAMETER StaticRuntime
    Link the static MSVC runtime (/MT) instead of the DLL runtime (/MD).

.PARAMETER Generator
    CMake generator. Defaults to the newest Visual Studio found by CMake.

.PARAMETER Version
    The zlib release to build, without the leading 'v'. Defaults to 1.3.2.

.EXAMPLE
    .\buildzlib.ps1 -OutDir C:\libs\zlib -StaticRuntime
#>
[CmdletBinding()]
param(
    [string]$WorkDir = (Join-Path $PWD 'zlib-build'),
    [string]$OutDir = (Join-Path $PWD 'zlib-install'),
    [ValidateSet('Release', 'Debug')][string]$Config = 'Release',
    [ValidateSet('x64', 'Win32', 'ARM64')][string]$Arch = 'x64',
    [switch]$StaticRuntime,
    [string]$Generator,
    [string]$Version = '1.3.2'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow otherwise
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

function Invoke-Native {
    & $args[0] $args[1..($args.Length - 1)]
    if ($LASTEXITCODE -ne 0) { throw "'$($args -join ' ')' failed with exit code $LASTEXITCODE" }
}

foreach ($tool in 'cmake', 'tar') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool '$tool' not found on PATH. Install CMake and run from a VS Developer prompt if needed."
    }
}

# 1. Choose the version
$zlibVersion = $Version.TrimStart('v')
Write-Host "zlib version: $zlibVersion"

# 2. Download and extract into fresh directories
$downloadDir = Join-Path $WorkDir "download-$zlibVersion"
$srcRoot = Join-Path $WorkDir "src-$zlibVersion"
$buildDir = Join-Path $WorkDir "build-$zlibVersion-$Arch"
foreach ($d in $downloadDir, $srcRoot, $buildDir) {
    if (Test-Path $d) { Remove-Item $d -Recurse -Force }
    New-Item -ItemType Directory -Path $d | Out-Null
}

$url = "https://github.com/madler/zlib/releases/download/v$zlibVersion/zlib-$zlibVersion.tar.gz"
$archive = Join-Path $downloadDir "zlib-$zlibVersion.tar.gz"
Write-Host "Downloading $url"
Invoke-WebRequest $url -OutFile $archive

# Paths are passed as arguments; nothing is run from inside the extracted tree.
Invoke-Native tar -xzf $archive -C $srcRoot
$srcDir = (Get-ChildItem $srcRoot -Directory | Select-Object -First 1).FullName
if (-not $srcDir) { throw 'Archive did not extract to a directory.' }

# 3. Configure
$cmakeArgs = @('-S', $srcDir, '-B', $buildDir)
if ($Generator) { $cmakeArgs += @('-G', $Generator) }
if (-not $Generator -or $Generator -like 'Visual Studio*') { $cmakeArgs += @('-A', $Arch) }
$cmakeArgs += '-DZLIB_BUILD_SHARED=OFF'    # ignored by older releases; we only build zlibstatic anyway
if ($StaticRuntime) {
    $cmakeArgs += '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW'
    $cmakeArgs += '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>'
}
Invoke-Native cmake @cmakeArgs

# 4. Build only the static library
Invoke-Native cmake --build $buildDir --config $Config --target zlibstatic --parallel

# 5. Install headers and library
$incOut = Join-Path $OutDir 'include'
$libOut = Join-Path $OutDir 'lib'
New-Item -ItemType Directory -Force -Path $incOut, $libOut | Out-Null

# zconf.h is generated into the build tree; the source copy is renamed zconf.h.included
Copy-Item (Join-Path $srcDir 'zlib.h') $incOut -Force
$zconf = Join-Path $buildDir 'zconf.h'
if (-not (Test-Path $zconf)) { $zconf = Join-Path $srcDir 'zconf.h' }
Copy-Item $zconf $incOut -Force

# Multi-config generators put the lib under <build>\<Config>; single-config in <build>.
# Pre-1.3.2, the output is named zlibstatic or, for debug, zlibstaticd.
# As of zlib-1.3.2, the output is named zs or, for debug, zsd.
# Normalize to zlib[d]
$built = Get-ChildItem $buildDir -Recurse -Filter 'z*.lib' |
    Where-Object { $_.Directory.Name -in $Config, (Split-Path $buildDir -Leaf) } |
    Select-Object -First 1
if (-not $built) { $built = Get-ChildItem $buildDir -Recurse -Filter 'z*.lib' | Select-Object -First 1 }
if (-not $built) { throw 'Could not find the built static library.' }

$destName = $built.Name -replace '^(zlibstatic|zs)', 'zlib'
Copy-Item $built.FullName (Join-Path $libOut $destName) -Force

# Write a pkgconfig file
$pcName = Join-Path $OutDir 'zlib.pc'

# pkg-config treats backslash as an escape character, so use forward slashes
$pcLib = $libOut -replace '\\', '/'
$pcInc = $incOut -replace '\\', '/'
# Quote paths containing whitespace, so they stay a single flag argument
if ($pcLib -match '\s') { $pcLib = "`"$pcLib`"" }
if ($pcInc -match '\s') { $pcInc = "`"$pcInc`"" }
$pcLibName = [System.IO.Path]::GetFileNameWithoutExtension($destName)

@"
Name: zlib
Version: $zlibVersion
Description: zlib compression library
Libs: -L$pcLib -l$pcLibName
Cflags: -I$pcInc
"@ | Out-File $pcName -Encoding ascii

Write-Host ''
Write-Host "zlib $zlibVersion ($Config, $Arch) built successfully."
Write-Host "  Headers:   $incOut"
Write-Host "  Library:   $(Join-Path $libOut $destName)"
Write-Host "  pkgconfig: $pcName"
