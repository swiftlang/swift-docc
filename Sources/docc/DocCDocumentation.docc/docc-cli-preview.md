# preview

Convert documentation inputs and preview the documentation output.

## Overview

`docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>`
`docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>]`
`docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>] [<availability-options>] [<diagnostic-options>] [<source-repository-options>] [<hosting-options>] [<info-plist-fallbacks>] [<feature-flags>] [<other-options>]`

### Options

- term `-p, --port <port-number>`:
                        Port number to use for the preview web server. (default: 8080)
- term `<catalog-path>`:          Path to a '.docc' documentation catalog directory.
- term `--additional-symbol-graph-dir <additional-symbol-graph-dir>`:
                        A path to a directory of additional symbol graph files.
- term `-o, --output-path, --output-dir <output-path>`:
                        The location where the documentation compiler writes the built documentation.
- term `--platform <platform>`:   Specify information about the current release of a platform.
      Each platform's information is specified via separate "--platform" values using the following
      format: "name={platform name},version={semantic version}".
      Optionally, the platform information can include a 'beta={true|false}' component. If no beta
      information is provided, the platform is considered not in beta.
- term `--checkout-path <checkout-path>`:
                        The root path on disk of the repository's checkout.
- term `--source-service <source-service>`:
                        The source code service used to host the project's sources.
      Required when using '--source-service-base-url'. Supported values are 'github', 'gitlab', and
      'bitbucket'.
- term `--source-service-base-url <source-service-base-url>`:
                        The base URL where the source service hosts the project's sources.
      Required when using '--source-service'. For example, 'https://github.com/my-org/my-repo/blob/main'.
- term `--hosting-base-path <hosting-base-path>`:
                        The base path your documentation website will be hosted at.
      For example, if you deploy your site to `example.com/my_name/my_project/documentation` instead of
      `example.com/documentation`, pass `/my_name/my_project` as the base path.
- term `--transform-for-static-hosting/--no-transform-for-static-hosting`:
                        Produce a DocC archive that supports static hosting environments. (default:
                        `--transform-for-static-hosting`)
- term `--analyze`:               Include 'note'/'information' level diagnostics in addition to warnings and errors.
- term `--diagnostics-file, --diagnostics-output-path <diagnostics-file>`:
                        The location where the documentation compiler writes the diagnostics file.
      Specifying a diagnostic file path implies '--ide-console-output'.
- term `--diagnostic-filter, --diagnostic-level <diagnostic-filter>`:
                        Filter diagnostics with a lower severity than this level.
      This option is ignored if `--analyze` is passed.

      This filter level is inclusive. If a level of 'note' is specified, diagnostics with a severity up
      to and including 'note' will be printed.
      The supported diagnostic filter levels are:
       - error
       - warning
       - note, info, information
       - hint, notice
- term `--ide-console-output, --emit-fixits`:
                        Format output to the console intended for an IDE or other tool to parse.
-- term `-warnings-as-errors`:    Treat warnings as errors
- term `--default-code-listing-language <default-code-listing-language>`:
                        A fallback default language for code listings if no value is provided in the
                        documentation catalogs's Info.plist file.
- term `--fallback-display-name, --display-name <fallback-display-name>`:
                        A fallback display name if no value is provided in the documentation catalogs's
                        Info.plist file.
      If no display name is provided in the catalogs's Info.plist file or via the
      `--fallback-display-name` option, DocC will infer a display name from the documentation catalog
      base name or from the module name from the symbol graph files provided via the
      `--additional-symbol-graph-dir` option.
- term `--fallback-bundle-identifier, --bundle-identifier <fallback-bundle-identifier>`:
                        A fallback bundle identifier if no value is provided in the documentation
                        catalogs's Info.plist file.
      If no bundle identifier is provided in the catalogs's Info.plist file or via the
      `--fallback-bundle-identifier` option, DocC will infer a bundle identifier from the display name.
- term `--fallback-default-module-kind <fallback-default-module-kind>`:
                        A fallback default module kind if no value is provided in the documentation
                        catalogs's Info.plist file.
      If no module kind is provided in the catalogs's Info.plist file or via the
      `--fallback-default-module-kind` option, DocC will display the module kind as a "Framework".
- term `--experimental-documentation-coverage`:
                        Generate documentation coverage output.
      Detailed documentation coverage information will be written to 'documentation-coverage.json' in the
      output directory.
- term `--coverage-summary-level <symbol-kind>`:
                        The level of documentation coverage information to write on standard out.
                        (default: brief)
      The '--coverage-summary-level' level has no impact on the information in the
      'documentation-coverage.json' file.
      The supported coverage summary levels are 'brief' and 'detailed'.
- term `--coverage-symbol-kind-filter <symbol-kind>`:
                        Filter documentation coverage to only analyze symbols of the specified symbol
                        kinds.
      Specify a list of symbol kind values to filter the documentation coverage to only those types
      symbols.
      The supported symbol kind values are: associated-type, class, dictionary, enumeration,
      enumeration-case, function, global-variable, http-request, initializer, instance-method,
      instance-property, instance-subcript, instance-variable, module, operator, protocol, structure,
      type-alias, type-method, type-property, type-subscript, typedef
- term `--dependency <dependency>`:
                        A path to a documentation archive to resolve external links against.
      Only documentation archives built with '--enable-experimental-external-link-support' are supported
      as dependencies.
- term `--experimental-enable-custom-templates`:
                        Allows for custom templates, like `header.html`.
- term `--enable-inherited-docs`: Inherit documentation for inherited symbols
- term `--allow-arbitrary-catalog-directories`:
                        Experimental: allow catalog directories without the `.docc` extension.
- term `--enable-experimental-external-link-support`:
                        Support external links to this documentation output.
      Write additional link metadata files to the output directory to support resolving documentation
      links to the documentation in that output directory.
- term `--enable-experimental-overloaded-symbol-presentation`:
                        Collects all the symbols that are overloads of each other onto a new
                        merged-symbol page.
- term `--enable-experimental-mentioned-in`:
                        Render a section on symbol documentation which links to articles that mention
                        that symbol
      Validates and filters symbols' parameter and return value documentation based on the symbol's
      function signature in each language representation.
- term `--enable-parameters-and-returns-validation/--disable-parameters-and-returns-validation`:
                        Validate parameter and return value documentation (default:
                        `--enable-parameters-and-returns-validation`)
      Validates and filters symbols' parameter and return value documentation based on the symbol's
      function signature in each language representation.
- term `--emit-digest`:           Write additional metadata files to the output directory.
- term `--emit-lmdb-index`:       Writes an LMDB representation of the navigator index to the output directory.
      A JSON representation of the navigator index is emitted by default.
