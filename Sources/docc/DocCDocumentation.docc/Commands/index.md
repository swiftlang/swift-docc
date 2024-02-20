# ``index``

Create an LMDB index for an already built documentation archive.

@Metadata {
    @PageImage(purpose: icon, source: command-icon)
}

If you pass the `--emit-lmdb-index` flag to the ``convert`` command, `docc` will create an LMDB index during the build so that you don't need to process the archive after it's been built.

## Arguments, Flags, and Options

### Inputs

- term `<source-archive-path>`:
  Path to the documentation archive ('.doccarchive') directory to build an LMDB index for.

### Other Options:

- term `--bundle-identifier <bundle-identifier>` **(required)**:
  The bundle identifier of the processed archive.

- term `--verbose`:
  Print out the index information while running.

- term `-h, --help`:
  Show help information.

> Earlier Versions:
> Before Swift-DocC 5.6, the `index` command was a top-level command instead of a `process-archive` subcommand. 

<!-- Copyright (c) 2024 Apple Inc and the Swift Project authors. All Rights Reserved. -->
