# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.26.0] - 2026-09-24

Scripts are locked down everywhere Accent renders a page. Served pages carry a
per-response nonce, static builds carry script hashes, and the admin UI runs
without `'unsafe-eval'`, so an injected script no longer runs. Custom themes
with inline scripts or `onclick=`-style handlers need a one-line change per
script; the entries below say what it is and how to find what breaks first.

Components become a contract a theme can be checked against: canonical and
builtin components, manifests that describe their attributes, and an editor
that lists them. Plugins can declare their own Markdoc tags. Directory
previews with `accent serve <dir>` turn into navigable sites with search.
Releases add fully static Linux musl binaries for Alpine.

Three changes need action when you upgrade:

- **Plugin API 0.2.0.** A plugin built for 0.1.0 is refused at install and at
  load. Run `accent plugin update <name>` for each installed plugin.
- **`[shortcode]` syntax is removed.** Rewrite each one as a declared
  component, `{% name %} ... {% /name %}`.
- **A broken internal link fails `accent build`.** Pass `--lax` to report it
  as a warning instead.

The JSON REST API also moves in the static output layout; see Changed.

### Added

- **Served pages restrict scripts with a per-response nonce.** `accent serve`
  now appends `script-src 'self' 'nonce-...'` to every page's
  `Content-Security-Policy`, with a new nonce on every response and no
  `'unsafe-inline'`. A script runs only when it comes from the site's own
  origin or carries `nonce="{{ nonce }}"`, which every shipped theme now
  writes on each `<script>`; inline `onclick=`-style handlers are blocked.
  **Custom themes with inline scripts or handlers need the same change**: add
  the attribute and move handlers into a script, or set
  `http_headers.security.script_policy.report_only: true` to find what breaks
  first, or `enabled: false` to opt out. A `<script>` in page content is
  blocked on served pages. The admin UI and media keep the previous policy.
- **The admin UI runs without `'unsafe-eval'`.** The admin now uses the
  Alpine.js CSP build and htmx with `eval` turned off, and the editor preview
  is a page of its own that carries the site's script policy, so a `<script>`
  in a draft is blocked in the preview as it will be when published.
  `/_admin/` gets the strict script policy, report-only for now through the
  new `http_headers.security.script_policy.report_only_paths` (default
  `["/_admin/*"]`); set it to `[]` to enforce. `script_policy.exclude` now
  defaults to `[]`. A hotfix override of `alpine.min.js` must be the CSP build.
- **Static builds restrict scripts too.** A built page has no response to
  carry a nonce, so `accent build` records a `sha256` hash of each inline
  script marked `nonce="{{ nonce }}"` and the origin of each marked script
  from another host, then writes them into the page CSP of its header
  artifacts; `accent serve-static` sends the same policy. Scripts in content,
  and theme scripts without the attribute, are blocked in static output. The
  build manifest format changed, so the first build after upgrading is a full
  rebuild.

- **The admin lists what a theme's components are, and the editor inserts
  them.** `/_admin/components` is generated from the schema registry: each
  component's origin, attributes and body kind, with a page per component
  showing the call to insert and the markup its theme renders. A switcher reads
  each theme in the theme directory. The page editor gains a **Components**
  palette under the body toolbar that inserts a call with its required
  attributes stubbed, into CodeMirror or the plain textarea.

- **A component manifest declares what a `list` or `object` attribute holds.**
  A `list` names its item type under `items:` and an `object` its fields under
  `fields:`, nested up to eight deep, and `accent validate` checks every item
  and field, naming the path to a value that does not match, such as
  `links[1].label`. A `list` without `items:` or an `object` without `fields:`
  is a manifest error. The documentation theme's new `related` component takes
  its links this way.
- **Canonical components carry markup landmarks.** Every conforming theme marks
  a canonical component's root with `data-canonical` and its parts with
  `data-part`, so a script or a stylesheet can find a callout's title or a
  tab's panel under any conforming theme. The default, site-dev and starter
  themes carry them.

- **Plugins can declare Markdoc tags.** A plugin lists its tags in
  `[shortcodes] codes` and ships a component manifest for each in its
  `shortcodes/` directory, in the format a theme uses. Two settings decide what
  those tags may do: `plugins.components.schemas` (default `true`) validates
  content against the plugin's manifests, and `plugins.components.render`
  (default `false`) lets the plugin write the markup. With the defaults a
  plugin tag is validated and left in the page as written, and the log names
  the plugin and the setting. `accent validate` names a plugin that declares
  a tag and did not load, and `accent validate --lax` reports plugin component
  findings as warnings that do not fail the run. `accent query components`
  lists every tag content may use, where it came from, and what renders it.
- **Canonical components, and a check that a theme implements them.** Every
  theme implements the canonical components -- `callout`, `accordion`,
  `button`, `card`, `tag`, `image`, `breadcrumb`, `tabs` and `tab`, plus
  styles for the built-in `table` -- with fixed attribute names, so content
  that uses only them renders under any conforming theme. `accent validate`
  reports a theme that lacks one, with no content needed, and so does
  `accent validate --templates`. A page that uses a component the active theme
  does not declare is now told which theme and whether the component is
  canonical, in `accent validate` and in the build and serve logs. A theme
  that provides no components declares `components: none` in `theme.yaml`.
  `accent validate --lax` relaxes a theme's gaps and a page's missing canonical
  component, but not a name nothing declares, which may be a misspelling. It
  now combines with `--templates`.
- **Builtin components Accent renders itself: `download`, `video`, `diagram`
  and `search`.** `{% download %}` renders a file beside the page as a card
  with its name, type and size, the same card `pdf_card()` renders for a PDF.
  `{% video %}` plays a video beside the page with its WebVTT captions, and
  `accent validate` reports a video with no `captions` unless it says
  `captions="none"`, which `--lax` relaxes. `{% diagram %}` renders a diagram
  with a caption and alt text through the same pipeline as a fenced block, from
  its body or a `src` file. `{% search %}` places the search box in a page.
  A file these components link to must be a type Accent serves; for any other
  type, such as `.zip`, add its extension to `media.attachments.extensions`.
  Accent now serves `.vtt` caption files as `text/vtt`.

- **Search results highlight your term on the page they open.** Every
  result link now carries a text fragment built from the three longest
  words you typed, so the browser scrolls to the first match and marks it. No script runs
  on the page that opens; both bundled themes paint the mark yellow
  through `::target-text`, since Chrome's own default is a pale lilac.
  Chrome, Edge, Safari, and Firefox support text fragments; any other
  browser opens the page as before.

- **Rename a model field without editing every page.** A field can list its
  old names under `renamed_from: [teaser]`. A page that still uses an old
  name loads with the new one, and the next save from the admin editor, the
  CLI, or an agent renames the key in the file where it stands, keeping its
  value and comment. `accent validate` reports each page still on an old
  name and ends with a count per rename. A page that sets both names keeps
  the new one's value and gets a warning; saving that field in the editor
  settles it, and the value you were looking at is the one that stays.

- **Search and a light/dark toggle in the preview viewer.** A directory
  preview (`accent serve <dir>`) now has a search box in the header, backed
  by the index the preview already built; press `/` to jump to it. Every
  preview follows the system colour scheme and has a sun/moon button to
  read in the other one. The choice persists across pages and previews,
  and selecting the system's scheme again goes back to following it. The
  viewer also shows the Accent favicon.

- **`nav_tree()` template function.** Returns the page hierarchy as a
  nested tree (the root page, then `children` all the way down, each node
  with `url`, `title`, and `nav_title`, in `menu.order` then URL order),
  built once per render on the server, so a theme renders a site-wide
  navigation with one `{% for ... recursive %}` loop instead of scanning
  `all_pages` per level. Nesting follows each page's `hierarchy_url`, now
  on every listing entry (`all_pages`, `page.children`, and the rest), so a
  page a permalink pattern or a frontmatter `url:` moved stays under its
  directory parent. Handles a deployment base path and attaches a page
  whose parent has no page to its nearest ancestor. The built-in viewer
  theme's sidebar now uses it.

- **Directory previews honour `.gitignore`.** The auto-index walk behind
  `accent serve <dir>` (and `content.auto_index` on any site) now consults
  every `.gitignore` from the content directory down, with git's rules
  (anchored and directory-only patterns, globs, negations, last match
  wins), so pointing `serve` at a repository serves what git tracks.
  `content.auto_index.gitignore: false` opts out; `--write-config` records
  the flag.

- **Directory previews are navigable sites.** `accent serve <dir>` now
  gives every directory that holds markdown a section page: a directory
  with a `README.md`, `index.md`, or `default.md` keeps it, and one without
  gets a generated page listing its sub-sections and pages, so a tree with
  no root README is reachable from `/`. The built-in viewer theme gains a
  sidebar tree expanded along the path to the current page, breadcrumbs,
  and a home link; single-file and URL previews are unchanged. Hidden
  entries and the `node_modules` and `target` directories are skipped. The
  same behaviour is available to any site through
  `content.auto_index.enabled: true` (with `content.auto_index.ignore` for
  the skip list), and `theme.embedded: viewer` lets a config-driven site
  use the built-in viewer theme without a themes directory on disk.
- **`accent serve <dir> --write-config [PATH]`** writes a `config.yaml`
  that reproduces the preview (content directory, automatic section pages,
  the viewer theme or the `--theme-dir` theme, address and port, server-side
  diagrams) and then serves as usual. A relative `PATH` is resolved against
  the served directory; an existing file is never overwritten. The written
  config also drives `accent build` and `accent validate`.

- Ad-hoc serving (`accent serve <file.md>` / `accent serve <dir>`) renders
  fenced Mermaid and Svgbob blocks server-side as inline SVG. The synthesized
  config forces `diagrams.render_mode: server` for local targets, since the
  embedded viewer theme ships no client-side diagram loader; the viewer theme
  now styles the rendered `.diagram-wrapper` (responsive sizing, dark-mode
  backdrop, captions). Remote URL targets keep their existing third-party
  content posture.
- Alpine Linux support: releases now include fully static
  `x86_64-unknown-linux-musl` and `aarch64-unknown-linux-musl` binaries with
  no glibc requirement (and no runtime requirements at all), smoke-tested on
  Alpine before publishing. `install.sh` detects musl-based systems and
  selects the musl build automatically; glibc systems keep the existing gnu
  builds and their 2.28 floor.
- `install.sh --require-verify` (or `ACCENT_INSTALL_REQUIRE_VERIFY=1`) makes
  every skipped verification a failure: a checksums file, signature, or
  signing key that will not download, or a machine without `gpg` or
  `sha256sum`, now stops the install instead of warning. The default stays
  fail-open for the interactive one-liner. The deploy workflows run the
  installer from the checkout with the flag set, so a deploy either verified
  both the checksum and the signature or did not install at all.

- `api.rate_limit` throttles the API instead of documenting an intention to.
  It counts requests per minute per client against the API routes only, answers
  `429` with `Retry-After`, and reports `X-RateLimit-Limit`/`-Remaining`/`-Reset`
  on every API response. `0`, the default, stays unlimited. Behind a proxy, set
  the new `api.trust_forwarded_for` so clients are counted individually.

### Changed

- **The component inspector reads the theme once per edit.** An attribute
  edit read the theme directory and parsed every component manifest three
  times, on the async runtime, and validated the whole document to show one
  tag's findings. It now loads the registry once, off the runtime, and
  validates the tag's own node.

- **`accent serve` and `accent serve-static` start with a clean screen.** In a
  terminal, a box shows the version, edition, license, mode, and a link to the
  documentation, and a ready block shows the address and the time startup
  took. Timestamped log lines begin after it. `NO_COLOR` turns color off.
  Output to a file, a pipe, or a service is still timestamped from the first
  line and still includes `Listening on ...`. Internal startup lines, such as
  the watcher's poll interval and the search backend, now log at debug level;
  `RUST_LOG=accent=debug` shows them.

- **A broken internal link fails `accent build`; `--lax` reports it as a
  warning instead.** The build already resolved every internal link against
  its output. It now fails on a link whose target it did not write, listing
  every such link with the source file to edit and, for a draft, in-review, or
  scheduled page, the reason it was not written. Before upgrading, run the
  current release with `--strict-links` to find them. That flag is now
  deprecated: it is accepted, prints a notice, and is removed in 0.27. External
  links are still not checked.
- **`accent validate` reports a link to a draft or in-review page as an
  error.** It was an info finding, while the build now fails on the same link.
  The message says to publish the page or remove the link, and
  `accent validate --lax` relaxes it along with the component findings; its
  summary now reads `--lax: N findings reported as warnings`.

- **`gix` now comes from crates.io, moving 0.84.0 to 0.87.1.** The
  `zoosky/gitoxide` fork carries no patches, so Accent no longer pins a commit
  on it; the pin had fallen 1110 commits behind upstream. The update brings
  upstream fixes such as fallible pack-memory reservations. The `tree-editor`
  feature no longer exists upstream and is dropped. Accent's git code needed no
  changes. Fetch and push still use the system `git`, because gitoxide has no
  push yet.

- The default and starter themes use the canonical names: `alert` is now
  `callout`, with `type` in place of `variant`, and `details` is now
  `accordion`. The default theme keeps `infobox`, which released documentation
  versions use. `accent migrate shortcodes` still rewrites `[alert]` and
  `[details]`, because a component manifest can list the shortcode names it
  replaces under `migrate.from`, with any attributes it renamed.
- rustls 0.23.45 (from 0.23.43), for RUSTSEC-2026-0285: TLS 1.3 handshake
  messages were accepted across encryption level boundaries. It affects the
  development HTTPS server and `accent serve --tls`. The manifest now requires
  0.23.45, so the lockfile cannot move back below the fix.
- wasmtime 48.0.2 (from 48.0.1): code generated by `bindgen!` compiles on
  the latest Rust nightly, and Wasmtime vendors its `cap-primitives`
  dependency, so `cap-std` and `cap-fs-ext` leave the dependency tree.
- **`accent build` renders pages in parallel.** The render pass runs on all
  cores instead of one; building the 644-page documentation site falls from
  12.4s to 2.2s on a 28-thread machine. Output is byte-identical however many
  threads run -- pages are reduced in URL order -- and `RAYON_NUM_THREADS`
  caps the pool (`1` renders serially). When more than one page fails, the
  build now reports every failure together in URL order rather than stopping
  at whichever one a worker reached first.

- **The editor reads the compiled model schema.** The admin editor's form,
  the typing of a saved or previewed form post, the inline field check, and
  the model browser's field rows now read the JSON Schema a document model
  compiles to, instead of each re-deriving the model on its own. Nothing an
  author sees or saves changes. Two keys join the schema `accent model show
  --schema` prints: `x-accent-order`, which lists a model's fields in the
  order they are declared, on the model and on every `object` field that
  declares fields (the printed `properties` are sorted), and
  `x-accent-widget` on list items and
  map values, so a list of `string` and a list of `text` no longer read the
  same.
- **A quoted number is a string.** YAML says `5` is an integer and `"5"` is
  a string; model validation used to parse the quoted form and accept it for
  an `integer` or `number` field. That made a value's type depend on who
  asked -- validation called `order: "5"` an integer, while `as_i64` read it
  back as absent and a template comparing `order == 5` saw a string.
  Validation now reads what YAML resolved, so `order: "5"` is a type
  mismatch reported as `got string`. Nothing Accent writes is affected: the
  admin form, `accent content update-frontmatter --set`, and `accent new`
  all already emit real YAML numbers for a declared numeric field. A
  hand-authored page that quotes a number on such a field will now report a
  type mismatch; remove the quotes. An integer still satisfies a `number`
  field.
- **`min_length` and `max_length` count Unicode code points, not bytes.** A
  model field's length constraints were measured in UTF-8 bytes, so a
  70-character Open Graph title containing three em dashes measured 76 and
  was refused against `max_length: 70` -- and the message reported the byte
  count as though it were a length, so the author counted 70 and was told
  76. They now count code points, which is what JSON Schema's
  `minLength`/`maxLength` specify. For most text that is what you would
  call a character, but not always: an emoji built from several code points
  -- a flag, a skin-tone modifier, a family sequence -- counts as more than
  the one character it draws as, and so does a letter written with a
  combining accent. Content near a limit and not written in ASCII
  can change verdict: `max_length` becomes more permissive and `min_length`
  more strict, because code points never exceed bytes. No page in this
  repository's four sites changes verdict.
- **Component bodies render as markdown, and the manifest says how each is
  spliced.** A component body used to be passed through literally when the
  template put it inside a block-level element, and in `infobox` and
  `details` the first paragraph was literal while later ones rendered. The
  manifest's `body:` field now decides the splice: `body: markdown` (block
  content) arrives between blank lines, so the template's `<div>` closes
  before it and the whole body renders through the ordinary pipeline;
  `body: inline` (a label, such as a button's text) arrives flush. Every
  shipped component keeps `body: markdown` except `button`, which is now
  `body: inline` and `inline: true`, so it can be written on one line or in
  a sentence without a placement finding. A theme outside this repository whose label-bodied
  component declares `body: markdown` sees that label wrapped in a
  paragraph after this release: declare `body: inline` for it. `accent
  validate --templates` reports a `body: inline` body placed on a line that
  starts with a block-level tag, and an indented line after a
  `body: markdown` body.
- **Plugin API 0.2.0: the `json` value is UTF-8 bytes.** The one
  open-shaped value in the plugin contract (frontmatter, filter values and
  results, model defaults, media metadata, data-store values) crosses the
  Component-Model boundary as the bytes of one JSON document instead of a
  flat arena of typed nodes, so a Rust plugin reads it with `serde_json`
  and a JavaScript plugin with `JSON.parse`. The package is
  `accent:plugin@0.2.0` and the host's supported API range is now
  `0.2.0..=0.2.0`: a plugin built for 0.1.0 is refused at install and at
  load, and the load-time message names the fix, `accent plugin update
  <name>`. The hub resolver now falls back to the newest listed version
  this accent can run when the latest build targets a newer host, instead
  of refusing outright. The first-party plugins and both `accent plugin
  new` templates build on 0.2.0; their hub builds ship with the release.
  A payload that is not a JSON document is a plugin diagnostic (a template
  error for a filter, a warning for a model default or media metadata
  entry, an invalid-request for a data-store write), never a silently
  invented value.
- **Derived caches now carry a schema fingerprint.** Rendered pages,
  diagrams, processed media variants, and the incremental build manifest
  are keyed by one digest of the engine build, the document models (what
  each declares, so a comment or a reformatted model file changes nothing),
  the loaded plugins and their configuration, `theme.yaml`, the `media`,
  `code`, `diagrams`, and `markdown` config sections, and the site URL and
  base path, so an edit to any of them invalidates every derived artifact
  by construction. In `accent serve`, a `jpeg_quality` change followed by
  `SIGHUP` now reaches the next derivation (the processor used to keep the
  value it started with); processed-media variants live in one directory
  per fingerprint under the cache directory, and the directories of
  previous fingerprints are deleted when the value moves and at startup.
  The diagram cache key now carries the block options each renderer
  reads: width and height for Svgbob, the caption for the client-side
  markup, all of them for a plugin renderer. The first `accent build`
  after upgrading is a full rebuild: the manifest format moved to version
  3 and its hashes are SHA-256, which do not change with the Rust release;
  after that, a model edit rebuilds every page where it used to rebuild
  none, and so does a build under a different `--base-url`, which used to
  skip every page and leave the old prefix in every link.
- **The template context is now derived from its Rust types.** What a
  template can read is exactly the context structs, serialized: no
  hand-maintained mapping sits between them any more, so a new field
  reaches templates the moment it exists. Nothing a template reads
  changed -- snapshots of the context every page of the three sites in
  the repository receives were taken before the change and are identical
  after it -- and every internal URL still arrives joined with the
  deployment base path. A JSON Schema of the whole context is committed
  as a test snapshot, so a release's diff of that file is the list of
  changes to the theme contract.
- **Editing a page's frontmatter no longer reformats it.** An admin save,
  an MCP write, or `accent content update-frontmatter` now rewrites only the
  fields that actually changed: comments, blank lines, quoting style, and
  the order you put the keys in are preserved exactly as you wrote them.
  Saving a page you have not changed writes nothing at all. Previously every
  write rebuilt the whole block and re-emitted it, so the first save through
  the admin UI discarded every comment in a page's frontmatter.

- **Duplicate frontmatter keys are now a parse error.** Frontmatter parses
  through the same YAML policy as config and theme files (one parser for
  the whole tree; the second YAML engine is gone from the dependency
  graph). The previous frontmatter parser silently kept the last
  occurrence of a repeated key, so a page carrying, say, two `title:`
  keys -- or `1:` beside `"1":`, which normalise to the same key -- built
  without complaint and dropped one value. Such a page now fails to parse;
  the fix is to delete the losing key. Keys are compared after
  normalisation, so the colliding pair is not always literally identical.
- A UTF-8 byte-order mark at the start of a markdown file no longer hides
  its frontmatter: the block is parsed normally instead of leaking into
  the rendered body.
- Content write operations (`accent content update-frontmatter`, body
  edits through the admin editor, MCP mutations) refuse a file that opens
  a `---` frontmatter block it never closes, instead of silently building
  a second block in front of it. Such files still render (the
  unterminated block is treated as body, as before); only editing them
  through Accent asks you to fix the block first.

- **Breaking (static output layout): the JSON REST API is built where it is
  served.** `accent build` wrote the API to `_api/v1/pages/blog/post/index.json`
  while `accent serve` answered `/api/v1/pages/blog/post` -- a different prefix,
  a different path, and a file no static host serves for a directory request, so
  a frontend developed against the dev server could not read the built output.
  Both surfaces now derive every path from `api.prefix` (which neither read
  before), and every resource is written and answered at a `.json` URL:
  `/api/v1/pages/blog/post.json` resolves against `accent serve`,
  `accent serve-static` and a bare CDN alike. The old layout is gone; a
  consumer reading `_api/v1/.../index.json` moves to the new paths. The
  payloads were reunited too -- the built page detail had been dropping custom frontmatter
  entirely, writing `null` where the served one omits a field, and publishing no
  file for archived pages the API answers with 200.

### Removed

- **Breaking: `[shortcode]` syntax is gone.** Square-bracket shortcodes were
  expanded before the markdown parser ran; that stage no longer exists, and a
  page still holding the syntax renders the brackets as text. Declared
  components (`{% name %} ... {% /name %}`) replace them and add what the old
  form could not: a manifest saying what each component takes, so a misspelled
  attribute is reported by `accent validate` instead of rendering as nothing.

  `accent migrate shortcodes` rewrites a site and has **not** been removed with
  the syntax it reads, so upgrading late costs a command rather than a manual
  rewrite. Run it without `--write` first; it reports what it would change and
  refuses anything it cannot verify.

  Seven builtins were pure markup and are now components the default theme
  ships and your theme can redefine: `infobox`, `alert`, `tabs`, `tab`,
  `button`, `details`, `edition`. Five reached into parts of Accent a theme
  template cannot and have no content syntax any more -- `[diagram]`, `[pdf]`,
  `[figure]`, `[iframe]` and `[search]` -- each keeping another way in: a fenced
  ```` ```mermaid ```` block or `diagram()`, `pdf_card()`, markdown image syntax
  or a raw `<figure>`, a plain `<iframe>` element, and `search_form()` in a
  template.

  `[alert]` was a deprecated alias for `[infobox]` that resolved *ahead of* a
  theme's own `alert` template, so a theme shipping one never saw it render.
  `alert` is now whatever your theme declares; write `{% infobox %}` for the
  titled callout.

### Fixed

- **Admin pages are never cached.** Every page and fragment under `/_admin/`
  now carries `Cache-Control: no-store`. Before, with browser reload off, they
  carried the public page policy (`public, max-age=300, s-maxage=3600`), so a
  CDN or proxy in front of Accent could store an editor's page and serve it to
  others. `http_headers.cache` cannot override it.
- **Force save works after an edit conflict.** The button in the conflict
  dialog sent nothing, because it aimed at the save bar the dialog had
  replaced. It now saves, and a second conflict opens a fresh dialog in the
  same place.

- **`accent hotfix apply` writes `hotfix.yaml` completely.** The overlay's
  provenance file ended mid-line, so every `git diff` of it reported
  `\ No newline at end of file` and line-oriented tooling miscounted the
  last entry. The file is also written atomically now, through a temporary
  file that is renamed over it, so an interrupted run leaves the previous
  manifest intact instead of a truncated one. (b219)

- **The developer site scripts bind loopback, and the specs site commits
  no credential.** The shared worktree selector behind every `scripts/*.sh`
  site script forced `0.0.0.0`, so every developer site was reachable from
  the local network whatever its config said, and `specs/config.yaml`
  paired that with an admin UI behind a token committed in plain text.
  Each site's config now decides its own bind, and every config that mounts
  an admin UI binds loopback; `--address 0.0.0.0` after the selector is the
  opt-in. The specs config and the admin-dev config defer their admin token
  to the environment, the specs config its Basic Auth password too, and the
  site scripts generate what is missing per worktree and print it. An
  unexpanded `${VAR}` placeholder no longer counts as an admin token, and
  the login page and the startup log name the variable to set. (b203)

- **CI rejects a duplicate spec identifier.** Two sessions filing specs on
  one day both listed the directory, saw the same gap, and claimed it, and
  nothing rejected the second claim until a hand renumber PR. A check on
  every spec change now fails a PR whose merge result holds two files under
  one identifier or a spec under the wrong family directory, and its
  `--branches` mode does the pre-filing scan across unmerged branches. (b308)
- **`/_health/git` reports the sync status without SMTP.** The probe
  answered `{"status":"disabled"}` unless mail notifications were
  configured and compiled in, so a git-backed publisher without an SMTP
  server had no HTTP-reachable sync status. Every fetch, from a webhook
  delivery or from polling, now records its outcome in the server state,
  and the probe reports it, the boot refresh and the last error text
  included; `disabled` means only that `git.enabled` is off, and a server
  that has not fetched since startup says `unknown` rather than `ok`.
  (b282, b309)

- **The service preflight tests no longer race for a released port.** The
  fixture picked a port by binding and releasing it, and the address check
  bound it again, so under the parallel test runner another test's
  ephemeral listener could land in between and add an "in use" finding
  to a test about something else. The probe is a parameter now: production
  binds, and a test that is not about the address passes one that always
  says free. (b283)

- **`git.sync.poll_interval` polls.** The field was declared, documented
  as the fallback for a forge that cannot reach the server, and read by
  nothing: a publisher without a working webhook stayed on the commit it
  booted on. A polling task now runs the webhook's fetch every
  `poll_interval` minutes on a publisher serving in production, under the
  same lock and with the same outcome handling, so a push reaches the site
  within the interval. Dev servers and authors never poll. (b201)
- **`accent new --field` writes values the page loads back as typed.** A
  list item was written raw, so `tags=Blog: a post,rust` scaffolded a
  mapping where a string was meant and the page failed to load, and a
  leading `#` vanished as a comment. Every scalar and every list item now
  goes through the YAML serializer; a list item takes the model's declared
  item type, so an integer list stays numeric; empty segments from a
  trailing comma are dropped; and a multi-line item continues under its
  dash. (b220)

- **Two builds of the same content produce the same search index bytes.**
  `_search/docfind_bg.wasm` differed between builds of identical content,
  which invalidated it at every deploy and blinded byte-level build
  comparisons: the keyword extractor ordered equal-score keywords by hash,
  so the per-document keyword budget kept a different subset each run.
  The DocFind fork now orders them by score, then by where they first
  appear in the text, so two builds of the same content give the same
  search index and the same rendered files; only the build manifest's
  timestamp differs between them. (b226)
- **A scheduled page is written on the day it becomes visible, a page
  reaching its unpublish date is rendered again as archived, and a page
  that is a draft again loses its output.** An incremental build decided
  what to render from content and template hashes, which a passing date
  never moves, so the page was listed by the sitemap, the feeds, and the
  search index but had no file behind it. The build manifest now records
  each page's effective status on the build date and rebuilds a page whose
  status moved, with no edit; a page that is no longer visible has its
  HTML, markdown companion, paginated continuations, and API detail file
  removed, which `--dry-run` announces; and every build-side pass reads one
  build date. (b256)
- **`accent cache clear` empties the processed-media cache too, and a
  deleted or renamed media file loses its variants.** The command cleared
  only the diagram cache, and nothing invalidated processed variants when
  the admin deleted or renamed their source or when a media file changed
  under hot reload, so stale variants stayed on disk until capacity
  eviction. The command now clears both caches and reports each, with
  `--diagrams` and `--media` to limit it; the admin operations drop the
  source's variants; hot reload watches the shared media directory too and
  drops the variants of a changed file by name; a config reload forgets
  the entries whose files a clear removed. (b238)

- **Generated documentation no longer references internal spec IDs.** 218
  doc comments across 121 source files named a feature, bug, research,
  implementation, architecture, or epic tracker ID, which `cargo doc` and
  `accent docs` rendered for readers who cannot resolve it. Every one is
  reworded to name the thing instead, the ID moved to a plain code comment
  beside the item, and a check in CI and both local gates keeps the count
  at zero. (b224)

- **`accent build --dry-run` writes nothing, and `--clean --dry-run` deletes
  nothing.** A dry run copied the theme assets, compiled the styles, and
  wrote the fingerprinted copies into the output before printing that no
  files would be written, because the rebuild plan needs the fingerprint
  manifest and the manifest needs the compiled CSS on disk; with `--clean`
  it also removed the output directory first. The dry run now skips the
  output preparation and does the asset work in a temporary directory that
  goes away with the plan, so the output directory is neither created,
  changed, nor removed. (b305)

- **A build under another `--base-path` into the same output directory
  rewrites its redirect stubs.** The permalink, `.md` extension, and
  versionless redirect stubs refused to overwrite a file that differed from
  what they would write, which is right for another pass's output and wrong
  for their own stub from the previous build whose target moved, so a prefix
  change left every stub unprefixed and the conformance check failed the
  build. The build manifest now records the stubs a build owns; the next
  build rewrites those, and only those, when their targets move, adopts a
  stub it finds byte for byte as its own, and removes a recorded stub it no
  longer emits instead of leaving it to dangle. Anything else at a recorded
  path stays. (b254)

- **A rebuild into the same output directory no longer adds a fingerprinted
  copy of every theme asset per build.** The fingerprint pass walks the
  output `theme/assets/`, where compiled styles live, so from the second
  build on it hashed its own copies and wrote `editions.<hash>.<hash>.css`,
  one more segment per build, and nothing removed them. A file shaped like a
  copy of a sibling that exists beside it is now a copy, never a source: the
  current one is left in place, and a stale one, an old hash or a doubled
  name, is removed once the build has succeeded, so the directory holds one
  copy per asset however often you build into it. A file the theme ships
  under a hash-shaped name beside something the build does not fingerprint
  is left alone. The emitted HTML was never affected. (b255)
- **An incremental build after a stylesheet edit renders every page again
  when fingerprinting is on.** The `fingerprint` filter writes the hashed
  URL of an asset into every page that links it, and no page hash saw the
  asset behind it, so a build without `--clean` after a stylesheet edit
  rendered only the pages whose content changed and left every other page
  linking the previous hash. The build manifest now records a digest of the
  fingerprint manifest, and a change to it is a full-rebuild axis, like the
  theme and schema hashes. (b304)

- **An enum drop-down shows the file's value even when it is not a declared
  one.** A component attribute or frontmatter field holding a value outside
  its declared set displayed the first declared option, while the finding
  beside it named the real value. The value is now a selected option of its
  own.

- **Ignored directories and the site's own config file are no longer served
  or published.** On a site whose content directory is the tree root, as
  `accent serve <dir> --write-config` writes it, every image, HTML, JSON, or
  YAML file under `node_modules/` or under a path the tree's `.gitignore`
  hides was a public URL, and so was the site's `config.yaml`. With
  `content.auto_index` on, what the loader hides is now not a static asset
  either, at the bare page URL, under `/content-media/`, or in the build
  output; and the loaded config file is never served or published in any
  layout. The preview and the deployed site answer the same media URLs.

- **`accent build` refuses an output directory inside the content
  directory.** A site whose `content.directory` is `.`, which
  `accent serve <dir> --write-config` writes, built to the default `output`
  inside its own tree. The page-local media pass then copied the output as
  page media, then the copy, until the path was longer than the filesystem
  accepts. The build now refuses such an output directory before it writes
  or cleans anything, naming both directories, and `--clean` refuses an
  output directory that contains the content directory, since cleaning it
  would delete the site. The same guard covers every directory the build
  reads: an output inside a mount source, the media directory, the theme's
  `assets/`, or the `.well-known` directory is refused too, since the next
  build would read it back, and with `--clean` the output directory may not
  be, contain, or lie inside any input directory, the theme, models, data,
  and plugin directories included.

- **`accent validate` no longer reports "Can't nest" warnings for valid
  Markdown.** A page with an HTML comment and a tag reported "Can't nest
  'text' in 'document'" at line 1, and bold, italic or link text that wraps
  onto a second source line reported "Can't nest 'softbreak' in 'strong'".
  The documentation site went from 608 warnings to none. The first came from
  accent-proust, fixed in 0.12.1; for the second, Accent allows line breaks
  inside emphasis and links when it validates.

- **A directory preview no longer polls build output and `.git`.**
  `accent serve <dir>` watched the whole directory, so serving a repository
  polled every file under `target/`, `node_modules`, and `.git` twice a
  second, and reloaded the page whenever a build or a `git` command wrote
  there. The watcher now skips what the preview skips: hidden entries, the
  `content.auto_index.ignore` names, and gitignored paths. The same applies
  to a plain `accent serve` of a `--write-config` preview. `accent serve
  <file>` watches only the file's own directory.

- **`accent build` leaves media URLs in code samples alone.** A page that
  showed a processed-image URL such as `/media/hero.jpg?w=960` in a code block
  or inline code got a `Media source not found` warning for each query. When
  the site also had real processed images, the build rewrote the sample to a
  generated filename such as `/media/hero-960w.jpg`. Code samples now build as
  written, and a missing source image is reported once, naming a page that
  uses it.

- **Pagination works on static hosts.** A paginated collection linked its
  pages as `/blog/page:2`, but the build wrote them to `blog/page/2/`, so on a
  deployed static site every link past the first page was a 404. Pages now
  live at `/blog/page/2` under both `accent serve` and `accent build`, and
  `accent serve` redirects the old `/blog/page:2` form permanently. A
  collection on the home page linked `//page:2`, which browsers read as
  another host; it now links `/page/2`.
- **Builtin components under a base path linked to the prefix twice.** With
  `site.base_path: /repo`, `{% download %}`, `{% video %}` and `{% search %}`
  wrote `/repo/repo/...`. The prefix is now applied once, including a video's
  `poster`.
- **`accent init --docs` includes the files its pages link to.** The docs link
  a sample script under `media/downloads/`, which scaffolds did not include.
- **`diagram()` shows a caption once when the diagram renders in the
  browser.** With `diagrams.render_mode: client`, or `hybrid` in dev, a
  `caption` rendered twice: once in the browser renderer's figure and once in
  the wrapper's.
- **Site search no longer throws on a short query, and a new query
  restarts keyboard selection.** Typing a single character logged a
  `ReferenceError` from the search script, and after arrowing through
  results, typing more kept the old selection, so Enter could open a
  result other than the highlighted one. Affects every theme that uses
  `search_form()`.
- **`search_form()` renders nothing while search is disabled.** With
  `search.enabled: false`, a theme that called it unconditionally rendered
  a search box that could not work, and `accent build` output carried a
  script tag for a `_search/search.js` the build never wrote.
- **A `future_only` or `past_only` bound on an object sub-field is
  enforced.** A temporal constraint one level down -- `event.when:
  { type: date, past_only: true }` -- was only reported when something else
  on the same field already had a finding, so a page whose one problem was
  a date on the wrong side of now validated clean. `accent validate`,
  `accent build`, the admin save, and the publish gate all report it now.
  A page relying on the gap reports a new warning, or a new error under
  `content.validation.mode: strict`; the fix is to correct the date or drop
  the bound.
- **A URL built by a template helper can no longer break out of its
  attribute.** `media()`, `url()`, `cdn_url()` and `pdf_card()` mark their
  result safe so a URL's own delimiters survive into the page, but part of
  that result is author input: a `"` in a component attribute or a
  frontmatter field closed the attribute and opened another, so content
  could add a live event handler to a theme's `<img>` or `<a>`. Those
  helpers now percent-encode the characters that may not appear in a URI
  and that end an attribute. No ordinary URL changes, and an
  already-encoded path is left alone.
- **A component's link works on a sub-path deployment.** A component
  template writing `href="{{ attrs.href }}"` emits the autoescaped
  `&#x2f;` spelling of a root-absolute link; the base-path rewriter read
  only the literal spelling and left it unprefixed, which the build's
  conformance check then failed. Both spellings are now rewritten.
- **A page that opens with a component gets a readable description.**
  Component tag syntax reached the derived lead -- and so the meta
  description, the social-card text, the `llms.txt` summary and the search
  snippet -- and both search indexes tokenised attribute names as content
  terms. Tag syntax is now stripped alongside raw HTML, keeping the tag's
  body, and code samples showing a tag are preserved.
- **Editing a component manifest hot-reloads.** A `shortcodes/*.yaml` edit
  was classified as an uninteresting change, so the dev server kept serving
  the cached page with the old declaration while the component's template
  half reloaded normally.

- **Loading a content directory that holds build output no longer takes
  minutes.** The content scan indexed every non-markdown file as a media
  asset and, for upload duplicate detection, read and hashed each one; a
  repository root with 145 GB of build artifacts under auxiliary target
  directories took over five minutes to load on every command. The hash is
  now computed only for a file an upload could produce (within
  `admin.media.max_upload_mb`, MIME type on `admin.media.allowed_mime_prefixes`);
  everything else stays indexed without one. `accent serve <dir>` also
  prints a scanning line before the load.
- **Pages that name a template the viewer theme lacks render instead of
  returning 404.** Under the embedded viewer theme (`accent serve <dir>`,
  `accent serve <file>`, `theme.embedded: viewer`) a page with an explicit
  `template:` from another theme returned 404 in serve and aborted the
  build; serve, build, and the admin preview now share one rule and fall
  back to the viewer's `default` layout. A theme on disk keeps the loud
  error for a missing explicit template.

- Every string round-trips through the YAML writer and reader, block
  scalars included. Four shapes the writer spelled in a form the reader
  read back differently are fixed in the YAML library: a value that is
  exactly one newline read back empty; a value ending in two newlines
  gained a newline on every save when another field followed it; a value
  whose first line is spaces only produced a file the reader refused; and
  a list item whose first line starts with a space or a tab read back with
  two extra spaces. The round-trip property tests that found them now run
  with no exclusions (b212).
- A duplicate key in `config.yaml`, or in a page's frontmatter, is
  reported with its path and position (`site.name: duplicate key "name"
  at line 3, column 3`) instead of the bare key name.
- A frontmatter field name containing `[`, `]`, or `*` is written as key
  text. The lossless editor handed every path to the YAML library's query
  grammar, which reads `[n]` as a sequence index and `*` as a wildcard: a
  `--set a[x]=1` wrote the key `a`, and a `--remove a[x]` deleted `a`. The
  grammar gained a quoted form for such a segment, and the editor spells
  every segment through it, so such a field is added, changed, removed, and
  renamed under its own name like any other (b234).
- A `${VAR}` placeholder under a config key containing `.`, `[`, `]`, or `*`
  (`site.meta` names such as `og.type`, a versioning bucket like
  `v0.26-dev`) is expanded in place like any other. Such a key used to send
  the whole file down the tree route, which rewrote every number-like
  string in it (`01234` loaded as `1234`) and moved a type error's position
  out of the file, and only a debug line said so. The one site that still
  takes that route, a placeholder inside an anchored value, is logged as a
  warning naming it (b235).
- Config values keep their spelling when environment placeholders are
  expanded. A string value that YAML would read as a number, such as an
  SMTP password `01234`, was rewritten to `1234` every time `config.yaml`
  loaded, because `${VAR}` expansion re-emitted the parsed tree before the
  typed read; the server then authenticated with the wrong secret and
  reported nothing. Expansion now edits the file text in place, so every
  value outside a placeholder reaches the config exactly as written, and a
  type error after an expanded line reports the line number in your file
  rather than one in an internal buffer (b227).
- A frontmatter field name containing a non-printable character (a line
  break, DEL, a C1 control, or the non-characters U+FFFE and U+FFFF; tab
  is allowed and written as an escape) is refused by name before anything
  is read or written: the MCP `update_frontmatter` and `create_page` tools
  return an invalid-params error, `accent content update-frontmatter
  --set` and `--remove` exit with the key named, and every content API
  write -- the admin save and the content agent included -- refuses the
  operation. Previously an agent-supplied key with a newline in it reached
  the writer, and before the YAML emitter fix collapsed the page's
  frontmatter into a single string (b212).
- A page whose frontmatter cannot be parsed no longer vanishes silently.
  The scan now logs a warning naming the file and the error (`serve` and
  `build` both show it), `accent build` still ships every other page, and
  `accent validate` reports the skipped file as an error and exits 1 --
  previously it printed "No issues found" over the dropped page.
- Theme templates HTML-escape `{{ ... }}` expressions again. The explicit
  auto-escape callback introduced with the Markdoc bridge returned
  `AutoEscape::None` for every non-component template, believing that was
  MiniJinja's default for `*.html.jinja` names; the default in fact strips
  `.jinja` and applies HTML escaping, so authored values had always been
  escaped -- and briefly were not (b223).

- Site protection (`protection.basic_auth`, `protection.ip_allowlist`) on a
  server started without `--production` is enforced whether or not
  `dev.browser_reload` is on. The free-in-dev allowance keyed off the
  browser auto-refresh setting, so turning that off on an unlicensed dev
  server silently served every path open, with one WARN per request that
  blamed licensing. The gate now follows the `--production` flag alone;
  under `--production` a Standard or Pro license still decides.
- A Basic Auth username or password that is still an unexpanded `${VAR}`
  placeholder at startup refuses to start, naming the user entry and the
  variable. Before, an unset `SITE_AUTH_PASSWORD` protected the site with
  the literal string `${SITE_AUTH_PASSWORD}` -- a value written in the
  config file. Empty credentials are rejected the same way;
  `${VAR:-default}` keeps working and authenticates with the default.
- The HTTPS token for git-backed content no longer appears in the `git`
  child's command line. It reaches the credential helper through the
  child's `GIT_REMOTE_TOKEN` environment variable; argv carries only the
  variable's name, as the module documentation had claimed all along.
- The Linux release binaries run on Debian 10, Ubuntu 20.04, RHEL 8,
  Amazon Linux 2023 and newer again. v0.25.0 needed glibc 2.39 and refused
  to start on Debian 12 and Ubuntu 22.04, because both Linux targets
  inherited the glibc of whatever image built them (`ubuntu-latest` and the
  cross-rs `main` image both moved to Ubuntu 24.04). Both targets are now
  linked against a pinned glibc 2.28 floor, the release build checks the
  produced binary against that floor, and a smoke job runs each Linux
  archive on a glibc 2.28 base before anything is published. The aarch64
  Linux binary also embeds the dependency SBOM now, like every other target.
- `install.sh` runs the binary once before installing it. A binary that
  cannot start on this system is no longer installed under an
  "Installation complete!" message: the installer exits 1 with the loader's
  error, the glibc version the release needs and the one the system has,
  and leaves any earlier installation untouched.
- Hot reload watches document models. Editing a model in the project
  `models/` directory, in the theme's `models/`, or in a plugin's `models/`,
  or a `_model.yaml` under `content/`, during `accent serve` now rebuilds
  the content index and reloads the browser, so validation, the admin
  schema browser, and the editor field views show the new schema on the
  next request. Before, the edit stayed invisible until an unrelated
  content or template save, an admin page save, SIGHUP, or a restart. A
  file the watcher cannot classify (an editor swap file, a README) no
  longer reloads the browser either.
- `api.allowed_origins` is honoured. The legacy `api.cors` layer applied
  permissive CORS regardless of the list, so the documented way to restrict
  origins in production did nothing. `["*"]`, the default, is unchanged.

## [0.25.1] - 2026-08-29

A bugfix release for the v0.25 line. The reason for it is the Linux release
binaries: v0.25.0 was built against glibc 2.39 and refused to start on
Debian 12 and Ubuntu 22.04, while the installers reported success over it
(the installer side is fixed independently, in `install.sh` and `accentup`
0.1.2). Alongside that, the fixes from master that change what the binary
does -- a git-backed publisher whose files on disk stopped following the
deploy branch, and two JSON API defects -- plus wasmtime 48.0.1.

Cut from a maintenance branch off the `v0.25.0` tag rather than from
`master`, so it carries these fixes and none of the 0.26 development work.
Anyone whose licence ceiling is 0.25 can take it.

### Fixed

- The Linux release binaries run on Debian 10, Ubuntu 20.04, RHEL 8, Amazon
  Linux 2023 and newer. v0.25.0 needed glibc 2.39 because both Linux targets
  inherited the glibc of the image that built them (`ubuntu-latest` and the
  cross-rs `main` image both moved to Ubuntu 24.04). Both targets are now
  linked against a pinned glibc 2.28 floor, the release build checks the
  produced binary against that floor, and a smoke job runs each Linux
  archive on a glibc 2.28 base before anything is published. The aarch64
  Linux binary also embeds the dependency SBOM now, like every other target.
- A git-backed publisher's working tree follows the deploy branch. The
  webhook fetched the branch and served markdown from the new commit, but
  the files on disk -- media, page-local assets, the theme, document models
  -- stayed at whatever the first clone produced, so a push that added a
  page and an image served the page and returned 404 for the image
  indefinitely. The checkout is now reset onto the fetched tip before the
  reload, and again at boot, for the publisher role only; untracked files
  survive.
- The JSON API renders page content through the same pipeline as the HTML
  page. `api.include_content` ran the bare markdown renderer, so shortcodes
  (`[infobox]`, `[figure]`, `[tabs]`, diagrams) reached API consumers as
  literal bracket text while the HTML page rendered them. Both `accent
  serve` and the `accent build` output are covered.
- The JSON API's page detail keeps its `files` list, and the static build no
  longer drops error pages, redirect pages and rewrite targets from the API
  output or keys a rewritten page under its target's URL.
- Hot reload watches the project `models/` directory. Editing a document
  model during `accent serve` now invalidates the index and reloads the
  browser instead of serving the stale schema until an unrelated save.
- `accent --version` reports the commit hash when the binary was built
  outside a git checkout instead of an empty string.
- A page miss on a public origin logs at debug rather than info, so
  commodity scanner probes (`/wp-admin.php`, `/.env`, ...) no longer fill
  the default log.

### Changed

- wasmtime 48.0.1 (from 48.0.0): context slots in component compositions
  are managed correctly, and WASIp2 HTTP requests set the `Host` header by
  default.

## [0.25.0] - 2026-08-21

The hub becomes usable from the command line. 0.24 turned the plugin registry
into an ecosystem hub and gave the binary the client to read it; this release
finishes the loop -- themes install from it, plugins and themes report when
they are behind it, `accent init --template` discovers starter templates
through it, and a retracted artifact is refused rather than quietly installed.
It also gains the half of the commerce contract that was missing: a paid
artifact downloads freely and is verified at the point of use, so a third party
can list one and charge for it.

`hub.accentcms.dev` goes live alongside this release as the catalog those
commands read, generated from the same registry documents by the same engine.
The three sites -- product, documentation, hub -- now navigate as one.

Under the plugin runtime, Wasmtime moves to the 48.0.0 LTS line, which carries
24 months of guaranteed security backports where an ordinary release gets two.
That was the runtime target from the start and it is the last item of the
Component-Model replacement epic.

### Added

- **`accent theme install <name>`, and themes in the hub.** Themes install from
  the registry the way plugins already did, with the same vendor-key pinning
  and the same `--allow-unverified` escape hatch. `accent theme list --remote`
  reads the registry, `theme info` shows an artifact's detail, and `theme
  outdated` reports what has moved on.

- **`accent plugin update`, `plugin outdated`, and `plugin search`.** An
  installed artifact can now tell you it is behind, and you can find one
  without opening a browser. `search` reads the mirrored registry index, so it
  works against whatever the hub last published.

- **Retraction is honoured end to end.** A retracted version is refused at
  install and reported by `outdated`, so a artifact withdrawn for a defect or a
  security problem stops spreading rather than remaining installable until
  someone notices.

- **`accent init --template <name>` discovers starter templates through the
  registry.** The built-in templates still ship; the registry adds to them
  rather than replacing them, and `--list` shows both.

- **Commercial artifacts are verified where they are used, not where they are
  downloaded.** A paid plugin, theme or template downloads freely and is
  checked at the point of use -- a plugin at component load, a theme at
  activation, a template before scaffolding -- against a vendor-signed licence.
  A missing or wrong licence is refused with the reason named. This is the
  scheme m053 specified and only half of which shipped.

- **`load_data()` works during `accent build`.** The template function that
  reads a site's data files now runs in static builds, not only under `accent
  serve`, which is what lets a generated catalog be built at all.

- **Scheduled link health.** A site's link index can now be re-checked on a
  schedule, so a link that rots after publication is noticed rather than
  waiting for a reader to find it.

- **`accent license buy --cadence <yearly|monthly>`.** The purchase flow
  carries the billing cadence, which selects the product; yearly (owned)
  remains the default.

### Changed

- **The plugin runtime moves to Wasmtime 48.0.0 LTS.** LTS releases carry a
  24-month support window with guaranteed security backports, against two
  months for an ordinary major -- which is the reason this line was the target
  for a runtime that executes third-party code. It also brings Cranelift
  dead-store elimination and, on Linux, `process_madvise` for the pooling
  allocator. Plugin sandbox semantics are unchanged: Wasmtime collapsed its
  separate directory and file permission flags into one read-only/read-write
  choice per grant, which is exactly the distinction Accent's grants already
  made.

- **`accent license buy` and `license renew` go through the issuance service.**
  They previously opened a hardcoded payment-provider URL. The service is what
  creates the checkout, signs the key, and hands it back to the waiting
  command, so the binary never talks to the payment provider directly and never
  holds a signing key. `renew` now opens a checkout for the edition and cadence
  of the current licence; if a subscription has already renewed, the new key is
  emailed and `accent license activate` installs it.

- **Dependency updates.** `h2` (see below), `moka` 0.12.16, `rmcp` 3.1.3,
  `rustls-webpki` 0.103.14, and the `wasm-tools` family.

### Fixed

- **A cache defect that shrank capacity over time.** `moka` 0.12.16 fixes a
  race that could leak a phantom entry slot on every occurrence, so a
  long-running server's usable cache capacity fell below its configured maximum
  and its reported entry count drifted above the truth.

- **`h2` denial-of-service advisory (RUSTSEC-2026-0258),** plus the follow-up
  that made the fix's own frame limiter ignore end-of-stream frames -- without
  which it could reject legitimate traffic.

- **`llms.txt` no longer wastes a machine reader's budget.** Five defects in
  one generator: a section's index page was published twice, as the heading and
  again as the first entry; sections were ordered alphabetically by directory
  rather than by the `menu.order` the navigation already uses, so the first
  section a context-limited reader sees was arbitrary; a truncated section
  looked identical to a complete one, so ten entries of a fifty-page section
  read as the whole list; an authored `lead:` was cut mid-word at 120
  characters; and `llms-full.txt` published HTML comments as visible text.

- **An authored `description:` is used when there is no `lead:`.** A page
  carrying a description no longer publishes a truncated body excerpt instead
  of the sentence its author wrote. An authored `lead:` still wins where both
  are set.

## [0.24.1] - 2026-08-16

A bugfix release for the v0.24 line. The reason for it is the plugin
host-services defect below: a contact form against any real mail relay
delivered the message and then reported it to the visitor as a failure, so
the natural response -- submit again -- delivered a duplicate. It is invisible
in every local setup, because a local mail catcher answers fast enough to stay
inside the budget.

Cut from a maintenance branch off the `v0.24.0` tag rather than from `master`,
so it carries these fixes and none of the 0.25 development work. Anyone whose
licence ceiling is 0.24 can take it.

### Fixed

- Plugin `host-services` calls no longer trap the guest for time it spends
  waiting on the host. The per-call budget was wall-clock, and the epoch
  ticker kept counting while the guest sat suspended in `send-mail` or a
  data-store write, so a relay that took longer than 50ms -- which is every
  real relay, once TCP, STARTTLS, authentication and the remote `250` are in
  the path -- killed the guest on its next instruction with the send already
  committed. The budget now meters guest execution: a plugin is credited the
  time it was suspended, while a plugin spinning in its own code still trips
  the deadline exactly as before.
- `plugins.render_budget_ms` (default `50`) exposes that budget in
  `config.yaml` for the first time. It was previously unreachable, and the
  plausibly named `plugins.timeout_ms` is really `diagrams.plugins.timeout_ms`
  -- a different subsystem, governing diagram rendering -- so setting it had
  no effect on a route handler and left no further lead.
- Markdown: `~` written for "approximately" no longer renders as subscript.
  Two unescaped tildes in one paragraph paired into a `<sub>` span that
  swallowed the text between them and stranded the surrounding `**` as
  literal asterisks, which reached published documentation. A subscript span
  containing whitespace is now left as written; `H~2~O` and `CO~2~` are
  unaffected.
- The bundled documentation theme (`accent init --docs`) is usable on a
  phone. Its header did not collapse at any width and needed a 491px
  viewport, so below that the search button and theme toggle sat off the
  right edge, the page scrolled sideways, and every control was under the
  44px touch minimum. The navigation now collapses into a disclosure panel,
  search keeps its place in the bar, and the documentation sidebar drawer
  gained the keyboard and focus behaviour it was missing.

### Changed

- Subscript no longer spans whitespace. `~one word~` is still subscript;
  `~several words~` now renders literally. This is stricter than the markdown
  parser's own rule and is what makes the "approximately" fix possible.

## [0.24.0] - 2026-08-14

The plugin surface and the development server both change shape here, and both
changes are breaking. Plugins now reach the host through a typed WIT capability
instead of the `/_internal/*` HTTP bridge, which is removed -- mail and the data
store work during `accent build` for the first time, and a plugin's data
namespace is derived by the host, so one plugin can no longer read or overwrite
another's. The registry those plugins install from has become the ecosystem hub,
serving plugins, themes and starter templates as single signed archives under a
document a pre-0.24 binary cannot read; upgrading is the only remedy. A bare
`accent serve` now binds HTTPS and negotiates HTTP/2, so the live-reload stream
no longer permanently occupies one of the six connections a browser allows per
origin -- the cause of the reported intermittent hangs -- and `--no-tls` restores
the previous behaviour exactly.

Templating moves several behaviours onto Jinja2 semantics, and document models
now govern the core frontmatter fields. The remainder is a broad correctness
pass: serve-versus-build parity, config-reload safety, search indexing that no
longer treats page markup as text, and a set of panics that used to take down a
connection, a request path, or every request at once.

### Added

- **`build.routing` completes the generated Apache artifact, so it can finally
  replace a hand-written one.** The routing directives accent emits are derived
  -- they express the URL shape the build already committed to. Three more are
  the opposite, knowable only to the operator: `error_document`,
  `canonical_host`, and a `redirects` list. Without them a generated
  `.htaccess` was not yet a complete substitute for a hand-maintained file,
  which is why both of this project's own sites still copied one over the top
  of the build output -- silently discarding the routing fix. Both sites now
  generate their artifact instead, and neither deploy workflow can overwrite
  it. `canonical_host` 301s the host's www/apex counterpart (not every other
  host, which would capture preview deployments); a redirect `to` starting with
  `/` carries `base_path` while anything else is used verbatim. The block is
  inert when absent, so an untouched site emits byte-identical output. Values
  are validated at emit time -- a host carrying a scheme, a relative source, a
  status outside 301/302/307/308, or whitespace in any argument fails the build
  rather than writing a directive Apache would misread. The canonical-host rule
  is emitted before the clean-URL rewrite, because mod_rewrite re-runs a
  per-directory ruleset after an internal rewrite and the other order sends
  `www/about` to `/about/index.html`. No equivalent exists for the `netlify`
  target, whose redirects live in a `_redirects` file this generator does not
  write, so configuring both fails closed rather than shipping a deployment
  missing its rules. Verified end to end against Apache 2.4.66.

- **The Apache `.htaccess` artifact now carries routing, not just headers.**
  accent advertises no-slash URLs (`/about`, not `/about/`) in its sitemap,
  feed, `llms.txt` and every page's `<link rel="canonical">`, but Apache's
  `mod_dir` 301-redirects each of them to the slash form before serving --
  so on an Apache host *every URL the sitemap listed was a redirect*, which
  Search Console reports as "Page with redirect" instead of indexing the
  page. The emitted file now turns that around and serves the advertised URL
  directly, and adds `Options -Indexes` because the rewrite makes index-less
  directories addressable. When the home page lives in a `home/` directory
  and is therefore served at the site root as well, a `301` from `/home` to
  `/` is emitted too, so only the advertised URL is reachable; a site with
  its own page at `/` keeps both, since those are two different pages.
  Requires `mod_rewrite` and `AllowOverride` covering `FileInfo` and
  `Options`; a host without `mod_rewrite` keeps the previous redirect
  behaviour rather than breaking, because the `DirectorySlash` change sits
  inside the module guard. Only the `apache` target changes -- Netlify
  already serves these URLs correctly. Verified end to end against Apache
  2.4.64, at the site root and under a `base_path` sub-path deployment.

- **`build.header_artifacts` carries your header configuration into a static
  build.** Everything under `http_headers` used to be serve-only, because
  `accent build` writes files and files carry no HTTP headers. On static
  hosting the whole header story silently evaporated: the security headers
  (nosniff, frame options, referrer policy, the page and strict-media CSPs),
  cache-control policy, and the attachment semantics that make a published
  `.sh` download instead of rendering. The last of those is not a nicety --
  the force-download protection against scriptable SVGs is an XSS defence, and
  it was absent from every static deploy. Nothing reported the gap, because
  `accent validate` and dev `serve` both model the serve runtime.

  ```yaml
  build:
    header_artifacts: ["netlify", "apache"]   # default: [] -- emit nothing
  ```

  `netlify` writes `_headers` (the dialect Netlify and Cloudflare Pages
  share), `apache` writes `.htaccess` (`mod_headers` directives). Both are
  generated from the same `http_headers` config `serve` reads, so there is one
  source of truth and no hand-maintained copy to drift, and both respect
  `base_path`. The default emits nothing, so an untouched site builds exactly
  as before.

- **`accent package --trust <official|verified|community>`.** The manifest's
  provenance tier is now settable, defaulting to `community` exactly as before.
  It used to be hard-coded, which meant every first-party submission had to
  hand-edit a generated document whose whole point is to be machine-produced,
  machine-checked, hashed and signed. Hard-coding it stopped nobody either --
  the field is a line of JSON. What actually decides the outcome is unchanged
  and lives in the registry: `official` requires the entry's repository to be
  owned by the `AccentCMS` organisation, `verified` an author record the
  maintainers have marked identity-verified, and a claim that fails is rejected
  rather than downgraded. The command now says what each non-default tier
  requires at the moment it writes the claim, so an unqualified submitter learns
  it before CI tells them.

- **`island:` directives accept a namespaced component name.** A plugin island
  declared as `my-plugin:word-count` can now be used from content as
  ```` ```island:my-plugin:word-count ````. One namespace prefix is allowed and
  each half accepts letters, digits, `-` and `_` only, so a component name still
  cannot become a path. Namespacing is what `accent package` and the registry's
  checks have always recommended -- island components register into one global
  registry per page and the loader resolves them last-registration-wins, so a
  plugin island and a theme island sharing a bare name collide silently -- and
  the directive could not express it until now.

- **TCP keep-alive on the `accent serve` listeners.** A client that disappears
  without closing its connection -- a slept laptop, Wi-Fi power-save, a NAT
  rebinding, a crashed browser tab -- used to leave the server-side socket
  `ESTABLISHED` until the OS retransmission timeout fired, typically 16 minutes
  or more, holding a descriptor and stalling anything written to it (a
  hot-reload event, for instance). Both the HTTP and HTTPS listeners now enable
  keep-alive probes, and so does every connection they accept: idle 60s, probe
  every 10s, dead after 3 unanswered probes, so a vanished peer is reaped in
  about 90 seconds. HTTPS additionally sends an HTTP/2 `PING` every 30 seconds
  with a 10-second acknowledgement deadline. No configuration; on by default. A
  platform that refuses the socket option logs a warning at startup and serves
  normally.

- **Typed plugin host services (`host-services` capability).** Plugins now
  send mail and use the data store through a typed WIT capability
  (`send-mail`, `data-write`, `data-read`) instead of HTTP calls to the
  server's own `/_internal/*` endpoints. The manifest opts in per service
  with `host_services = ["mail", "data"]`; the data-store namespace is the
  plugin's own name, derived by the host, so one plugin can no longer read or
  overwrite another plugin's data. Host services also work during
  `accent build`, where the HTTP bridge never could. The bundled
  contact-form plugin is ported and no longer needs any network capability.

### Removed

- **The `/_internal/*` plugin HTTP bridge.** `/_internal/smtp/send`,
  `/_internal/data/write`, and `/_internal/data/read` are gone, along with the
  outbound-HTTP address-guard exemption that let a plugin reach them and the
  `server_port` value the host injected into every plugin's config so it could
  build the URL. **This is a breaking change for a plugin that sends mail or
  stores data by POSTing to `http://127.0.0.1:{server_port}/_internal/...` with
  `allowed_hosts = ["127.0.0.1"]`.** Such a plugin still loads, but the call is
  refused by the address guard. The server warns at load time when a manifest
  allowlists a host that could reach loopback (`localhost`, a loopback IP
  literal, or the bare `*` wildcard), and that warning now states that such a
  plugin's calls are already failing. Port to the `host-services` capability
  above -- it needs no allowlist entry, no port, and no JSON envelope.

  If your plugin used the data store, note that the capability derives the
  namespace from the plugin's own name instead of taking it from the request.
  A plugin that wrote under some other namespace must move its directory once
  (`mv _data/<old-namespace> _data/<plugin-name>`) and repoint every
  `load_data("<old-namespace>", ...)` call in its templates. Both fail silently
  if missed -- a read from a namespace that does not exist returns nothing
  rather than erroring. The third consequence does not: because the namespace
  is now a directory name, a plugin that declares `host_services = ["data"]`
  with a name that is not a legal namespace (lowercase `a-z`, `0-9`, `-`, `_`,
  at most 128 characters) is **refused at load** with an error naming the rule,
  rather than accepting submissions and dropping every one of them.

  Removing the bridge also returns the outbound-HTTP address guard to an
  unconditional non-public-address block: loopback is refused for every plugin
  request, whatever the URL path.

### Changed

- **`accent serve` now uses HTTPS in development mode.** A bare `accent serve`
  binds TLS with a self-signed certificate and negotiates HTTP/2, instead of
  plain HTTP/1.1. The reason is the live-reload stream: it is a long-lived
  server-sent-events response, and over HTTP/1.1 it permanently occupies one of
  the six connections a browser opens per origin, leaving five for everything
  else. Under a coincident reload-stream reconnect, a fresh navigation, and
  parallel asset loads, a request could sit waiting for a free slot -- the
  reported "sometimes a request just hangs". HTTP/2 multiplexes every stream
  over one connection, so the contention does not exist.

  **This is a breaking change to the default invocation.** A CI job, smoke
  test, or script that runs `accent serve` and then fetches `http://…` must
  either switch to `https://` (accepting a self-signed certificate) or add the
  new **`--no-tls`** flag, which restores the old behaviour exactly.
  `--no-tls` cannot be combined with `--tls`, `--cert`, or `--key`.

  `accent serve --production` is **unchanged** and still binds plain HTTP --
  deployments terminate TLS at a proxy that expects HTTP/1.1 upstream. Pass
  `--tls` there to opt in, as before.

  The certificate covers `localhost`, `127.0.0.1`, and the bind address, and
  is **cached**, so the browser warning appears once rather than on every
  restart: macOS `~/Library/Caches/dev.accentcms/dev-cert/`, Linux
  `$XDG_CACHE_HOME/accentcms/dev-cert/`, Windows
  `%LOCALAPPDATA%\accentcms\dev-cert\`. Set `ACCENTCMS_DEV_CERT_DIR` to store
  it elsewhere -- test harnesses should point it at a scratch directory. On the
  first start the server prints the certificate path together with the
  platform-specific command that installs it into the trust store, which
  removes the warning entirely. It is valid for a year and regenerates
  automatically when it expires, when either file no longer matches its
  recorded digest, or when it stops covering the host names in use.

  A **wildcard bind** (`server.address: 0.0.0.0`, the documented way to reach
  the dev server from another machine) is the one case Accent cannot infer:
  it does not know which address the visitor will type, so the certificate
  covers loopback only and a phone reports a name mismatch. The server warns
  about this at startup; set **`ACCENTCMS_DEV_CERT_SANS`** (comma-separated)
  to the address you will visit, or use `--no-tls`.

  `accent serve --production --tls` also uses a self-signed certificate, but
  **never writes it to disk** -- a production serving key does not belong in
  a cache directory that eviction tooling and profile backups treat as
  disposable. Each start mints a fresh one, exactly as before this change.

  `accent serve-static` follows the same default, so a build checked with the
  live server and with the static preview is reached over the same scheme.
  It has no `--production`, so **`--no-tls` is the only way to get cleartext
  there** -- a CI smoke test that curls `http://127.0.0.1:4403/...` after
  `accent build` needs that flag added.

  `accent serve --docs --production` is now **rejected**. It was always a
  no-op (the embedded docs server has no production mode and the `--docs`
  path never reached the license gate), and with the TLS default reading
  `--production` its only remaining effect would have been an unannounced
  switch to cleartext. Use `--docs --no-tls`.

  Admin session cookies now carry `Secure` whenever the server is serving
  TLS, not only under `--production`. A cookie minted over HTTPS without it
  is one the browser will replay over plain HTTP to the same host.

- **The plugin registry is now the ecosystem hub, and older binaries cannot
  read it.** `AccentCMS/plugin-registry` has become `AccentCMS/hub-registry`,
  and its v1 `registry.json` is deleted. One registry now serves plugins,
  themes and starter templates, each version listed as a single checksummed,
  signed archive rather than a set of loose files.

  **A pre-0.24 `accent` fails against it**, with

  ```
  registry returned HTTP 404 Not Found: https://raw.githubusercontent.com/accentcms/plugin-registry/main/registry.json
  ```

  The remedy is to upgrade; there is no shim, and none is possible -- the two
  formats share no document. Nothing was ever installed from v1: it never held
  an entry, which is why the break was worth taking now rather than never. Its
  successor is empty at first too, so `install` reports that an artifact is not
  listed, which for the first time is a true statement rather than the only
  answer the registry could give.

  The registry URL also moved in configuration: `plugins.registry_url` is gone,
  replaced by a top-level `hub.registry_url`. A config still carrying the old
  key gets a startup warning naming the new one. Three per-kind URLs for one
  registry would have been three chances to drift, and theme and template
  installs must work in a build with no plugin runtime compiled in.

- **Templating: booleans and none now print Jinja2-style.** The template engine
  moves to MiniJinja 2.22, which spells printed primitives the way Jinja2 does:
  `{{ some_boolean }}` renders `True` or `False` instead of `true`/`false`, and
  a none renders `None` instead of `none`. **This is a breaking change for a
  theme that prints a frontmatter boolean into markup** -- typically an HTML
  attribute a script reads back (`data-featured="{{ page.custom.featured }}"`)
  or a hand-built JSON literal. Both now carry a capitalised token that
  `JSON.parse` rejects and a `=== "true"` comparison misses, and neither
  errors, so the breakage is silent.

  Fix by asking for the web spelling explicitly: `| lower` for attributes,
  `| tojson` for JSON and `<script>` blocks.

  ```jinja
  <article data-featured="{{ page.custom.featured | lower }}">
  <script type="application/json">{"featured": {{ page.custom.featured | tojson }}}</script>
  ```

  Only *printing* is affected -- `{% if page.custom.featured %}` is unchanged,
  as is `| tojson` output, which was always correct JSON. No shipped Accent
  theme prints a bare boolean, and a full 476-page build of the documentation
  site was compared across the two versions with no rendered difference.
- **Templating: string filters keep their input's safe marking.** `upper`,
  `lower`, `title`, `capitalize`, `trim`, `replace`, `indent`, and `join` now
  carry safety provenance through the transformation, so
  `{{ page.content | safe | trim }}` is no longer re-escaped. `join` still
  escapes unsafe items individually when the separator is safe.
- **Templating: `split` returns a sequence.** Its result can be indexed from
  the end and sliced without an intervening `| list`, so
  `{{ page.url | trim("/") | split("/") | last }}` works.
- **Templating: a `{% set %}` inside a `{% for %}` no longer leaks between
  iterations.** Each iteration now starts with loop-local assignments unset,
  matching Jinja2. A template that relied on the leak to carry a value forward
  must use a `namespace()` instead.
- **Document models now govern the core frontmatter fields.** `title`, `date`,
  `author`, `lead`, `tags`, `status`, and the rest are declared by a built-in
  model named `core` that every model inherits automatically. Declaring one of
  them in your own `fields:` overrides the core declaration and is enforced --
  `date: { required: true }` in a blog model finally blocks a dateless page
  instead of doing nothing.

  **This is a breaking change for sites whose models already list core fields.**
  Those declarations were silently inert; they now take effect, so a site may
  see a burst of validation issues on legacy content. That is the fix working.
  Review the reported pages, or relax the model, before upgrading a build that
  runs with `content.validation.mode: strict`.

  A few smaller consequences:

  - A model may **constrain** a core field but not **retype** one -- `title`
    holds a string, `tags` holds a list. A model declaring
    `title: { type: number }` is now refused at load time, with the other
    models around it unaffected. Inside `module_models:`, where a name like
    `media` may well mean something local, only the offending field is
    dropped: the module's other fields keep validating and the build stays
    green. `core` is a reserved model name, but `extends: core` is accepted --
    it says explicitly what every model does implicitly.
  - `required: true` on `title` or `lead` asks for a value the author wrote.
    Accent fills both in when they are omitted (`title` from the first heading
    or the filename, `lead` from the opening paragraph), and a filled-in value
    does not satisfy the demand.
  - A `date:` is validated against the same formats the loader accepts, so
    `March 15, 2026` and `15.03.2026` pass a `type: date` check exactly as they
    already load.
  - A `defaults:` entry for a core field that always has a value (`status`,
    `published`, `anchors`, `process`) never fires, because such a field is
    never absent. Publishing status is owned by the workflow, not by a model
    file.

- Field definitions accept `editable: false`, which keeps a field out of the
  admin editor's form pane while leaving it validated and available to
  templates. A new `type: any` declares a key whose shape is genuinely open.

- The admin editor's form pane renders the page's model rather than a
  hand-maintained widget list, so a model that relabels or requires a core
  field is reflected in the form. An input left empty now clears its
  frontmatter key instead of writing an empty value, and a value the author
  did not change is not materialised into the file -- an untouched Lead no
  longer freezes the excerpt derived from the body. Two exceptions keep those
  rules from destroying content: an empty Title leaves the stored title alone
  (the box is never empty when the form opens, so an empty one is a mistake,
  not an instruction), and a value the model marks `required` is written even
  when the author did not change it. A frontmatter value the form cannot
  display -- a nested block the schema does not name -- is no longer offered as
  an empty text input, so saving cannot silently delete it.

  Because the form pane now renders the whole model, the body field sits behind
  every frontmatter control. The editor gained a **Skip to body editor** bypass
  as its first focusable element -- invisible until focused -- and pressing Esc
  in the body now lands on the Save button instead of dropping focus onto the
  page. Reaching the body and reaching Save are one keystroke each again.

### Fixed

- **A panic while a plugin reload held the registry lock could 500 the whole
  site, permanently.** `AppState::plugins` is read on the way through every
  page request; a `std::sync::RwLock` is poisoned for the life of the process
  once a thread panics while holding it exclusively, and every read site then
  aborted -- which, with the catch-panic guard also new in this release, meant
  a `500` for every page from a server that kept accepting connections and
  passing its health probe. Dev hot reload held that write guard across
  reading a plugin's `.wasm`, parsing its `plugin.toml`, and compiling and
  instantiating a Wasmtime component: the largest body of fallible work in the
  tree, in the position where a panic did the most damage, running on every
  plugin file change. Loading a plugin is now two phases -- compile first,
  with the registry lock released entirely, then swap under it -- and the
  registry lock recovers from poisoning instead of aborting, logging one error
  naming the lock the first time it does. What the swap displaces is torn down
  after the guard is released, not under it, and registry teardown on a config
  reload moved off the guard too. Three things improve on the way past: a
  plugin recompile no longer stalls requests while it runs (it also no longer
  occupies an async worker thread), a hot reload whose replacement does not
  compile leaves the previously loaded plugin serving instead of removing it
  first and failing into a gap, and one save that rewrites both `plugin.toml`
  and `plugin.wasm` recompiles the plugin once rather than twice.

- **The homepage is advertised at the root, not at `/home`.** A home page
  living in a `home/` directory is reachable at two URLs -- its authoring
  URL, and the site root, which `accent serve` resolves through it and
  `accent build` writes the root `index.html` from. Both return 200 with the
  same content, and `sitemap.xml` listed the authoring one, endorsing the
  duplicate and pointing search engines away from the URL a reader visits.
  Both sitemaps (serve and build) now list the root, and themes get a new
  `page.canonical_url` for `<link rel="canonical">` and `og:url` so the tag
  agrees with the sitemap entry naming it -- the two are produced by
  different code, and disagreeing was worse than either form alone. Both
  bundled themes are updated; a theme still reading `page.url` for its
  canonical tag keeps the old value. Unaffected unless your homepage lives
  in a `home/` directory *and* no page maps `/`: a site with both keeps two
  distinct pages with two distinct URLs.

  Extended to the remaining outward-facing surfaces: `feed.xml` item links
  (a reader that de-duplicates by link would otherwise treat the two URLs as
  different articles), `llms.txt` and `llms-full.txt`, and the JSON-LD
  `url`/`mainEntityOfPage`/breadcrumb entries.

  `accent serve` now also **301s `/home` to `/`**, so the duplicate is gone
  rather than merely unadvertised. Both forms take a single hop: `/home/`
  lands on `/` directly rather than passing through `/home`. Static
  deployments get the same redirect from the generated `.htaccess`.

- **Admin page lists no longer reorder between renders.** Sorting by a field
  that two pages share -- the same modified time, the same date, the same
  title -- left their relative order to `HashMap` iteration, which is
  re-randomised every time the content index is built. The dashboard's
  *Recent* list was the visible one, and the tie is the ordinary case rather
  than the exotic one: a checkout, a sync or a generator stamps many files
  with one mtime, and on a filesystem coarser than APFS two files written
  back to back are already equal. URL now breaks every tie, as it always did
  for menu-ordered lists.

- **A panicking request answers `500` instead of dropping the connection.**
  Nothing sat between the render and the socket, so a panic in a filter, a
  template function, or the markdown pipeline unwound the connection task
  without writing any HTTP response at all -- the client saw a reset or an
  empty reply, which reads as a network fault and sends the operator to the
  proxy or the TLS terminator before the renderer. Both `accent serve` and
  `accent serve-static` now answer a typed `500` carrying the site's normal
  security, CORS and cache headers, and log the panic with the request method
  and public path; the panic hook still writes its backtrace, so the location
  and the URL that reached it are both on record. No known panic path remains
  in the render pipeline -- this is containment for the next one, and it
  covers every route, every middleware layer, and the sub-path URL mapper.
  `accent build` gained the equivalent for every phase that renders a
  template: a panic now ends the build with `rendering page '/docs/...'
  panicked: ...`, or the name of the pass it happened in (taxonomy, feeds,
  sitemap, error pages), instead of a backtrace naming nothing. The build
  still fails rather than skipping the page, deliberately: a deployable tree
  silently missing a page is worse than no tree.

- **A packaged template keeps its `.gitignore`.** The template contents list
  had no place for a root ignore file, so packaging one reported it as *"not
  part of a template artifact"* and left it out. The same starter then
  scaffolded two different projects -- present via the copy embedded in the
  binary, absent via a registry install -- and the registry-scaffolded one
  committed its own caches and build output the first time its author ran `git
  add -A`, which is the state the file exists to prevent, at the moment a new
  user is least able to notice it. A template may now carry one, and should:
  its contents become the user's project. A plugin or a theme installs into a
  subdirectory of a project that already has an ignore file, so a root
  `.gitignore` is still not part of either. Ignore files inside an included
  directory -- a theme's `assets/.gitignore` -- were always archived and still
  are.

- **`accent package` no longer leaves untracked output in your repository.**
  Its `--out` default, `dist/`, is now ignored in this repository, and the
  publishing guide tells artifact authors to ignore it in theirs. An archive is
  a few tens of kilobytes, so nobody notices it until it is in a commit.

- **The registry's admission gate no longer reports a missing artifact as a
  host outage** (`hub-registry` 0.3.0). An `artifact.url` returning 404 or 410
  was classed `artifact/unreachable`, the category whose CI message reads *"this
  is not a rejection -- re-run this job when the host is back"*. It is a
  rejection: the host answered, and it will answer the same way forever. That
  landed on the most common first-time mistake -- opening the submission before
  uploading the release -- and told the submitter the one thing guaranteed not
  to help. A 404 or 410 is now `artifact/not-published` and names both causes
  (the release is not uploaded, or `artifact.url` points elsewhere); connection
  failures, timeouts and 5xx keep the unreachable class and its own exit status.
  Internally the HTTP status now survives a failed download instead of being
  flattened into a message, which is what made the split possible without
  parsing prose.

- **`accent plugin install` says so when the project will not load what it just
  installed.** A plugin installed into a project whose configuration leaves the
  plugin system off is inert: the files are on disk and checksum-verified, no
  hook runs, its routes 404, and any island it just advertised never hydrates.
  Nothing errored, so there was no message to search for -- the user read
  "Installed", saw the directory, and concluded the plugin or the CMS was
  broken. It falls exactly on a new user's first day, because the `starter`
  template ships the plugin block commented out. The install now prints a note
  naming `plugins.enabled` and the config file to set it in. It stays a note and
  not a refusal: installing into a project you intend to enable later is
  legitimate.

- **The bundled `accent-contact` plugin's islands are namespaced
  (`accent-contact:word-count`, `accent-contact:reading-time`), shipped as
  0.2.0.** The bare names it declared before are close to the likeliest names a
  theme author would pick for the same two widgets, and the collision is silent
  -- one registration overwrites the other and the page renders the wrong
  component with no diagnostic. Both `accent package` and the registry's
  validator warned about it, on the first `official` plugin in the catalog: the
  artifact a third party reads to learn what a well-formed plugin looks like was
  demonstrating what our own tooling tells them not to do. **If you used the
  0.1.0 island names in content, update the directives when you upgrade.** The
  published 0.1.0 manifest is immutable and untouched.

- **`accent build` no longer deletes markup that follows a media URL.** The
  build's media-URL scanner ended its query capture at a double quote or
  whitespace and nothing else, while scanning whole HTML files rather than
  just attribute values. A `/media/...?w=...` URL written in HTML **text
  content** (a page documenting the query syntax, say) or inside a
  **single-quoted attribute** therefore swallowed the markup that followed it,
  and the rewrite -- which replaces the whole match with the variant filename
  -- dropped that markup from the built page. `<img src='/media/hero.jpg?w=960'>`
  lost its closing quote and `>`; a code span lost its `</code>`. It was silent
  because only queries that parse cleanly reach the rewrite, and the query
  parameters accepting free-form strings (`fit`, `fmt`, `thumb`) parse happily
  with a tag glued on. Affects `accent build` only when media processing is
  enabled and at least one variant is generated; `accent serve` processes media
  on the fly and was never affected. Double-quoted attributes, the common case,
  were always correct.

- **`page.prev` / `page.next` no longer skip pages or disagree with
  `page.siblings`.** Prev/next ordered the sibling sequence by `menu.order`
  and then by **title**, while the hierarchy index -- which `page.siblings`,
  `page.children` and every listing read -- orders the same sequence by
  `menu.order` and then by **URL**. The tiebreaker only fires when siblings
  share a `menu.order`, so numbered content trees were never affected; but a
  flat directory without numeric filename prefixes gives every page order `0`,
  and there prev/next followed the prose of each page's title instead. Pages
  were skipped, the two navigations on a single page stepped through the same
  siblings in different orders, and prev/next reported a different "last page"
  than the sidebar. Prev/next now reads the ordered child list from the index
  rather than re-deriving it, so the two orders cannot drift apart. A sibling
  the reader cannot see -- an archived page, or a draft outside
  `dev.show_drafts` -- is stepped over rather than ending the sequence, again
  matching what the listing beside it shows.

  **This changes prev/next ordering** on any site where sibling pages share a
  `menu.order` -- it now matches what listings on the same page already
  showed. Sites whose sections carry distinct `menu.order` values, including
  every numeric-prefixed tree, are unaffected.

- **A page's lead is published as plain text, so its meta description reads as
  a sentence.** A lead becomes `<meta name="description">`, `og:description`,
  `twitter:description`, the page's `llms.txt` entry, its RSS item description,
  its entry in the JSON APIs, and whatever a theme shows in a listing -- none
  of which can render markup, and several of which escape nothing at all. It is
  now plain text at every one of them.

  Two things were wrong. When a page has no `lead:`, Accent CMS derives one
  from the first paragraph, and that derivation stripped markdown but not HTML:
  a page whose body opens with a layout block (`<header>`, a hero `<div>`) got
  a lead made entirely of tags, and not even its own prose, since the block
  *is* the first paragraph and the real opening sentence never entered the
  excerpt. Raw HTML is now removed before the paragraph is chosen, so an
  opening block with no visible text is skipped entirely and the excerpt comes
  from the first real sentence below it. Separately, a `lead:` written by hand
  was passed through with its markup intact, which reached feeds, `llms.txt`
  and generated markdown raw.

  HTML you are *documenting* still survives: markup inside a fenced block, an
  indented block, or an inline code span is kept, the same guarantee the search
  index already made. **Your content files are never rewritten** -- the strip
  applies to the published view, so a `lead:` you wrote stays exactly as typed
  in your frontmatter and in the editor.

  **This changes published output**: meta descriptions, social-card
  descriptions, `llms.txt` entries and feed item descriptions change on the
  next build of any site with such a page.
- **Theme assets serve the right `Content-Type` again -- `.woff2` and
  `.webmanifest` in particular.** The theme-asset route misspelled `woff2` as
  `wof2` in both the extension and the media type, so the arm matched nothing
  and every WOFF2 font a theme self-hosts was served as
  `application/octet-stream`; `.webmanifest`, `.webp` and `.avif` had no entry
  at all. The misspelling had also reached the cache-policy table, which
  matched the same phantom type and had no `font/woff2` arm, so fonts missed
  the year-long `immutable` policy meant for exactly them. Browsers sniff
  fonts and generally loaded them anyway -- unless the site sends
  `X-Content-Type-Options: nosniff` -- but proxies and CDNs select compression
  by media type, so a mislabelled font or manifest also shipped uncompressed.
  Static builds behind a normal web server were never affected: the host
  supplies its own mapping, and the generated `_headers`/`.htaccess` files
  carry cache policy rather than content types -- they are unchanged. The
  theme route, the page-sibling static-asset route and the build's
  header-artifact generator now share one extension table, so an extension
  added for one is typed for all; what each route may *serve* is unchanged.
  Two smaller corrections ride along: `.js` is now `text/javascript`
  (RFC 9239 obsoletes `application/javascript`), and `.mjs` is recognised.
- **A config reload no longer switches dev features back on in production.**
  `--production` disables hot reload, browser reload, the debug query
  parameter, and draft visibility, but it did so exactly once, when the CLI
  arguments were applied. A `SIGHUP` (or `POST /_admin/reload`) re-read
  `config.yaml` from disk and put all four back -- and because `hot_reload` and
  `browser_reload` default to on, a config that simply never mentions them was
  enough. The visible symptoms ranged from a production server quietly serving
  unpublished draft pages, to fingerprinted stylesheets failing Subresource
  Integrity checks in the browser because the reloaded config flipped the asset
  pipeline to its unminified output while the `integrity` attributes still
  described the minified bytes. A reload now re-applies the production clamp
  before anything reads the new config, and warns when an explicitly-set
  `dev.debug` or `dev.show_drafts` is overridden; a production server also
  refuses to start a file watcher at all.
- **A config reload no longer discards the path and theme command-line
  flags.** `--theme`, `--theme-dir`, `--content-dir`, and `--site-dir` were
  applied to the config once at startup and appear nowhere in `config.yaml`,
  so a `SIGHUP` reverted to whatever the file said. A server started with
  `--theme dark` against a config naming `default` silently swapped its entire
  live theme on the first reload -- including reloads triggered incidentally
  by a deploy hook or `systemctl reload`. The overrides are now replayed on
  every reload. `--address` and `--port` are deliberately not replayed: the
  listener is already bound, so changing those still needs a restart.
- **A config reload no longer serves mismatched asset bytes while it
  finishes.** The reload published the new fingerprint manifest and template
  engine well before it cleared the page and style caches -- a gap that
  spanned the plugin-registry rebuild, so seconds on a site with WASM plugins.
  During it, cached pages referenced hashed URLs the new manifest could not
  resolve (404), and freshly rendered pages could be answered from the stale
  style cache with pre-reload bytes under a `Cache-Control: immutable`
  content-addressed URL whose SRI hash no longer matched, pinning the wrong
  bytes in browser and CDN caches. Theme, manifest, engine, and caches now
  move together, after all fallible work has succeeded -- so a reload that
  fails on a bad template also leaves the previous, self-consistent set live
  instead of a half-applied mixture.
- **Search results no longer render indexed page content as HTML.** The
  client-side renderer built its result list by concatenating the indexed title
  and snippet straight into `innerHTML`, so raw HTML in a page body became live
  elements in the results: the browser re-nested the following results inside
  them, which showed up as phantom results with missing titles and a result
  list the arrow keys could not walk. Where page authorship is not fully
  trusted it was also a stored-XSS path -- a page body could run script in the
  session of anyone who searched. Titles and snippets are now escaped, with
  query highlighting applied on top, so markup in content is displayed as text.
  Affects both search backends, which share the renderer.
- **Raw HTML in a page body is no longer indexed as searchable text.** Tags,
  HTML comments, and `<script>`/`<style>` bodies are dropped before the text is
  tokenized, so `div`, `class` and `header` are no longer search terms on every
  page that uses them for layout, and result snippets show prose rather than
  markup -- including on pages with no `lead:` of their own, whose snippet is
  derived from the first paragraph. HTML inside a code block or an inline code
  span is kept, so a page documenting `<div>` stays findable by searching
  `div`; this covers four-space indented blocks as well as fenced ones. Only
  what the renderer treats as markup is removed, so angle brackets your page
  actually displays -- `a < b`, or an example written as `<angle brackets ...`
  -- remain searchable as the words they are.
- The `truncate` filter no longer panics when the cut falls inside a multi-byte
  character. Its length now counts characters rather than bytes, so
  `{{ page.title | truncate(60) }}` keeps 60 characters of an accented, CJK, or
  emoji-bearing title instead of crashing the render. Text at or below the
  limit is also returned whole now -- the byte comparison used to append an
  ellipsis to a non-ASCII string that already fit.
- Template rendering no longer panics when a comparison has no lossless common
  representation (such as a float against an integer too large for `f64`), and
  no longer overflows the stack on repeated sequence concatenation. Iteration
  over map items is faster. A Python-compatible dict method is no longer
  shadowed by a map key of the same name. All four come from the MiniJinja 2.22
  upgrade.
- The page meta description now falls back to the typed `lead:` frontmatter
  field as documented. It previously consulted only custom frontmatter, so a
  page with a `lead:` got the site-wide description instead. `page.lead` is
  also exposed to templates for the first time.
- A model constraining a module field, a taxonomy field, or a filename pattern
  field by a core name resolved it against custom frontmatter, where core
  fields never appear -- reporting a module's `title` as missing, reading a
  core-named taxonomy field as empty, and skipping `{date}` filename
  cross-checks. All three resolve through the same accessor now.
- `accent new` resolves `{date}` and `{title}` filename-pattern tokens against
  the frontmatter it is about to write.
- `accent validate` no longer flags a link to `/` as broken when the home page
  lives in a `home/` directory. Both `accent serve` and `accent build` serve
  that page at the root, so the internal-link check now applies the same rule;
  a draft home page reports its status at info level instead.

## [0.23.1] - 2026-07-26

A bugfix release for the v0.23 static-build and deployment surface. The
unifying theme is serve/build parity: several links and assets that worked
under `accent serve` were missing from `accent build` output and 404ed only
on deployed sites, invisibly to `accent validate`.

### Added

- `accent build --strict-links`: a build-output link sweep resolves every
  emitted internal href against the output tree (at any `base_path`,
  including none). It warns by default and fails the build under the flag;
  the docs and website deploy workflows now build with it, so a broken-link
  regression fails the deploy instead of shipping 404s.

### Fixed

- Default theme under `site.base_path`: the top menu and the docs sidebar
  (both its versioned and non-versioned branches) rendered empty on every
  sub-path deployment, because the templates encoded root-relative URL
  shape in their depth heuristics and the `version.root` template context
  value never carried the base path. Nav depth is now measured against
  `url('/')` and `version.root` is prefixed like every other context URL;
  a regression fixture builds the embedded docs theme with and without a
  base path.
- Static-build link parity for three link classes that worked in `serve`
  and 404ed on deployed sites: versionless URLs now get a meta-refresh stub
  at every default-version page (previously only the versioning root);
  internal relative links are absolutized at render time against both
  authoring bases, so emitted hrefs no longer depend on the host's
  trailing-slash behavior; and `accent validate` now flags all unresolvable
  relative links, not just `.md`-suffixed ones (page-local file references
  stay exempt). One long-broken source-tree-path link in the docs was
  corrected across buckets, with frozen-bucket errata.
- Page-local media in static builds: `accent build` now emits page-local
  media files at their bare page URLs, mirroring the serve-time alias
  exactly -- rendered pages win collisions, per-page `media.expose: false`
  is honoured, sectioning directories and root-level orphan files are
  covered, and `media.serve_at_page_url: false` disables both surfaces
  consistently. The static-asset resolver now also rejects dot-prefixed
  path components on both surfaces, and serve and build share a single
  extension allowlist.
- Copy-code button: copying a code block no longer prepends the button's
  own label (`Copy`/`Copied!`) to the copied text.
- install.sh now warns when a stale `accent` earlier in `PATH` shadows the
  freshly installed binary, naming both paths and the remediation.
- Release/deploy pipeline, no released-binary impact: the site deploy
  workflows no longer race the release binary after a tag, and the release
  publish job survives partial re-runs of the build matrix.

## [0.23.0] - 2026-07-25

Sub-path deployment support lands: a static build (or a proxied `accent
serve`) now works correctly when the site lives under a path prefix
such as a GitHub Pages project site or a reverse-proxy mount point.
Alongside it, the two-release-old docs promotion checklist becomes a
tool with a fail-closed release gate behind it, and the workspace picks
up a Rust toolchain bump plus the CI/dependency fixes that came with
validating it.

### Added

- **Base path support for sub-path deployments (f255)**: `site.base_path`
  config field plus `--base-path` on `accent build` and
  `accent serve-static`. Every internal URL (page links, theme assets,
  media, search fetch paths and result URLs, `llms.txt` links, `.md`
  redirect stubs, pagination, tag links) is emitted under the prefix, so a
  static build works when served from a sub-path such as a GitHub Pages
  project site. The prefix auto-derives from the path component of
  `site.url`/`--base-url`, making the documented
  `accent build --base-url https://user.github.io/repo` recipe work as
  written; an explicit `base_path` wins, and if it diverges from the
  URL's own path a startup/build warning names both values and the
  affected absolute-URL surfaces (sitemap, feeds, canonicals, JSON-LD).
  Absolute artifacts compose the prefix exactly once. New `url(path)`
  template function/filter for themes; in-tree themes no longer hardcode
  root-absolute paths, and `accent build` warns about hardcoded
  root-absolute URLs in theme templates and fails the build if any
  emitted file still contains an unprefixed internal URL. `accent serve`
  and `accent serve-static` serve the site under the prefix -- reserved
  infrastructure routes, now including `/_health` and `/.well-known`,
  stay at the server root -- so local serving reproduces the deployed URL
  space. Post-review hardening: DocFind's native search index (the JSON
  API/MCP consumers) is built from its own root-relative document set
  instead of reusing prefixed browser-index bytes, so startup search
  under a base path returns results again; the version-scoped-search
  (f225) "/" catch-all is preserved instead of being joined into the
  prefix; and `font_css_url()` now joins the prefix like `cdn_url()`,
  with proxied font CSS emitting relative `../files/` references so
  cached stylesheets stay correct under any mount prefix.
- **Docs promotion tool and fail-closed release gate (f254)**: `cargo run
  -p docs-promote -- promote --release X.Y` executes the versioned-docs
  release promotion (freeze the `vX.Y-dev` bucket to `vX.Y`, relabel both
  bucket roots, seed `vX.(Y+1)-dev`, regenerate the frozen-content
  manifest) as a single idempotent, non-committing tool instead of a
  manual checklist -- closing both the omission failure class (b101:
  v0.22.0 shipped without the docs ever being promoted) and the
  incompleteness failure class (b108: the stale "0.22-dev" breadcrumb).
  `scripts/check-docs-promotion.sh` backs it with an independent gate
  wired into both `scripts/release.sh` and `release.yml`: a stable-tag
  release now fails closed if the docs corpus was never promoted,
  matching the existing `LICENSE_PUBLIC_KEY_PEM` fail-closed precedent
  (pre-release tags are exempt). Repo-internal tooling with no render
  surface or product-facing behavior. This release's own docs were
  promoted with it: `v0.23` is now the frozen release bucket and
  `v0.24-dev` the writable one.

### Fixed

- **Frontmatter redirects no longer poison browser redirect caches
  (b107)**: a simple `redirect: /target` (and the detailed form without
  an explicit `code:`) now emits `302 Found` with `Cache-Control:
  no-cache` instead of a permanent `301`. An author-editable "moving
  pointer" redirect cached as permanent by the browser was surviving
  server restarts and content changes, producing convincing
  "the docs are broken" reports on shared dev ports. `code: 301` remains
  the explicit opt-in for deliberate permanent migrations;
  canonicalization redirects (trailing slash, `.md` cleanup,
  permalink-pattern maps) are unaffected and stay 301.
- **Version-bucket breadcrumb showed the wrong version after promotion
  (b108)**: a released version bucket's `menu.title` frontmatter kept
  reading "X.Y-dev" after promotion, so the breadcrumb and prev/next
  navigation disagreed with the version switcher. Fixed for the shipped
  v0.22 docs and closed permanently going forward by the docs-promote
  tool's relabel step (f254).
- **Mermaid diagram layout**: the vendored `accent-mmdr` renderer
  advanced through three patch releases (0.3.0 -> 0.3.2), fixing edges
  that crossed through subgraph titles, edges into adjacent terminal
  markers (flowchart `((Done))` circles, state `[*]` end rings) that
  routed as clipped hooks or squeezed diagonal staircases, and terminal
  markers that overlapped their source node.
- **Fresh dependency resolution could fail the build**: `lightningcss`
  bumped to `1.0.0-alpha.72` -- the previous pin's loose
  `parcel_selectors` requirement let any build that re-resolves
  dependencies instead of honoring `Cargo.lock` (`cargo install` without
  `--locked`, a build after `cargo update`) pick an incompatible
  `parcel_selectors`/`cssparser` pair and fail to compile inside
  `lightningcss`. Locked and fresh resolutions now agree.
- **Toolchain and CI hardening, no released-binary impact**: the
  workspace toolchain moved to Rust 1.97.1 (`rust-toolchain.toml`), which
  also made an unattributed `clippy --lib --tests` false positive on the
  lib test target stop reproducing (b110); every test-side `git` fixture
  helper now disables commit signing, so the integration-test suite no
  longer fails on a developer machine with a locked signing agent (b111);
  and the Windows CI runner's persistent target directory now self-cleans
  below 40 GB free, fixing a disk-exhaustion failure that the
  toolchain/dependency bump triggered (b112).

## [0.22.1] - 2026-07-14

A bugfix release. It completes the trial-license code removal that 0.22.0
announced at the policy level, corrects how an expired legacy trial key is
reported at startup, and folds in two developer-profile fixes that no
released binary was ever affected by.

### Removed

- **`accent license trial` subcommand (f249)**: the code removal that the
  0.22.0 "Trial licenses" note forward-referenced. The subcommand, its
  dispatch wiring, and the `TRIAL_DAYS` constant are gone, and no upsell,
  startup banner, or `accent license status` line references trials anymore.
  Evaluation remains the free build/dev-serve tier (Policy A2) or a
  low-commitment monthly license. Previously issued `kind: "trial"` keys
  still validate and expire under the time-constrained (monthly/rental)
  rules -- there is no retroactive invalidation -- so a legacy trial key now
  renders as `Monthly (rental)`.

### Fixed

- **Expired legacy trial key mislabelled at `serve --production` startup
  (f249)**: the expired-license nudge now branches on the owned-vs-rental
  lifecycle rather than the raw `cadence` claim, so a legacy trial key
  (which carries no cadence) is correctly treated as time-constrained -- it
  is reported as running as Core instead of falsely claiming perpetual
  ownership, and the spurious "Trial license active" banner is gone.
- **Developer-profile only, no released-binary impact**: the plugin-runtime
  fuel-cap test no longer flakes under host CPU load (b096), and ad-hoc
  single-file serving under the `edition-core` compile profile (media
  compiled out -- never a released build) no longer 404s sibling static
  assets (b100). Every released binary compiles `media` in and already
  served these correctly.

## [0.22.0] - 2026-07-12

The launch release: Accent CMS becomes publicly downloadable. One
license-unlocked binary per platform, published with mandatory signing to
[github.com/AccentCMS/accent](https://github.com/AccentCMS/accent), plus
the first release of the built-in content agent.

### Added

- **Public single-binary distribution (f247)**: releases are now published
  to the public download repository `AccentCMS/accent` -- six platform
  archives (`accent-v<version>-<target>`), a SHA-256 checksums file, and a
  mandatory GPG signature (`checksums-v<version>.txt.asc`; the release
  signing key is published as `release-signing-key.asc`). Install scripts
  (`install.sh` / `install.ps1`) download, checksum-verify, and (with gpg
  present) signature-verify automatically; every release additionally
  receives a publication attestation in the Sigstore transparency log.
  There are no per-edition artifacts: every download contains the full
  feature set and the license key sets the runtime tier.
- **Content agent (f242, free in every edition)**: `accent agent` runs a
  budgeted, human-in-the-loop LLM session over the site's content with
  explicit provider/endpoint/model arguments and stdin approval for
  writes.
- **Agent admin chat (f244, f246)**: the admin UI gains a chat panel
  driving the same agent over `/_admin/agent/*` SSE with approval and
  steering; flipping `agent.enabled` changes nothing but the agent routes
  and panel markup.
- **Agent audit stamping (f245)**: agent sessions stamp an audit hash that
  cross-references the session log with git history.
- **Public plugin registry**: `github.com/AccentCMS/plugin-registry` is
  live (empty for now); default-config `accent plugin install` resolves it
  and reports missing plugins cleanly (b099).
- **Relative markdown links now just work (b092)**: intra-site links written
  the portable, GitHub-compatible way -- `[E001](e001-example.md)`,
  `[up](../guide/setup.md)` -- are rewritten at render time to the target
  page's clean URL, resolved against the linking page's *source file* exactly
  as GitHub and IDE previews resolve them. Applies to `accent serve` and
  `accent build` alike; unresolvable destinations are left untouched, and
  `accent validate` now flags them (new `BrokenRelativeLink` warning) instead
  of letting them ship as silent 404s. Absolute `.md` links to existing pages
  are rewritten too (skipping the redirect hop) and are no longer
  false-positived by `accent validate`.

### Changed

- **Version output drops the compile-time edition tag (f247)**: `accent
  --version` now prints `<version> (<hash>) [license: <tier>]` and the page
  footer's `accent.version_string` prints `<version> (<hash>)`. Under
  single-binary distribution every release binary compiles the same feature
  superset, so the old `[edition: ...]` tag would have read `pro` on every
  installation regardless of license. The admin Settings "Edition" row now
  shows the runtime license tier (Core (free) / Core+ / Standard / Pro).
- **Feature-invariant config schema (f234)**: the `config.yaml` schema is now
  identical in every build of Accent CMS. Config sections for subsystems that
  are not compiled into a binary (for example `cdn:` or `mcp:` on a Standard
  binary) are now parsed, type-checked, and retained instead of being silently
  ignored, and a startup warning names each such section so the omission is
  visible. As a consequence, a *malformed* section for a compiled-out
  subsystem now fails config load with a parse error (previously it was
  skipped as an unknown key). Well-formed configs are unaffected.
- **Canonical URLs without trailing slashes (b092)**: `/section/` now 301s to
  `/section` in `accent serve` and `accent serve-static` (the redirect fires
  only for URLs that actually serve; unknown paths stay single-request 404s),
  and `sitemap.xml` emits the same canonical no-slash form as every other URL
  surface instead of appending a trailing slash.
- **Shared content kernel (f231)**: the content-critical state (index,
  cache, config) moved into a `ContentKernel` shared by the server and the
  MCP command, unifying the two content indexes.

### Removed

- **Trial licenses**: the 10-day per-edition trial is withdrawn. Evaluation
  is the free build/dev tier (no key, no time limit) plus a low-commitment
  monthly license for production. Documentation no longer offers trials;
  removal of the `accent license trial` command is tracked as f249.

### Fixed

- **Static builds of versioning roots (b098)**: `accent build` rendered a
  versioning root's shell page (for example `/docs`) as a dead-end page,
  while `accent serve` 302s it to the default version; the build now emits
  the equivalent redirect stub.
- **`accent validate` file-serving-route false positives (b094)**: absolute
  links under `/media/`, `/content-media/`, `/theme/assets/`,
  `/.well-known/`, and `/assets/plugins/` are no longer reported as broken
  pages.
- **Agent hangs (b090, b091)**: `accent agent` no longer hangs on exit when
  stdin never EOFs, and an approval pause can no longer outlive the session
  budget when the requesting client disconnects.
- **Serve-spawn test flakes on macOS (b095)** and the 500-line rule breach
  that turned CI red for unrelated PRs (b097).

### Security

- **CDN license gate now covers config reload and live requests (f247)**:
  the Pro-only CDN integration was license-checked only at serve startup, so
  a SIGHUP or `POST /_admin/reload` with `cdn.enabled: true` could activate
  asset rewriting, outbound cache purges, and the proxied-font routes
  without a Pro key. Reloads now re-gate `cdn.enabled` (mirroring the admin
  UI re-gate), and the `/_fonts/*` and purge-webhook handlers re-check it
  per request. Groundwork for single-binary distribution, where MCP and CDN
  are compiled into every release binary and the license key alone unlocks
  them.
- **Release supply chain**: GPG signing of the release checksums is now
  mandatory (publishing fails without a verified signature), third-party
  deploy tooling was removed from the release path, and every published
  release is attested at publication time.
- Bumped `crossbeam-epoch` 0.9.18 -> 0.9.20 (RUSTSEC-2026-0204: invalid
  pointer dereference in the `fmt::Pointer` impl for `Atomic`/`Shared`).
  Transitive dependency; lockfile-only patch bump.

## [0.21.0] - 2026-07-04

Checkpoint release before the agent-harness integration cycle (E036/E037):
version-scoped client-side search, plugin content-source hot reload, the
release-download verification guide, and a large Simple Search performance
fix.: de-cfg the Config schema (features gate behavior, not shape))

### Added

- **Version-scoped client-side search (f225)**: on a site with versioned
  documentation, search results are now automatically scoped to the version the
  reader is viewing -- a reader on `/docs/v2.0/...` no longer sees v1.x or
  in-development hits mixed in. The search index publishes its versioning roots
  and both the Simple Search client and the search island derive the current and
  each result's version from the URL, keeping only matching results (falling back
  to each root's default version when the reader is not inside a version).
  Non-versioned pages always appear, and non-versioned sites are unaffected.

- **Release-download verification guide (f199)**: a new deployment docs page,
  "Verifying a Release Download", documents how to confirm a downloaded binary
  is authentic before running it -- SHA-256 checksum verification, the optional
  GPG-signed checksums file, auditing the binary's embedded `cargo-auditable`
  SBOM with `cargo audit bin` / `rust-audit-info`, and the macOS Gatekeeper
  note. Completes the user-facing documentation for the supply-chain signing
  layer shipped in 0.20.0.

- **Plugin content-source hot reload (f025i)**: plugin content mounts
  (`source: plugin:<name>`) can now refresh in dev mode without a restart. When
  the plugin declares a positive `refresh_interval_seconds` in its
  `plugin.toml` `[config]`, `accent serve` (non-`--production`, hot reload on)
  re-invokes the plugin's `on_content_load` hook on that cadence; a changed page
  set (added, removed, or edited page) refreshes the content index, rebuilds
  taxonomy, and triggers a browser reload when `browser_reload` is enabled. An
  unchanged source triggers nothing. Production never polls -- `SIGHUP` or
  `POST /_admin/reload` re-runs all hooks there.

### Fixed

- **Simple Search no longer freezes the browser on large indexes (b081)**: the
  client used to re-tokenize the entire content corpus on every keystroke,
  which on a large index (e.g. the specs site's `content_length: 50000`,
  ~8.3 MB) blocked the main thread ~125 ms per query. The search index now
  ships per-page **deduplicated content tokens** instead of raw text, and the
  client tokenizes only the short title/lead/tags fields once at load -- making
  a query `O(query x tokens)` rather than `O(corpus)`. Per-query cost drops to
  single-digit milliseconds and the index payload shrinks ~59% (8.3 MB ->
  3.4 MB) while `content_length` stays high, so deep-content matching is
  preserved. Results are unchanged.

## [0.20.0] - 2026-06-23

Major release: complete plugin runtime rewrite to the WASM Component Model,
two-binary edition collapse, ad-hoc markdown serving, CDN integration,
CodeMirror 6 admin editor, two-cadence license lifecycle, in-browser DocFind
search, HTTP response compression, and release supply-chain signing.

### Added

- **WASM Component Model plugin runtime -- E034 complete (f200-f210)**:
  The plugin system is rebuilt from the ground up on Wasmtime 48 (LTS) +
  WASI 0.2. The ten-phase epic delivers: a Phase-0 proof-of-concept (f200,
  verdict PROCEED); a runtime-independent WIT contract with ABI version range
  negotiation (f201); the Wasmtime host foundation with universal CPU/memory
  metering (f202); a typed component binding layer and registry (f203); WASI
  capability providers -- scoped filesystem and outbound HTTP with SSRF
  redirect guard (f204); content and template hook dispatch (f205);
  media, document-model, and content-source hook dispatch (f206); routes and
  islands typed dispatch (f207); diagram-plugin parity via `render_diagram`
  (f208); guest authoring toolchains (`cargo-component` + `jco`, f209); and
  the full Extism-to-Component-Model cutover with first-party plugins rebuilt
  as Rust+JS components (f210). All hook surfaces from the Extism era are
  preserved at the typed WIT boundary. CI builds plugins with
  `cargo-component`; the WASM artifact cross-device copy issue (EXDEV) is
  fixed via `CARGO_TARGET_DIR`. Production license public key is injected at
  compile time so release binaries verify licenses offline without carrying
  the dev key.

- **Two-binary edition model -- E035 complete (f212-f217)**: Accent CMS now
  ships two binaries -- **Standard** and **Pro** -- replacing the prior three.
  "Core" is the Standard binary with no license key (free tier). The A2
  "free to build, pay to serve" gate is audited and enforced: the full feature
  set (plugins, media, client-side search, styling, all diagram languages) is
  free in `accent build` and non-production `accent serve`; production serving
  requires Standard+ (f213). The diagram-plugins feature is moved into Standard
  (f212). The Core+ admin-UI gate requires a Core+/Standard/Pro license in dev
  and production alike (f217). The edition-core CI hygiene pass now runs
  `--no-default-features --features edition-core` clippy check-only (f215).
  The release pipeline collapses to **12 binaries (2 editions × 6 targets)**
  with `accent --version` reporting the active license state; a one-cycle
  `accent-core-*` deprecation alias of each Standard archive is uploaded so
  legacy download URLs keep resolving and remain verifiable (f214).

- **Ad-hoc local markdown serving (f197a)**: `accent serve <file.md>` renders
  a single markdown file at `/`, and `accent serve <dir>` serves a bare
  directory of markdown files -- both with a new binary-embedded viewer theme,
  so no `config.yaml`, theme, or content directory needs to exist on disk and
  nothing is extracted to the filesystem. Page titles follow the usual
  `frontmatter -> first H1 -> filename` chain; images and other files next to
  a served file resolve through the existing page-local media alias (with the
  same traversal, dotfile, and MIME-allowlist protections); edits trigger the
  standard SSE browser reload. `--theme`/`--theme-dir` swap the viewer theme
  for an on-disk one. `--production` stays gated to Standard+, as for any
  site. `http(s)://` targets are recognised and return a clear "remote support
  not yet available" message.

- **Remote markdown URL serving (f197b)**: `accent serve <https://...>`
  fetches and renders a remote markdown URL at `/`. `--refresh <seconds>`
  polls the URL and triggers SSE browser reload on changes. Remote sources
  are fetched over HTTPS; redirects are followed up to a safety limit.

- **Remote and single-file content mounts (f197c)**: A content mount may now
  point at a single remote file or a bare local file outside the content tree.
  The mount resolves into the page hierarchy at the configured path, with the
  same frontmatter, title, and media-alias rules as local pages.

- **In-browser DocFind search (f102)**: DocFind full-text search now works in
  the browser. The WASM artifact is patched at build time so it runs in the
  browser JS engine without a server round-trip. A fail-safe fallback to
  Simple Search activates when the DocFind artifacts are stubs or unavailable
  (b082 fix). The `site-docs` site pins the search backend to Simple Search
  for stability while the full DocFind rollout completes.

- **Two-cadence license lifecycle (f226)**: Paid license keys now carry a
  `cadence` claim selecting yearly (ownership) or monthly (rental). Yearly
  keys unlock their edition forever for releases at or below their
  `MAJOR.MINOR` ceiling; past expiry they are nudge-only (startup WARN,
  `X-Accent-CMS-License` header, `accent license status`) and never block.
  Monthly and trial keys fall back to free Core past expiry (`--production`
  refused, admin UI not mounted). The version ceiling is compared at
  `MAJOR.MINOR` so patch releases within a licensed minor are always free
  while the key is in force. Trial keys are 10 days; monthly keys are
  33 days from issuance.

- **CodeMirror 6 markdown editor island (f219)**: The admin page editor
  replaces the plain `<textarea>` with a CodeMirror 6 island -- syntax
  highlighting, line numbers, bracket matching, and a configurable keymap --
  while preserving the HTMX save round-trip. The editor island is loaded
  lazily so the admin shell load time is unchanged.

- **Admin body editor toolbar and textarea ergonomics (f218)**: A toolbar
  strip above the body editor provides bold, italic, link, and heading
  shortcuts; Escape releases the Tab trap so keyboard users can navigate past
  the editor; a frozen-document placement hint guides errata workflows.

- **HTTP response compression (f220)**: Axum `CompressionLayer` compresses
  responses with Brotli, Gzip, and Deflate based on `Accept-Encoding`.
  Compression is build-time gated (not a live SIGHUP predicate) so the
  feature flag controls binary size.

- **Release signing and supply-chain trust (f199)**: Release binaries are
  signed: a free SHA-256 `checksums-vX.Y.Z.txt` is attached to every GitHub
  release; Apple-notarised macOS builds are gated behind the Apple Developer
  account. Downstream verification instructions are included in the release
  notes.

- **CDN integration (f082)**: Pro-tier CDN integration is shipped. An operator
  configures a CDN origin-pull endpoint; Accent sets `Cache-Control` and
  `Surrogate-Key` (Fastly/Varnish) / `CDN-Cache-Control` headers per route,
  and exposes a `/_cdn/purge` webhook for cache invalidation on content
  changes.

- **Config toggle for `.md` extension redirects (f198)**: A new
  `server.md_redirect: false` option disables the automatic 301 redirect from
  `/page.md` to `/page`, useful when serving raw-markdown feeds alongside
  rendered pages or when proxying a repo mirror.

### Changed

- **OWASP / Axum + Wasmtime security hardening**: OWASP Top-10 review of
  the Axum request-handling surface and the Wasmtime sandbox boundary. Input
  sanitisation tightened on upload paths; plugin outbound-HTTP redirects are
  blocked by default (SSRF guard, part of f204).

### Fixed

- **Security audit: quinn-proto 0.11.15 + memmap2 0.9.11 (b083)**:
  RUSTSEC-2026-0185 (quinn-proto) and RUSTSEC-2026-0186 (memmap2) addressed
  by bumping both crates to patched versions.

- **DocFind fail-safe fallback to Simple Search (b082)**: When the DocFind
  WASM artifacts are stubs (committed placeholders, not real search indexes),
  the search UI now falls back to Simple Search instead of displaying an error
  or silently returning no results.

- **Benchmark thin-LTO profile (b080)**: The Criterion benchmark suites failed
  to link on the self-hosted CI runner under fat-LTO. A `bench` profile with
  `lto = "thin"` resolves the issue and keeps benchmarks fast without the
  full fat-LTO binary-size optimisation.

- **Styling available in all editions (b079)**: Compiled CSS was gated behind
  the `styling` feature flag so the `edition-core` build shipped without any
  stylesheet. Core now bundles the compiled CSS; the feature flag gates only
  the Sass pipeline, not the compiled output.

- **Collection date sort now chronological (b078)**: Collections sorted by
  `date` were ordering pages lexicographically (treating dates as strings)
  instead of chronologically. The sort now parses dates via `chrono` and
  applies a stable alphabetical tiebreak; both padded and non-padded ISO 8601
  dates sort correctly.

- **Relative `--output` no longer panics in CSS minify pass (b077)**:
  `accent build --output ./public` triggered a `strip_prefix` panic in the
  styling pass when the output path was relative. The pass now resolves the
  output path to an absolute path before computing relative offsets.

- **Clone-root-owned checkout ownership misdiagnosis (b076)**: `git clone
  --force` against a root-owned working directory was diagnosed as a missing
  `origin` remote instead of an ownership mismatch, producing a confusing
  error. Git's safe-directory error is now distinguished from the
  missing-origin case and surfaces the real remediation step.

- **SMTP send failure logging (b075)**: SMTP delivery errors were swallowed
  after the send attempt; the log showed only rate-limit events. Delivery
  failures now log at `ERROR` level, split from rate-limit `WARN` events so
  operators can alert on hard send failures separately.

- **Collection date sort documented (b078)**: The documentation now explains
  that `sort_by: date` orders pages chronologically (newest first), and that
  an explicit `sort_order: asc` reverses the direction.

- **Drop unmaintained `yaml-rust` via syntect (b006)**: The `syntect` crate's
  `yaml-load` feature pulled in the unmaintained `yaml-rust` crate. Switching
  to `syntect` without `yaml-load` removes the advisory and shaves a transitive
  dependency.

### Removed

- **Extism plugin runtime**: Removed. All plugin host logic is now handled by
  the Wasmtime Component Model runtime (E034/f210). The `extism` crate and its
  transitive dependencies are no longer in the build graph.

- **Retired the Core binary-size budget CI workflow** (`.github/workflows/binary-size.yml`).
  It was a high-friction post-merge alert (authoritative size measurable only on
  the self-hosted Linux runner; full uncached LTO build per size-relevant push;
  reactive budget bumps) and `edition-core` is no longer a shipped profile.
  The mmdr Profile-B trim and `scripts/measure-binary-size.sh` (ad-hoc local
  measurement) remain.

## [0.19.1] - 2026-06-12

Patch release: two production-blocking git-deploy / configuration bugs
found on the first accentx.ch deployment of v0.19.0, plus a
config-loading hole found in the post-merge review of those fixes.

### Fixed

- **git-deploy fetch/push authentication on private remotes (b073)**: on
  `https://` remotes with `GIT_REMOTE_TOKEN` set, every authenticated
  `git fetch` and `git push` failed with `error: unknown switch 'c'`
  because the one-shot `-c credential.helper=...` was appended after the
  subcommand -- `-c` is a global git option and is only honoured before
  it. Webhook push-to-live, the 5-minute deploy poll, preview-branch
  fetch, and outbound push were all dead on private repos, freezing
  content at the boot-time clone (only `clone.rs` had the order right).
  All four git call sites now share a single credential-injection helper
  applied before the subcommand, with per-site argv regression tests on
  the authenticated path. Interactive credential prompts are now
  suppressed on Windows too, so a bad token fails loud instead of
  hanging a headless server.
- **Environment-driven numeric and bool config fields (b072)**: `${VAR}`
  expansion always produced a string, so typed fields
  (`smtp.port: u16`) rejected env-substituted values and no numeric or
  boolean field could be driven by an environment variable or deploy
  secret. A config value that is exactly one `${VAR}` placeholder now
  takes the type the environment supplies (`port: "${SMTP_PORT}"` with
  `SMTP_PORT=587` loads as the number 587, as if written literally),
  via a fallback parse that keeps every currently-loading config
  loading identically -- mixed values and non-numeric expansions stay
  strings, and an unset `${VAR}` stays a literal placeholder for the
  fail-loud secret guards.
- **Config parse failures no longer fall back to built-in defaults
  (b072)**: `accent serve` mislabeled an existing-but-unparseable config
  file as `No config file found` and silently served built-in defaults;
  under `--production` a one-line config typo became a crash loop (or,
  with servable defaults, the wrong site). `serve` and `serve-static`
  now abort with the real parse error -- the same diagnostic
  `accent validate` prints -- and fall back to defaults only when the
  file is genuinely absent.
- **Config existence check fails loud on stat errors (b074)**: the
  absent-vs-broken distinction above was gated on `Path::exists()`,
  which collapses permission denied and every other stat failure into
  "absent" -- an existing config behind an unsearchable parent
  directory (root-written config, non-root service user) still
  silently served built-in defaults behind the misleading
  `No config file found` warning. `serve` and `serve-static` now probe
  with `Path::try_exists()` and abort with the OS error
  (`cannot access configuration file '<path>': Permission denied`)
  when the check itself fails; a confirmed-absent file keeps the
  defaults fallback.

## [0.19.0] - 2026-06-08

### Added

- **Social sharing metadata (f195)**: every page now unfurls as a rich
  social card with zero per-page authoring. The default and starter
  themes ship a `partials/head_meta.html.jinja` partial that emits Open
  Graph, Twitter Card, `article:*`, `og:locale`, robots `noindex`, and
  `hreflang` tags, plus a **build-safe** `<link rel="canonical">` and a
  **page-specific** `<meta name="description">` (replacing the previous
  site-wide description). A new `absolute_url()` template helper (function
  and filter forms) makes URLs absolute against `site.url` independent of
  the request, so canonical / `og:url` are identical in `serve` and static
  `build`. The card's description and image resolve through the same
  shared resolvers as JSON-LD (no divergence). A new open `site.meta` map
  plus per-page `meta:` frontmatter (page wins) carry any platform tag --
  `twitter:site`, `fediverse:creator`, `fb:app_id`, or a network that
  appears next year -- with `name=`/`property=` inferred by key prefix and
  no platform hard-coded in Rust.
- **Git managed-checkout bootstrap / clone-on-boot (f140l)**: a
  git-deploy publisher is now a self-bootstrapping, read-only mirror of
  the remote. On boot, when `git.enabled` and `git.bootstrap.enabled`,
  a publisher or author server clones the deploy branch into the content
  directory if it is absent; an existing checkout is left in place and
  fast-forwarded by the running fetch loop (webhook/polling) after
  startup -- no entrypoint scripting, no baked content. `accent build`
  bootstraps the same way before generating static output. A new
  `accent git clone [--force] [--branch <name>]` verb performs the same
  bootstrap deterministically (independent of `git.enabled`) and is the
  real "nuclear option" re-clone recovery path. Reuses the existing
  system-git + `GIT_REMOTE_TOKEN` credential injection (token never in
  argv). **Safety floor:** in production (`serve --production`),
  `git.enabled: true` with a content directory that is not a git
  checkout is a hard startup error (naming the `accent git clone`
  remedy) instead of silently serving baked files forever; dev mode
  warns and falls back so the local git-aware workflow keeps working.
  Set `git.allow_fs_fallback: true` to restore the legacy fallback in
  production too. See the [Git deployment guide](/docs/git-deployment)
  for the two-speed deploy model. Standard edition or higher.
- **Social meta validation via a document model (f196)**: layers
  optional model-driven validation onto the open `meta` carrier from
  f195. Bind a document model and a `description` max-length plus
  `og:type` / `twitter:card` enums are checked at content-load time;
  with no model bound, the raw map and the rendered card are
  unchanged. Constraint checking now recurses into `Object` sub-fields
  so a nested cap (e.g. `meta.og:description` max-length) is enforced,
  and colon-containing keys (`og:type`, `twitter:card`) parse verbatim
  with no escaping convention. Ships `themes/default/models/base.yaml`
  (a `description` + `meta` object schema) and `docs.yaml`
  (`extends: base`), auto-bound to docs-template pages; the models are
  non-strict with no required fields, so existing pages validate
  cleanly. The `extends` reuse pattern is documented in the
  document-models and social-sharing guides.
- **Frozen content write guard (f193)**: enforces the versioned-docs
  freeze at write time, fail-closed, across the admin and CLI surfaces
  from one config field. Each version carries a `state` (dev / released
  / archived) with effective-state inference (the last-declared bucket
  defaults to dev, the rest released); startup rejects more than one
  dev version per root. The admin Save guard rejects plain writes to
  frozen pages with a server-side 403 and a frozen banner; a role-gated
  "Edit as errata" overrule writes the page, records provenance in the
  audit log, and re-baselines the frozen manifest, while archived
  versions reject even errata. A new `accent validate` frozen-content
  rule hashes every frozen page and diffs against a per-root
  `.frozen-manifest.toml`; it is opt-in and inert until
  `accent validate --write-manifest` records a baseline, so existing
  versioned sites keep passing. Version state is surfaced in the public
  `VersionContext` and the docs theme version dropdown. Standard
  edition or higher (admin guard); `accent validate` rule available in
  Core.
- **Hotfix overlay for baked-in frontend dependencies (f190, f192,
  m041)**: lets an operator override the third-party vendored assets
  baked into the binary (Alpine.js, HTMX) with a patched copy on disk,
  so an upstream security advisory can be applied without a rebuild or
  a new release. A top-level `hotfix` config block (`overlay_dir`,
  `on_unknown`) points at an on-disk overlay directory resolved
  relative to the config; an allowlist restricts overrides to genuinely
  third-party assets (never Accent-owned code) and doubles as the
  path-traversal guard. Overlay responses carry a content ETag plus
  `Cache-Control: no-cache` (with `If-None-Match` -> 304) so a swapped
  file busts the embedded path's day-long cache. **Phase 2** adds a
  `hotfix.yaml` provenance manifest with boot/SIGHUP SHA-256
  verification (a hash-mismatched file is blocked, falls through to the
  embedded copy, and is logged), the `accent hotfix apply <asset>
  <file>` / `accent hotfix remove <asset>` / `accent hotfix list` /
  `accent hotfix verify` commands (verify exits non-zero on a
  reject-class problem), and an admin top-bar "hotfix active" chip.
  Standard edition or higher (`admin` feature).
- **MCP advanced tools and prompts -- E005 Phase 4 complete (f080d)**:
  the Model Context Protocol server gains four advanced tools
  (`validate_content`, `render_preview`, `audit_content`,
  `find_references`) and three prompt templates (`content_review`,
  `content_migration_plan`, `taxonomy_cleanup`), surfaced through the
  existing `#[tool_router]` block plus `list_prompts` / `get_prompt`
  overrides. AI clients can now validate, preview, audit, and
  cross-reference content directly over MCP. Pro edition (`mcp`
  feature).
- **MCP `render_preview` full template rendering (f179)**: when the MCP
  server is started via `accent mcp`, `render_preview` now runs both
  halves of the pipeline -- markdown body to HTML, then the active
  theme's Jinja layout -- so AI assistants get HTML that matches the
  live server's response (modulo dev-only injections) instead of a
  body-only fragment. New `template` (override the resolved template)
  and `frontmatter` (JSON object applied to draft previews) parameters;
  the response gains a `scope` field (`"full-page"` vs `"body-only"`).
  Template values containing `/`, `\`, `..`, NUL, or empty strings are
  rejected before reaching the loader, and the body runs through the
  same event-processor pipeline (smart quotes, wikilinks, TOC, syntax
  highlighting, math, admonitions) as the live server. Falls back to
  body-only output with a warning when the theme directory is missing.
  Pro edition (`mcp` feature).
- **`cli-tree` developer tool for CLI option-tree introspection**: a new
  workspace member (`tools/cli-tree/`) that extracts the `accent` command
  and option tree directly from the live `clap` definition and prints it
  as an indented, human-readable tree or as stable JSON. Edition
  passthrough features (`--features edition-core|edition-standard|edition-pro`)
  select which `#[cfg(feature)]`-gated subcommands are visible, so the
  output matches exactly what each edition ships. It backs a generated
  CLI-to-feature-mapping reference and a cfg-aware integration smoke test
  that asserts per-edition command gating and flag value-classification.
  Developer tooling only -- not part of the shipped binary.

- **Accent Author admin shell 1.0 (E033)**: the admin UI is now a
  full editorial surface, not a read-only preview. Authors can browse
  pages, edit them field-by-field, watch a live preview update as they
  type, save with concurrent-edit conflict detection, run the workflow
  transition from draft to published, upload media, and create, move,
  or delete pages. Enabled by the `admin` cargo feature (Standard /
  Pro) plus the `admin.enabled` config flag. See the
  [Admin UI reference](/docs/admin) for the full screen-by-screen
  guide. Deliberately out of scope for 1.0 (per the product spec):
  drag-and-drop page reordering, content-model editing, multi-user
  accounts / roles / OIDC, per-page ACLs, plugin-defined admin
  extensions, and revision history beyond Git. Those remain tracked
  for later editions.

- **Accent Author admin shell (read-only preview, f171)**: load-bearing
  scaffolding for the HTMX-native admin UI from epic E033. Mounts seven
  read-only screens under `/_admin/` on the same axum instance as the
  public site -- login, dashboard, pages list, pages tree, schema
  browser, validation report, settings. Reads exclusively through the
  public `api::query::*` and `api::validate::*` surface; a CI lint
  (`cargo run -q -p admin-seam-check`) enforces the replaceability seam
  so f176 can swap the shell without touching the rest of the codebase.
  Gated by the new `admin` cargo feature (included in Standard / Pro)
  and the `admin.enabled` config flag (default `false` through
  f171-f174; flipped to `true` by f175). Mutation screens land in
  f172-f174.

- **`recent_documents()` template widget and last-updated listing field
  (f186)**: a native `recent_documents(limit, model?)` template function
  returns the most-recently-updated pages across the site, sorted by
  frontmatter date with a file-mtime fallback. `modified_date` is
  exposed on `PageMetaContext` so the `pages` / `all_pages` listings
  carry both the frontmatter date and the file mtime. Ships a
  `partials/recent-documents.html.jinja` widget in the default docs
  theme, wired into the docs page TOC column. A stateless read over the
  in-memory index; works identically in `serve` and `build`. Core
  edition.

- **`menu.title` navigation label override (f194)**: pages can now set
  an optional `menu.title` that navigation surfaces -- breadcrumbs,
  sidebar, prev/next, and the top menu -- prefer over the page's
  `title`, while the page heading and browser title keep the full
  `title`. Threaded through `PageMetaContext`, `PageContext`, the page
  `context!` macro, and the JSON-LD breadcrumb builder for both `serve`
  and `build`. The default theme demonstrates it across all four
  navigation surfaces; the devdocs and starter themes honour it.
  Documented in the content-organization guide. Available in all
  editions.

- **Numeric prefix stripping for flat files (f181)**: file stems are
  now run through `strip_numeric_prefix()` when computing URLs, so
  `01.getting-started.md` produces `/getting-started` instead of
  `/01.getting-started`, and `menu.order` is auto-populated from the
  prefix when frontmatter does not declare one. Digit and space guards
  prevent false positives on version numbers (`1.0-release` stays
  intact) and natural-language titles (`24. Dezember` stays intact);
  reverse URL resolution scans directory entries to map `/installation`
  back to `03.installation.md`. Available in all editions.

- **Companion directory modules and module files for flat files
  (f182)**: formalises the companion-directory pattern so flat-file
  pages can own modules and scoped media without Grav-style directory
  ceremony. When `about.md` and `about/` coexist, the directory is the
  flat file's companion -- `_`-prefixed subdirectories are modules and
  non-markdown files are page-scoped media (when no index file exists in
  the directory). `_`-prefixed markdown files (`_hero.md`) load as
  lightweight `PageModule`s carrying frontmatter and content; directory
  modules win over file modules when both share the same name. Available
  in all editions.

- **Content models mature: `_model.yaml` directory binding across a real
  corpus**: document models can now be bound to a whole directory tree
  via `_model.yaml`, validated, and rendered on typed pages. A directory
  binding now resolves correctly (relative page dirs resolve against the
  content root first), and `accent build` falls back to
  `default.html.jinja` for flat-file pages whose filename-derived
  template is missing, matching the `serve` path so a fully-modeled site
  builds. Structural landing/readme files (`index`, `README`, `default`,
  any case) are exempt from a model's filename pattern so binding a
  directory does not flag its README. The devdocs theme renders a
  modeled page's `page.custom` fields as a compact field rail -- status
  badges, meta pills, source-reference blocks, acceptance checklists, and
  ID chips resolved to their local pages -- collapsing to nothing on
  unmodeled pages. Available in all editions.

- **Default theme search keyboard navigation**: pressing `/` anywhere
  (when not already typing in a field) jumps focus into the header
  search box, with the caret placed at the end of any existing query;
  the shortcut is skipped when a modifier is held or focus is in an
  input, textarea, select, or contenteditable element. The search
  placeholder shows the `/` hint as a bordered key badge. Shipped as a
  default-theme asset (`js/search-keys.js`), loaded on every page.

- **ZenUML diagrams render in dev-mode preview (theme)**: ZenUML is an
  external Mermaid diagram type not in Mermaid core, so `zenuml` blocks
  previously showed "No diagram type detected" in the dev-mode client
  preview even though the server renderer already supported them -- a
  dev/prod parity gap. The dev-mode Mermaid loader now imports
  `@mermaid-js/mermaid-zenuml` and registers it via
  `mermaid.registerExternalDiagrams()` before rendering, in both the
  site-docs default and devdocs themes. The plugin facade is tiny and
  lazy-loads the heavy ZenUML core chunk only when a `zenuml` diagram is
  actually rendered, wrapped in try/catch so a plugin-load failure
  degrades gracefully instead of breaking other diagrams.

- **`vendor-assets` and `mcp-probe` developer tooling**: two new
  workspace members for maintaining and diagnosing the shipped binary.
  `tools/vendor-assets/` makes vendored frontend JS (Alpine.js, HTMX)
  maintenance mechanical -- `fetch` downloads each pinned asset from
  jsDelivr and verifies its embedded version marker before writing (a
  bad download never clobbers a good file), `verify` is an offline drift
  check suitable as a CI gate (exit 1 on drift), and `check` queries the
  npm registry to report pins that are behind (minor vs `[MAJOR]`); a
  single `ASSETS` manifest is the source of truth. `tools/mcp-probe/` is
  an MCP tools-surface diagnostic for inspecting what the MCP server
  exposes. Developer tooling only -- not part of the shipped binary.

### Fixed

- **Editor Diff tab reported the whole body as added on an unedited
  page (b044)**: the "Pending changes" pane embeds the on-disk body as
  JSON in a `data-baseline` attribute, but the attribute was
  double-quoted. `tojson` leaves the JSON string's own `"` delimiters
  raw (it escapes only `< > & '`), so the attribute collapsed to empty,
  the client's `JSON.parse` threw and fell back to an empty baseline,
  and every body line diffed as added. The attribute is now
  single-quoted (minijinja's documented contract for `tojson`), the
  baseline parser hides the pane on any parse failure instead of
  diffing against an empty string, and the pane is relabelled "Pending
  body changes" since only the body textarea is tracked.

- **Editor live-preview logged a burst of Alpine "is not defined"
  errors on every load (b043)**: `admin.js` was the last `defer` script,
  so Alpine's microtask-scheduled auto-`start()` walked the DOM and
  evaluated `x-data="adminPreview(…)"` before the component was
  registered. The preview self-healed via an `Alpine.initTree` re-walk,
  but each load logged `adminPreview`/`statusLabel`/`requestRender`/
  `srcdoc` "is not defined" errors. The admin layout now loads `admin.js`
  **before** `alpine.min.js`, so its `alpine:init` listener registers the
  component before Alpine evaluates any `x-data` -- no console errors and
  no `initTree` re-walk on a normal load.

- **Admin Move/Delete redirect broke the HTMX modal flow (b042)**: the
  page Move and Delete handlers replied with a bare `303 + Location` to
  HTMX `hx-post` forms. HTMX's `XMLHttpRequest` follows the redirect
  before its JavaScript runs, so the browser never navigated -- the
  redirect target's full HTML was swapped into the modal host and the
  address bar went stale. HTMX requests now get `200 + HX-Redirect` (a
  real browser navigation); plain (no-JS) form posts keep the
  `303 + Location` fallback.

- **Move corrupted flat-file pages (b051)**: `move_page` assumed every
  page was a folder-index page (`NN.slug/default.md`) and moved it by
  renaming the page's parent directory. For a flat-file page
  (`<slug>.md`) the parent is the shared section directory, so the move
  tried to rename the whole section into its own child and failed with
  `failed to write file: .../01.renamed`. Move is now shape-aware
  (mirroring delete): folder-index pages rename their own directory,
  flat-file pages relocate just the file -- preserving the flat shape
  and numeric-prefix style and leaving sibling pages untouched.

- **Draft and review pages leaked on taxonomy, raw/API, feed, and
  rewrite surfaces (b021)**: draft filtering happened at content-load
  time, which both hid unpublished pages from the admin authoring UI
  and, where individual surfaces re-derived visibility inconsistently,
  exposed drafts publicly. The `/tags` and `/tags/{tag}` pages, the raw
  markdown and JSON API, RSS feed, sitemap, the static build page loop,
  and rewrite targets all drew straight from a status-agnostic index. The
  visibility decision is now made once in the presentation layer: the
  loader holds every page (so the admin can see and publish drafts) while
  every public surface applies the same `is_visible_at` / `show_drafts`
  gate -- a resolved-but-hidden draft takes the 404 path, draft-only tags
  drop out of taxonomy with corrected counts, and a published page can no
  longer rewrite to a draft target. Archived pages stay reachable by
  direct URL.

- **Content-model validation reported declared built-in fields as
  missing and ignored `_model.yaml` binding (b023)**: the validator
  checked required fields only against `frontmatter.custom`, so a model
  declaring a built-in slot (`title`, `date`, `tags`, `publish_date`,
  `slug`, ...) was falsely flagged as missing. The set of recognised
  built-ins is now a shared `BUILTIN_FRONTMATTER_FIELDS` list used by both
  validation phases. Separately, `_model.yaml` directory binding silently
  did nothing under `validate` because the walk-up compared canonical
  against relative/symlinked `source_path` forms; the page directory and
  content root are now canonicalised together so binding resolves. An
  explicit `model:` or a `_model.yaml` naming an unloaded model now warns
  instead of falling through silently.

- **`accent build` aborted with "template not found" for flat-file pages
  (b039, b040)**: `serve` falls back to `default.html.jinja` when a
  filename-derived template is missing, but the static HTML build path did
  not, so sites like the specs corpus could not be built. The build path
  now shares the same fallback. A companion fix makes `_model.yaml`
  directory binding work under `build` -- it was canonicalising a
  content-relative `source_path` against the process CWD instead of the
  content root, so the walk-up silently bound nothing.

- **CLI shared flags were rejected after a subcommand (b022)**: the
  `model`, `plugin`, and `git` commands declared their shared flags
  (`-c`/`--config` and friends) on the parent without `global = true`, so
  clap rejected them once it descended into a subcommand, and `cache` had
  the mirror-image bug (config accepted only after the subcommand). This
  left three inconsistent flag positions versus the flat `serve`/`build`/
  `validate` commands. The shared flags are now global on all four, so any
  ordering resolves to the same config.

- **`${VAR}` placeholders in config were never expanded; webhook secret
  silently insecure (b056)**: only four bespoke env readers existed, so
  every other `${VAR}` field was consumed verbatim. Most dangerously,
  `git.webhook.secret: "${GIT_WEBHOOK_SECRET}"` made the HMAC key the
  literal placeholder string -- forgeable by anyone with repo/image read
  access and silently passing the empty-secret guard. Config loading now
  walks the parsed YAML value tree and expands `${VAR}` / `${VAR:-default}`
  from the environment (keys untouched, structure preserved); an unset
  `${VAR}` is left literal so the misconfig stays visible, and webhook
  registration now rejects an unexpanded-placeholder secret instead of
  registering an endpoint keyed by the literal string.

- **Git deploy never went live after a push (b055)**: the fetch loop
  advances `refs/remotes/origin/<branch>`, but advancement was detected
  against -- and content served from -- the local `refs/heads/<branch>`,
  which the fetch never moves. A push advanced the remote-tracking ref, the
  local branch stayed put, the fetch reported "Already up to date", and the
  server kept serving the old tree until a manual `update-ref` and restart.
  Serve and detect now resolve the remote-tracking ref the fetch actually
  writes, so a webhook fetch surfaces on the next request with no restart.

- **Accented form submissions arrived as mojibake (b058)**: the
  accent-contact form decoder pushed each `%XX` byte via `byte as char`, a
  Latin-1 decode that splits multi-byte UTF-8 into one bogus char per byte
  -- `%C3%A9` became "Ã©" instead of "é", so names like "André", "Müller",
  and "Zürich" reached the operator email garbled. Percent-escapes are now
  accumulated as raw bytes and interpreted as UTF-8 once at the end;
  malformed escapes pass through verbatim.

- **Default-version redirect was a cacheable 301 (b063)**: a versioning
  root visited without a version prefix (e.g. `/docs`) redirected to the
  default version with a permanent 301. The default version is a moving
  pointer (v0.18 -> v0.19 -> ...), so browsers -- Safari most aggressively
  -- cached the target indefinitely, surfacing as a broken doubled
  `/docs/v0.19/v0.18/` after v0.18 was retired. The default-version
  redirect now emits a temporary 302 with `Cache-Control: no-cache` so the
  pointer is re-resolved every visit; permalink, deprecated-version, and
  frontmatter redirects keep their permanent/author-chosen codes.

- **Version lifecycle state was undefined in templates (b060)**: the
  per-version `state` field (computed by `effective_state()`) was dropped
  in `TemplateContext::to_value()`, so `version.state` / `v.state` were
  always undefined and the default theme's `(frozen)` dropdown marker and
  frozen-release note never rendered. State is now passed through both the
  top-level and per-entry version context.

- **Duplicate H1 rendered when the body heading matched the page title
  (b018)**: a body whose first `# Heading` matched the templated
  `page.title` produced two H1s on the page. A new markdown pipeline
  processor strips the leading H1 when it matches the title (whether the
  title came from the heading, frontmatter, or filename); a frontmatter
  title that differs from the body H1 keeps both, since the author wants a
  short nav title and a longer display heading.

- **Diagrams rendered as raw source in dev mode (b070)**: the Hybrid
  render strategy's server-vs-passthrough decision was mode-only, so dev
  mode emitted client pass-through markup for every diagram language. Only
  Mermaid has a browser renderer; svgbob/bob/d2 are server-side renderers,
  so their pass-through markup showed raw ASCII source. The decision is now
  language-aware and forces server rendering for a server-only language
  when its renderer is registered, even in dev mode.

- **Copy-code button corrupted diagram source in dev mode (b069)**: the
  copy-code island inserted a "Copy" button as the first child of every
  `<pre>`, including `pre.diagram-passthrough`. The dev-mode Mermaid loader
  reads each block via `textContent`, so the source became "Copy" + source
  and Mermaid rejected every diagram with "No diagram type detected". The
  island now selects `pre:not(.diagram-passthrough)`.

- **devdocs/default-theme search Enter did nothing until an arrow key was
  pressed (b024)**: `renderResults` always tagged the first result with
  `aria-selected`, but the keyboard handler kept `activeIndex` at -1 and
  the Enter branch required `activeIndex >= 0`, so pressing Enter right
  after typing followed nothing -- most visibly with a single result. Enter
  now follows the highlighted result, defaulting to index 0. Covers both
  the Simple and DocFind backends.

- **Wide tables overlapped the devdocs "On this page" sidebar (b027)**:
  content tables used only `width:100%`, which sets a preferred (not
  maximum) width, so a table wider than its grid column overflowed and
  rendered on top of the sticky TOC aside. Tables now render as a
  scrollable block (`width:max-content; max-width:100%; overflow-x:auto`)
  so narrow tables stay compact and wide ones scroll within their own
  column.

- **"Recently updated" widget showed a site-wide list everywhere (b050)**:
  the devdocs `recent_documents()` widget was called with no model filter,
  so every page showed the same list, and it only appeared in the
  detail-page sidebar. It now derives the section from the first URL
  segment, reads that section's document model from `_model.yaml`, and
  scopes the list to it; root and section landing pages now render the
  widget too (root showing overall recents).

- **Root/home page could not be opened, saved, or transitioned in the
  admin editor (b034, b035)**: the pages list links the root page (url
  `/`) to `/_admin/pages/`, an empty trailing segment the axum 0.8 `{*path}`
  catch-all cannot match, so opening or saving the home page 404'd; the same
  cause broke its draft->published transition. Dedicated `/_admin/pages/`
  and `/_admin/transitions/` routes now delegate to the existing handlers
  with an empty path. Move and Delete are deliberately omitted from the
  root row (and the modal handlers refuse a crafted `?url=/`) since moving
  or deleting the site root is not a supported operation.

- **Editor wrote an editable status field that silently republished drafts
  (b037)**: the editor rendered a status control stuck on the model default
  (`published`), and a plain Save wrote it back -- silently republishing any
  draft/review/archived page and bypassing the workflow state machine and
  its publish-validation gate. Model defaults that name a typed frontmatter
  field (like `status`) no longer pollute the custom map, the editor drops
  `status`/`published` from its passthrough fields, and Save omits status
  from the payload entirely (status is owned by the transition endpoint, so
  the on-disk value is preserved). The MCP `tools` surface was also wired up
  in this work: the server advertised the `tools` capability but the
  `ServerHandler` impl lacked `#[tool_handler]`, so all tools returned
  "Method not found" -- the attribute is now applied and the tools list and
  dispatch correctly.

- **New Page form created dead-on-arrival and over-published pages (b038,
  b041)**: the new-page form had no status control, so every page was born
  with the model's default status (`published` for blog) and bypassed the
  required-field validation the publish transition enforces -- landing an
  invalid published page. A Draft/Published select (default Draft) is now
  offered and create-as-published is validated up front and refused inline
  when required fields are missing. Separately, the scaffold always wrote
  `template: <model>`, but a theme need not ship a template per model, so
  pages for templateless models 404'd at their public URL and failed
  preview; the template is now pinned only when the theme actually ships a
  matching template, otherwise omitted so the `default` fallback applies.

- **Editor diff and source previews and validation links were broken
  (b016, b065, b066)**: in diff mode `render_diff_view` treated
  `page.source_path` as absolute, but the scanner stores it relative to the
  content root, so the `strip_prefix` guard fired for every page and every
  diff read "page is outside the content directory" (b016) -- the path is
  now joined against the content root first. Source and diff preview modes
  have no edit form, so their preview posted a path-only payload that
  clobbered the on-disk body with an empty overlay, leaving the pane
  showing chrome with no content (b065) -- a path-only payload now yields no
  overlay and the stored page renders unchanged. Validation report rows
  linked to a non-existent `/_admin/pages/edit?path=` route and 404'd
  (b066) -- they now point at the real `/_admin/pages{url}` editor route.

- **Editor list widgets (Tags, model lists) were inert (b036)**: the Add
  and per-row Remove buttons rendered with `data-list-add` /
  `data-list-remove` attributes, but no JavaScript handled them, so tags
  could not be added or removed at all. A delegated click handler now wires
  both, re-indexing rows and marking the form dirty; it preserves repeated
  `tags[]` names verbatim (the save handler aggregates them) and renumbers
  only indexed `name[i]` lists.

- **Media library was permanently dimmed and click-blocked (b028)**: the
  detail-drawer host painted a full-screen scrim at all times because its
  CSS gated visibility on `:empty` / `:not(:empty)`, and the host's
  two-line markup holds a whitespace text node that `:empty` never matches
  -- so the overlay was always on and intercepted every click on the
  search box, filters, +Upload button, and thumbnails. The scrim is now
  keyed on an actual `.media-drawer` child via `:has()` (which ignores
  text nodes) and the host markup was collapsed so its empty state is
  genuinely empty.

- **Media search box rendered the literal text "none" (b029)**: the media
  library and picker modal passed the `search` filter as a bare
  `Option<String>`; MiniJinja serialises a Rust `None` as its own `none`
  value, and the template's `default('')` only substitutes for *undefined*
  variables, not `none`, so a fresh open showed `none` in the Search box and
  a stray submit searched for "none". Both handlers now pass an owned empty
  string.

- **Admin build-status pill showed "offline" in dev mode (b033)**: the
  top-bar pill flashed "deployed" then settled on "offline" on a healthy
  admin dev server -- the static label defaulted to "deployed" while the
  mode was dev, and the status probe hit `/_dev/reload`, an SSE endpoint
  admin hot-reload deliberately does not serve, which errored and pinned the
  pill offline. The context now emits a mode-aware label and a
  `browser_reload` flag, and the probe returns early when browser reload is
  not applicable, so the pill reads "dev".

- **Schema browser leaked raw Rust Debug output for complex field types
  (b046)**: the Models browser built each Type cell with
  `format!("{:?}", field_type)`, which recurses into the full nested
  definition for list/object fields and leaked internal type names
  (`FieldDefinition`, `FieldConstraints`) and Rust value syntax
  (`Some(...)`, `bool(false)`) into the UI. A recursive formatter now
  renders a compact shape syntax (`list<...>`, `map<...>`,
  `object{ field: type!, ... }`, trailing `!` marking required). The same
  work made the admin handlers degrade gracefully when a disk-loaded
  dev-assets template is missing (b053): the eleven `.expect(...)`
  template lookups now use the logged-500 `render_error` pattern instead of
  panicking the worker.

- **Admin pages-list "Modified" column showed the frontmatter date, not
  the file mtime (b045)**: the column rendered the frontmatter date, so
  flat-file pages with no explicit date always showed "-" and the value
  disagreed with the "Last modified" sort and the editor's "Last modified"
  line. The page summary and detail views now carry a `modified` field
  populated from the file modification time, so list, sort, and editor
  agree.

- **`/_admin/` downloaded a 0-byte file instead of showing a 404 when
  admin was disabled (b068)**: the disabled-admin runtime gate returned a
  bare `StatusCode::NOT_FOUND` with an empty body and no Content-Type;
  combined with the global nosniff header, Safari could not type the body
  and saved it as a file. The gate now returns a typed, self-contained
  `text/html` 404 that renders in every browser.

- **Admin visual polish: unstyled editor and pages-list controls (b025,
  b030, b031, b032)**: several admin surfaces shipped with class names that
  had no matching CSS, falling back to browser defaults. The page editor
  used a double-dash `.admin-button--*` BEM convention the stylesheet did
  not define and had no form-body rules, so buttons collapsed to the plain
  base and the body textarea was tiny (b025); the `.admin-field`
  frontmatter widgets had no layout CSS, so labels sat inline and inputs
  clipped their values at the UA default width (b030); the page
  move/delete/children modals lacked the `.admin-modal-backdrop` wrapper, so
  they rendered as static blocks at the page bottom with no dimming or
  centering (b031); and the pages-list row-actions menu was a bare
  `<details>` disclosure whose `<ul>` rendered as an inline bulleted list
  clipped by the table's `overflow:hidden` (b032). All four are CSS/markup
  fixes that bring the controls to their intended styled, centered, and
  fully clickable state.

- **Admin audit-log directory was not gitignored (b047)**: the admin audit
  trail writes `<content_dir>/.admin/audit.log`, but the root `.gitignore`
  did not list `.admin/`, so running the admin against an in-repo content
  directory left untracked state authors could accidentally commit. Added
  `.admin/` to the root `.gitignore`.

### Changed

- **`gix` fork synced to upstream (monthly cadence, E026)** -- the
  `zoosky/gitoxide` fork's `main` fast-forwarded to upstream
  `GitoxideLabs/gitoxide` `eac50e120` (fork carried no divergent patches,
  so the sync is a clean fast-forward) and the Accent rev pin bumped
  `575113dfb` -> `eac50e120`, moving `gix` `0.83.0` -> `0.84.0`. Pulls in
  ~80 upstream commits including the gix-pack aggregate-delta allocation
  cap and shallow-clone tag-refspec fix. No Accent code changes required;
  the `gitoxide_contract` API-surface tests and the full git suite pass
  unchanged.
- **HTMX (admin shell) upgraded from 1.9.12 to 2.0.10** -- the vendored
  `themes/_admin/static/vendor/htmx.min.js` blob re-fetched via
  `tools/vendor-assets` with the embedded version marker verified, and the
  pin bumped in the tool manifest and `m039-non-cargo-dependencies.md`. The
  admin uses a narrow, modern HTMX subset and none of the features 2.x
  removed (`hx-on` shorthand, core WebSocket/SSE, `hx-boost`). The one 1->2
  behaviour change handled: htmx 2 makes 4xx/5xx responses non-swapping by
  default (`responseHandling`), so the admin shell now ships an `htmx-config`
  meta tag (`themes/_admin/templates/layout.html.jinja`) marking the
  swap-intended error codes 400 (transition errors), 409 (move/delete and
  edit conflicts) and 422 (validation errors) as `swap:true`. Because the
  delete form posts with `hx-target="body"`, the now-swappable delete 409s
  (`page_delete.rs`) set `HX-Retarget: #modal-host` so the children-block /
  blocked-delete fragment lands in the modal host instead of replacing the
  page body; the move failure fragment (`page_move.rs`) is wrapped in a
  dismissible modal for the same reason. Scoped to `/_admin/` only. Verified
  by the full admin Playwright + accessibility suite, including a new
  `admin-htmx-error-swap` spec that guards the error-swap config and the
  delete-409 retarget.
- **Alpine.js (admin shell) upgraded from 3.13.5 to 3.15.12** -- the
  vendored `themes/_admin/static/vendor/alpine.min.js` blob re-fetched via
  `tools/vendor-assets` with the embedded version marker verified, and the
  pin bumped in the tool manifest and `m039-non-cargo-dependencies.md`. A
  minor bump within Alpine v3 (no breaking API); the admin uses only stable
  v3 directives (`x-data`/`x-show`/`x-on`/`x-bind`/`x-cloak`/`x-if`/
  `x-model`/`x-ref`/`x-text`/`x-init`). Scoped to `/_admin/` only -- the
  public site and shipped themes use no Alpine. Verified by the full admin
  Playwright + accessibility suite (80 specs).
- **Rust toolchain upgraded from 1.94.1 to 1.96.0** -- pinned in
  `rust-toolchain.toml`, CI auto-downloads on first run. Clippy 1.96
  tightened several `pedantic`/`nursery` lints; production-code findings
  were fixed (e.g. `sort_by` -> `sort_by_key(Reverse(..))`, let-else,
  digit separators, `u64 as i64` -> `cast_signed()`) and a set of
  false-positive-prone or test-dominated pedantic/nursery lints
  (`similar_names`, `default_trait_access`, `field_reassign_with_default`,
  `needless_collect`, and others) are now allowed crate-wide in
  `[lints.clippy]`. The numeric `cast_*` lints are deliberately kept
  active (truncating/wrapping casts are a real bug class); the few
  intentional casts carry a local `#[allow]`.
- **`minijinja` upgraded 2.19.0 -> 2.20.0** -- patch-level template-engine
  bump in `Cargo.lock`; no Accent code or template-API changes required.

### Security

- **Extism upgraded 1.21 -> 1.30, Wasmtime 41 -> 43.0.2.** Extism 1.30
  moved its bundled Wasmtime to the patched 43 line, so accent's direct
  `wasmtime` dep (kept in lockstep for the `with_wasmtime_config`
  hardening) was bumped to 43.0.2. This resolves the twelve previously
  ignored Wasmtime advisories (RUSTSEC-2026-0085..0096, -0114); the
  `.cargo/audit.toml` ignore block was removed and `cargo audit` is
  clean. The WASM plugin runtime was verified end-to-end against the new
  versions (example plugin loads, executes, and renders). WASM plugins;
  Standard edition or higher.
- **Dropped the direct `wasmtime` dependency.** It existed only to force
  a patched Wasmtime over Extism's old orphaned 37 and to set
  `signals_based_traps(true)` -- both moot now that Extism 1.30 ships the
  patched Wasmtime 43 and enables signals-based traps in its default
  engine config. Wasmtime remains in the tree transitively via Extism;
  plugin sandboxing is unchanged (verified end-to-end).
- **Baseline security response headers now sent by default (f184).** A new
  global response-header middleware applies `X-Content-Type-Options:
  nosniff`, `X-Frame-Options: SAMEORIGIN`, a `Referrer-Policy`, and a
  baseline Content-Security-Policy on every page response. The baseline CSP
  deliberately carries no `script-src` / `default-src`, so existing theme
  and admin inline scripts keep working; the strict per-request-nonce page
  CSP is deferred to a follow-up. Headers are only set when a handler has
  not already set its own, and the policy is configurable and
  SIGHUP-reloadable via the new `http_headers` config block
  (`SecurityHeadersConfig`, documented in the configuration reference).
  Available in all editions.
- **Uploaded-SVG stored-XSS closed; media responses hardened (f184).**
  Every media-serving path now returns a strict `Content-Security-Policy:
  default-src 'none'; sandbox` plus `nosniff`, and `image/svg+xml` is
  served with `Content-Disposition: attachment` so a scriptable SVG
  downloads instead of executing inline -- centralised in the security
  middleware so it covers all media routes and takes precedence over the
  baseline page headers there. Additionally, the island renderer's
  `html_escape` helper was fixed to escape single quotes, aligning it with
  the shortcode helper and removing a latent single-quoted-attribute
  injection foot-gun.

## [0.18.1] - 2026-05-14

### Security

- **`lettre` 0.11.21 -> 0.11.22** clears RUSTSEC-2026-0141
  (CVSS 9.1, published 2026-05-14): TLS hostname verification
  disabled when using the Boring TLS backend. Accent builds with
  the `tokio1-rustls-tls` feature, not Boring TLS, so binaries
  shipped with v0.18.0 were **not** actually vulnerable. The
  advisory was published a few hours after the v0.18.0 tag and
  caused `release.yml`'s `cargo audit` step to fail before any
  binary uploads completed. v0.18.1 is a lockfile-only patch
  release that re-triggers the binary build with the cleared
  advisory; no other code changes from v0.18.0.

## [0.18.0] - 2026-05-14

### Added

- **Locale-Aware Smart Quotes (Epic E032, f147 series)**
  - Spec-driven locale table for smart-quote remapping with BCP-47
    region-aware lookup, replacing the previous hard-coded English
    pairs (f147, f147a, f147b)
  - Inner-guillemet spacing for French locales (NNBSP inside `« »`)
    (f147c)
  - Conservative apostrophe heuristic that preserves typographic
    apostrophes without misclassifying contractions (f147e)
  - Nested quote handling with a `reversedGuillemets` override for
    locales that flip outer/inner pairs (f147d)
  - RTL direction signal exposed in the template context so themes
    can adapt layout per page locale (f147f)
  - Deployment-level smart-quote override via `config.yaml`
    (`markdown.smart_quotes`) -- overrides per-page locale when the
    deployment wants a fixed style (f147g)

- **llms.txt and LLM Crawler Discovery (f121)**: build- and serve-time
  generation of `/llms.txt`, robots-style entries for known LLM
  crawlers, and a discovery `<link rel="llms-txt">` injected into
  every page so AI agents can locate the file without crawling
  guesses. Build and serve modes are byte-identical (b014).

- **Local Branch Preview (f140g)**: `?preview=branch=<name>` query
  parameter renders content from a named local git branch without
  changing the deploy ref. Useful for previewing editorial work
  before merge. Restricted to roles allowed by site access protection.

- **GitSource on the live serve path (f140k)**: the live server now
  reads pages through the same `GitSource` abstraction used by
  build, replacing the bespoke filesystem path. Enables consistent
  branch / ref handling and unlocks f140g preview wiring.

- **Git Sync Notification Extensions (f140j)**: divergence detection
  between the working tree and the deploy ref, reload-failure
  emails, and webhook-reject emails. Operators are told why a sync
  was refused (auth, signature, payload), not just that it failed.

- **Per-Block Diagram Render-Mode Override (f161r)**: an info-string
  attribute on a diagram code block can opt that block into a
  different render mode (`inline`, `island`, `image`) without
  changing the site-wide default.

- **Page-Local Media at Bare Page URL (f170)**: page-local files are
  reachable at the page's own URL, e.g.
  `/i18n/smart-quotes/quotes.spec.json` resolves to the same file as
  `/content-media/i18n/smart-quotes/quotes.spec.json`. Page URLs
  always win over the alias. Disabled per-site with
  `media.serve_at_page_url: false`, or per-page with the new
  `media: { expose: false }` frontmatter. The MIME allowlist now
  includes `json`, `xml`, `yaml`/`yml`, `toml`, `csv`, and `txt` so
  spec files, fixtures, and schemas shipped next to docs are
  servable. When a bare URL has no matching page or media file but
  its parent directory does have an index page, the 404 body names
  the parent (e.g. `parent page exists at /i18n/smart-quotes/`).

- **License Management (E028 continuation)**
  - **Core+ edition (f167)**: per-seat pricing tier sitting between
    Core (free) and Standard, covering production use without the
    Standard feature surface.
  - **Cadence-driven version ceiling (f166)**: JWT `version_pin`
    claim compared with `<=` so a license signed for `0.17.x`
    keeps working through every patch release of `0.17`, and the
    ceiling rolls forward with the licensing cadence.
  - **License trial flow (f168)**: 10-day trial per edition without
    requiring a key, with the trial state surfaced in
    `accent license status`.
  - **Pricing constants refactor (f169)**: the website is now the
    source of truth for edition prices; embedded constants were
    removed and the binary fetches the live table at activation
    time (with a baked-in fallback).
  - **Purchased date in `accent license status` (f165 G11)**: shows
    when the current key was issued in addition to expiry.
  - **license-gen tooling completeness (f165)**: closed 11 of 13
    gaps for the license issuance workflow; ships per-edition
    presets, batch operations, and an issuance audit log (m026).

### Changed

- **Dependency updates**
  - `gix` fork rev bumped to `575113dfb` -- pulls in upstream
    improvements to the smart-protocol negotiator used by
    `accent git fetch`
  - `encre-css` family bumped to `0.20.1` / `0.7.1` / `0.6.1`
    (encre-css, plugin, plugin-extra)

- **Smart-quote remapping pipeline**: previously a single English
  pair applied to every page; now selects the pair from the page
  locale via the f147 table, with deployment override via
  `markdown.smart_quotes`. Existing sites that relied on the
  English pair should set their config locale to `en` (or use the
  deployment override) to retain prior output.

### Fixed

- **`accent git` CLI usability (B005)**: `git push` and `git fetch` no
  longer require `git.remote.url` in `config.yaml` -- they fall back
  to the repo's origin remote, and importantly invoke system git by
  the remote *name* (not URL) so `[url].insteadOf` rewrites and
  `[remote "origin"].fetch` refspecs configured in `.git/config`
  continue to apply. Both commands produce a clear "remote URL not
  configured" diagnostic when neither the config nor the repo has a
  remote set. `git status` no longer errors on a fresh deploy and
  distinguishes "content directory not yet fetched", "directory
  exists but is not a git repository", and "open failed" so a corrupt
  `.git/` isn't mistaken for a fresh deploy. The displayed remote URL
  is annotated with `(from repo origin)` when picked up from
  `.git/config`, and SCP-style SSH URLs round-trip without scheme
  rewriting. Issues 5 (untagged-enum `git.remote: "url"`) and 6
  (system git for fetch credentials) shipped in earlier commits.

- **`GitSource.modified()` returns deploy-ref commit time** (PR #625):
  previously it returned the filesystem mtime of the checkout, which
  drifted after every `git fetch` even when the ref had not moved.
  Build and serve now report the deploy ref's commit timestamp, so
  RSS / sitemap / `lastmod` headers reflect content age, not deploy
  age.

- **llms.txt discovery link injection (B014)**: the discovery `<link>`
  tag is now injected through the template engine for both serve and
  build modes, restoring parity. Previously only serve mode injected
  the link, so static builds omitted it.

- **Benchmark fixtures (B011)**: template and markdown bench fixtures
  resynced with the current public API so `cargo bench --no-run`
  compiles cleanly again.

- **mmdr rev pin (B007)**: bumped to pick up the Linux layout-quality
  baseline regeneration and the `quality_gate.py` error-field fix.
  `layout_quality.sh` now forces an mmdr rebuild when the pinned rev
  changes.

- **Local CI Playwright setup**: `local-ci.sh` now creates a temporary
  `main` ref when one is missing, so the Playwright base-URL setup
  succeeds in fresh checkouts (PR #622).

### Behaviour change

- Bare URLs that previously returned 404 may now return 200 when a
  matching page-local file exists (f170). Sites that relied on 404s
  at bare media URLs (CDN fallthrough, strict URL contracts) should
  set `media.serve_at_page_url: false`.
- Pages whose effective locale differs from `en` will receive
  locale-appropriate smart-quote pairs after f147 lands, instead of
  the previous English pair. Lock to English (or the prior style)
  via `markdown.smart_quotes` in `config.yaml`.
- License keys signed against version `X.Y.Z` now accept any
  release up to and including that version via `<=` comparison
  (f166). Keys remain valid across patch releases without a re-issue.

### Security

- `cargo audit`: 0 vulnerabilities, 5 informational warnings.
  - Two unmaintained-crate notices on the `diagrams-svgbob`
    transitive path: `paste` (RUSTSEC-2024-0436) and
    `proc-macro-error` (RUSTSEC-2024-0370). The svgbob 0.7.2 pin
    has not changed since v0.17.0; both crates were already in the
    dependency tree at that release, and the advisories surfaced
    via RustSec database additions, not a dep change. Neither is
    a vulnerability.
  - `rand` warning from v0.17.0 prep stayed cleared after the
    0.8.6 bump.
  - All ignored advisories remain blocked on the same upstreams
    (extism -> wasmtime 41, syntect -> yaml-rust / bincode).
    See `specs/bugs/b006-cargo-audit-warnings-2026-04.md` for the
    full re-evaluation, including the two svgbob-path entries.

### Documentation

- E023 git deployment epic reconciled with shipped reality
- E032 canonical smart-quote i18n epic filed and surfaced in docs
- B013 YAML sprawl and R076 tree-sitter highlighting research
  recorded; B006 syntect 6.0 outlook corrected
- m026 license issuance workflow added
- f165, f166, f167, f168, f169 license planning specs promoted to
  Done as the work shipped

## [0.17.0] - 2026-05-03

### Added

- **Mermaid Rendering in Core Edition (Epic E029, f160 series)**
  - Vendored `accent-mmdr` fork as the canonical source for Mermaid
    rendering, treated as fork-as-primary against
    `1jehuang/mermaid-rs-renderer` (f160a, f160g)
  - Embedded Inter font in mmdr eliminates startup `fontdb::Database`
    construction (~11 ms -> ~1 us per fresh DB) (f160b, f160c)
  - `render_strict` and `render_with_warnings` lenient modes plumbed
    through the Accent wrapper, preserving structured `ParseError`
    detail for content authors (f160b, f160f)
  - Source-provenance markers in generated SVGs (phase 1 + phase 2)
    let downstream tools attribute output back to its diagram source
    (f160e, f160q)
  - Semantic SVG output with deterministic content-hash IR for
    stable build cache keys (f160i)
  - **Mermaid conformance corpus** (f160p): 23 diagram types, AST or
    SVG-structural-diff baselines, fast/full CI split via
    `conformance.yml`
  - **Layout-quality CI gate** (f160o): `quality_gate.py` baseline
    comparison wired into `layout-quality.yml`
  - Binary-size budget with measured Linux x86_64 baseline plus
    `cargo bloat` symbol breakdown for regression tracking (f160d)

- **Document Type Body Schema (Epic E017, f125 series)**
  - Body and taxonomy schema DSL for document models (f125a)
  - Markdown body structure extractor (f125b)
  - Body and taxonomy validation surfaced via `accent validate` (f125c)
  - Body sequence pattern constraints (e.g. headings must follow
    introductions) (f125d)
  - Scaffolding and observability hooks for body/taxonomy schemas
    (f125e)
  - Extended body element coverage (lists, tables, code, media) (f125f)

- **Diagram Pipeline Enhancements (Epic E030, f161 series)**
  - `diagram()` template function for inline diagram rendering (f161h)
  - `render_diagram` Extism plugin hook (Pro edition) -- third-party
    diagram engines via WASM (f161k)
  - Pikchr example diagram plugin demonstrating the plugin hook (f161l)
  - Themable diagram-overlay reference theme (f161j)
  - Starter template renders example Mermaid SVGs out of the box
    (f161o)

- **PDF Metadata-Card Thumbnails (Feature f066f, all phases)**
  - **Phase A**: convention-based sibling thumbnails, frontmatter
    `thumbnail` overrides, on-demand `?thumb` query parameter, and
    full build-time pipeline integration
  - **Phase B/C**: `pdf-thumb-card` Cargo feature (in
    `edition-standard`/`pro`) wires the `accent-pdf-thumb-card`
    workspace crate as the Layer 3 backend. When no Layer 1 sibling
    thumbnail or Layer 2 frontmatter override exists, `?thumb`
    returns a self-contained SVG card with the PDF's title and
    author from its Info dictionary or XMP metadata stream.
  - Plugin formalisation: `metadata["thumbnail_url"]` set by
    `on_media_discover` plugin hooks is now bridged onto the typed
    `MediaAsset.thumbnail_url`, flowing directly to templates via
    `pdf_card()` and `filter_documents` without going through the
    `?thumb` query parameter.
  - Dedicated `MediaProcessor::acquire_metadata_permit` semaphore
    (sized at `2 * available_parallelism`) decouples metadata-card
    concurrency from CPU-bound image processing.
  - 10-second wall-clock timeout on metadata-card extraction (both
    serve and build modes) bounds the worst case for crafted or
    pathological PDFs.

- **Heading Anchors with Click-to-Copy (f164)** -- per-theme style
  presets and clipboard integration on heading hover

- **Embedded Documentation Server (f162)** -- `accent serve --docs`
  serves the documentation site straight out of the binary, no extra
  flags or content directory required

- **Git Deployment Observability (f140h)** -- `/_health/git`
  endpoint exposes git sync state (last fetch, last push, conflicts);
  structured sync notifications surface in templates and admin UI

- **`accent cache clear` (b008)** -- new CLI subcommand to flush the
  page render cache without restarting the server

- **gitoxide API contract tests (f163)** -- guards the surface area
  Accent depends on so future `gix` upgrades fail at compile time
  rather than at runtime

### Changed

- **`media.pdf.auto_thumbnails` default flips from `false` to `true`**
  when the `pdf-thumb-card` Cargo feature is compiled in (i.e. all
  `edition-standard` and `edition-pro` builds). PDFs without an
  author-provided thumbnail now serve a metadata card by default
  instead of the generic SVG document icon. Set `auto_thumbnails:
  false` under `media.pdf:` in `config.yaml` to restore the
  pre-0.17.0 behaviour.

- **Dependency updates** (release prep, PR #583): `cargo update`
  applied all compatible bumps including `reqwest` 0.13.2 -> 0.13.3,
  `rmcp` 1.5.0 -> 1.6.0, `rustls` 0.23.39 -> 0.23.40,
  `rustls-platform-verifier` 0.6 -> 0.7, `quick-xml` 0.38 -> 0.39,
  `wasm-bindgen` 0.2.118 -> 0.2.120, plus ~30 transitive bumps.

- Self-hosted runner systemd unit renamed `accentcms.runner` ->
  `accent.runner` to match the binary (operations spec m009)

### Fixed

- Mermaid loader was gated behind a feature check that hid output
  from the `diagram()` template function (f161h)
- Mermaid SVG mount used strict XML parsing, breaking in some content
  layouts; now uses HTML parsing
- Mermaid CDN URL was over-escaped by templates; now marked safe
- Mermaid-loader partial was missing from devdocs base template
- Devdocs diagrams overflowed the content column on narrow viewports
- OrbStack runner provisioner did not pass `--replace` to `config.sh`,
  causing re-provisioning to wedge on stale config (B010)
- CI: layout-quality and benchmark workflows broke on shared
  `target/` reuse; force per-checkout target dir (f160o)
- Build state: `diagram_dispatcher` was not populated in
  `from_content_source`, breaking diagrams during build mode

### Removed

- The unused `pdf-thumbnails` Cargo feature stub. PDFium-based
  rasterization was evaluated in `specs/architecture/a006-pdf-thumbnail-strategies.md`
  but is not implemented and not currently planned.
- `bd` (beads) issue tracking from the repository. Issues are now
  tracked exclusively under `specs/features/`, `specs/bugs/`,
  `specs/architecture/`, etc. (B009)

### Security

- `rand` 0.8.5 -> 0.8.6 clears the RUSTSEC-2026-0097 audit warning
  (advisory does not apply to Accent code paths but the bump is free)
- All `cargo audit` advisories re-evaluated for the release; ignored
  list in `.cargo/audit.toml` reduced to entries with documented
  upstream blockers (wasmtime 41 via extism, syntect 5 via
  yaml-rust/bincode)

### Documentation

- Mermaid conformance and layout-quality CI specs added to m014
  (CI and Release Process)
- a006: PDF thumbnail strategies architecture review
- m020: Island asset distribution
- m022: Beads multi-machine sync (historical, B009 retired this)
- m025: Website pricing as source of truth
- r074: HTMX admin UI 1.0 product spec
- r075: HTMX admin UI visual design language
- f167: Core+ edition (per-seat pricing tier, planning)
- f168: License trial flow (10-day, planning)
- f169: Pricing constants refactor (planning)
- License versioning policy moved to ceiling-and-rolling-window
  model (k004, k005, f166)

## [0.16.0] - 2026-04-13

### Added

- **Template-Driven Islands Architecture (Epic E021)**
  - Template-driven islands with `{% island %}` directives for interactive components (f101a)
  - Markdown island directives: `:::island` syntax for inline island embedding (f101b)
  - Plugin-provided islands: WASM plugins can register island types (f101c)
  - Contact form island plugin (`accent-contact-island`) with idle hydration (f138d)
  - Island hydration patterns documentation (lazy, idle, visible, media)

- **Markdown Extensions Pipeline (Epic E025)**
  - Configurable markdown parser extensions via `config.yaml` with 15+ toggles (f145a)
  - Flag-only extensions and `MetadataBlockStripper` for YAML metadata blocks (f145b)
  - `WikiLinkProcessor` for `[[Page Name]]` resolution with broken-link validation (f145c)
  - `BacklinkIndex` for automatic backlink tracking exposed in templates (f145d)
  - `AdmonitionProcessor` for GFM blockquote alerts (`> [!NOTE]`, `> [!WARNING]`) (f145e)
  - `MathProcessor` for LaTeX math rendering (`$inline$`, `$$display$$`) (f145f)
  - Markdown extensions documentation page (f145g)
  - Infobox shortcode with type variants (info, warning, tip, danger) (f145i)
  - Tabs shortcode for tabbed content panels (f145j)

- **Git-Based Deployment (Epic E023)**
  - `GitRepository` wrapper for content reads via gitoxide (f140a)
  - `GitSource` implementing `ContentSource` trait (f140b)
  - Git fetch, branch tracking, and CLI commands (f140c)
  - Webhook receiver for git push events (f140d)
  - Mutation audit commit creation (f140e)
  - Git push via system git binary (f140f)

- **Server Roles and Content Guards (Epic E024)**
  - Server role configuration: `publisher`, `author`, `developer` (f141a)
  - Mutation guards based on server role (f141b)
  - Publisher git guardrails with auto-commit on content changes (f141c)
  - Author git guardrails with pull-before-edit and push-after-save (f141d)
  - File-based data store for user-generated content (f141e)
  - Periodic git export for UGC data (f141f)

- **License Management (Epic E028)**
  - License version pinning to JWT claims (f154)
  - Post-grace content freeze instead of hard rejection (f155)
  - Centralized license pricing URLs and constants (f156)
  - License key revocation via compiled JTI list (f157)
  - License management CLI: `accent license status/activate/deactivate/buy/renew/refund` (f158)
  - Centralized edition upsell messages (f159)

- **Site Access Protection** -- basic auth and IP allowlist for staging/preview sites (f142)
- **DocFind RAKE keyword budgets** -- configurable via `search.keyword_budgets` (f144a)
- **MCP SDK upgrade** -- rmcp 0.17 to 1.4 stable API (f080e)

### Changed

- **Dependency upgrades:**
  - `jsonwebtoken` 9 -> 10 (rust_crypto backend, Ed25519-only)
  - `sha2` 0.10 -> 0.11, `hmac` 0.12 -> 0.13 (RustCrypto digest 0.11)
  - `winreg` 0.52 -> 0.56 (drops unmaintained winapi-rs for windows-sys)
  - `lightningcss` 1.0.0-alpha.70 -> alpha.71
  - `wasm-encoder` / `wasmparser` 0.240 -> 0.246
  - `axum-test` 18 -> 20, `rustls` 0.23.37 -> 0.23.38
  - `rmcp` 0.17 -> 1.4 (stable MCP SDK)
  - Gitoxide fork synced to upstream (26a5f65e2)
  - pulldown-cmark fork: superscript punctuation fix for chemical ions
- **License grace period** changed from 60 days to 365 days (annual licensing model)
- **Per-seat licensing renamed to per-site** (domain-based)
- **Render pipeline** extracted to `page/render.rs` (500-line rule)

### Fixed

- Build `apply_overrides` used wrong `--site-dir` path (extra `site/` and `main/` components)
- MCP `site_dir` override lacked `--content-dir`/`--theme-dir` precedence logic
- `LicenseArgs.config` was `String` instead of `PathBuf`
- `execute_buy` with invalid edition exited with code 0 instead of error
- `generate_state_token` used predictable timestamp+PID; now uses `getrandom`
- rustls `CryptoProvider` not installed at startup causing TLS panic
- Plugin `config` not passed to Extism manifest (B004)
- Git CLI empty remote URL and config ergonomics (B005)
- Version switcher 404 on missing pages (B003)

### Security

- Cargo audit re-evaluation: all 16 advisories reviewed (b006)
- `rsa` crate advisory (RUSTSEC-2023-0071) documented as unreachable (Ed25519 only)
- 11 wasmtime CVEs documented, blocked on extism upgrade
- `generate_state_token` now uses cryptographic randomness

### Documentation

- Markdown extensions guide (wiki links, math, admonitions, definition lists, etc.)
- Island architecture guide with hydration patterns
- Git deployment and webhook setup guide
- Site access protection guide
- Server roles documentation
- Release process updated with cargo audit and dependency review steps
- Forked dependencies documented in release process (m014)
- Research r067: text-based diagram tools (Mermaid, Svgbob, D2)

## [0.15.0] - 2026-03-30

### Added

- **DocFind Native Search Parity (Epic E014)** -- fuzzy search across all API layers
  - Native `DocFindNativeIndex` for server-side fuzzy search via the zoosky/docfind fork with `native` feature (f137a)
  - CLI `accent query search` with `--backend=auto|docfind|simple` flag (f137b)
  - REST API `/api/v1/search` uses DocFind when available, includes `backend` field in response meta (f137b)
  - MCP `search_content` tool uses DocFind with fallback to simple matching (f137c)
  - 17 cross-interface search parity tests verifying result consistency (f137e)
  - Single index build -- DocFind index built once and shared between WASM and native paths, eliminating non-deterministic keyword divergence

- **Contact Forms and Email Notifications (Epic E022)**
  - `request.path` and `request.query` accessible in templates for form validation feedback and query-param-based UI (f138)
  - Plugin route dispatch fix: POST method, headers, and body now forwarded to WASM plugin route handlers (f138a)
  - SMTP notification service with `lettre`: `SmtpService::send()` Rust API + `/_internal/smtp/send` HTTP endpoint for plugins (f138b)
    - Three TLS modes: `starttls` (default), `implicit`, `none` (for dev servers)
    - Rate limiting (configurable per-minute), localhost-only enforcement via ConnectInfo
    - Password via `ACCENTCMS_SMTP_PASSWORD` env var
  - Contact form WASM plugin (`plugins/accent-contact/`) with CSRF injection, field validation, SMTP forwarding, and redirect flow (f138c)
  - Contact form template, content pages, and pre-compiled plugin in `site-dev/`

- **Content Source Abstraction (Epic E020)**
  - `ContentSource` trait with `FilesystemSource` and `MemorySource` implementations (f135a)
  - `ContentLoader` source integration -- all content loading goes through `ContentSource` (f135b)
  - Theme and `TemplateEngine` source integration (f135c)
  - Asset serving via `ContentSource` (f135d)
  - `accent docs serve` command for embedded documentation (f135e)
  - `MemorySource` test migration for faster, OS-independent tests (f135f)
  - Consolidated parallel functions into trait-based design (f135g)

- **Static Site Generator Improvements (Epic E019)**
  - Asset fingerprinting and cache busting with content-hash filenames for `accent build` (f132)
  - `get_env()` template function for environment variable access (f133)
  - `get_hash()` template function for SHA-256 hashing (f134)

- **Filesystem Mounts** -- serve content from multiple directories with configurable mount points and priority (f129)
- **Plugin Content Source Hook** -- `on_content_load` hook for plugins to contribute pages to the content index (f025h)
- **WASM Plugin CI** -- CI pipeline builds and verifies all WASM plugins (`accent-contact`, `llm-tagging`) on `plugins/**` changes
- **Windows Runtime Hardening** -- `LongPathsEnabled` check and `dunce` canonicalization for Windows compatibility (f120a)

### Changed

- **Rust toolchain upgraded from 1.93.0 to 1.94.1** -- pinned in `rust-toolchain.toml`, CI auto-downloads on first run
- **Internal spec references hidden from user-facing output** (f136) -- feature IDs moved from `///` doc comments to `//` code comments, site-docs wrapped in HTML comments. CLAUDE.md Rule 19 enforces this going forward.
- **Plugin route responses** now respect the plugin's status code and custom headers (was always 200 text/html)
- **Plugin WASM execution** runs on `spawn_blocking` thread to prevent deadlock when plugins call back to the same server
- **Cache bypass** for requests with query strings to prevent cache poisoning from query-dependent template output
- **Taxonomy handlers** (`/tags`, `/tags/{tag}`) now expose `request.path` and `request.query` to templates
- **`form_urlencoded`** crate used for query string parsing with proper percent-decoding and `+`-as-space

### Fixed

- **DocFind duplicate keyword extraction** -- index built twice with non-deterministic `HashSet` iteration causing 1-keyword divergence. Now built once and shared.
- **DocFind `println!` in library** -- removed stdout printing from `docfind_core::build_index()`, replaced with application-level `tracing::info!`
- **Benchmark OOM kills** -- resolved memory issues and orphaned runner VMs in CI benchmarks
- **Plugin `allowed_hosts`** -- was in wrong TOML section (`[allowed_hosts]` vs field on `[plugin]`)
- **SMTP `SmtpTransport::relay()`** -- used implicit TLS which fails against plain SMTP servers. Now uses `builder_dangerous()` for `tls: none`
- **SMTP Content-Type check** -- case-insensitive header check using `eq_ignore_ascii_case` instead of exact string match
- **SMTP rate limiter** -- TOCTOU race fixed by holding write lock through counter increment, `Ordering::SeqCst` for ARM visibility
- **SMTP email validation** -- invalid addresses now return 400 (not 500) with validation in the handler before calling `send()`
- **`truncate_snippet` UTF-8 panic** -- `floor_char_boundary()` prevents panic on multi-byte codepoints

### Security

- **CVE fixes** -- upgraded extism 1.20 to 1.21, resolving 3 wasmtime CVEs
- **SMTP endpoint localhost-only** -- `/_internal/smtp/send` rejects non-loopback IPs with 403 via `ConnectInfo` extraction
- **SMTP rate limiting** -- configurable per-minute limit prevents email flooding

### Documentation

- SMTP notification service user guide (`site-docs/v0.15/14.smtp-notifications/`)
- Contact form plugin setup guide (`site-docs/v0.15/15.contact-form/`)
- Request context reference in templating guide (`request.path`, `request.query`)
- Asset fingerprinting guide (`site-docs/v0.15/10.asset-fingerprinting/`)
- Environment variables guide (`site-docs/v0.15/11.environment-variables/`)
- Hashing functions guide (`site-docs/v0.15/12.hashing/`)
- Theme portability guide (`site-docs/v0.15/13.theme-portability/`)

### Specs and Research

- **Epic E014:** DocFind Search Parity (4/5 done, gRPC deferred)
- **Epic E019:** Static Site Generator (3/3 done)
- **Epic E020:** Content Source Abstraction (9/12 done)
- **Epic E022:** Contact Forms and Email (4/5 done, Islands deferred)
- **Epic E023:** Git-Based Deployment proposal (Accent Pages)
- **Epic E024:** Server Roles proposal (Publisher / Author / Developer)
- **R010:** Contact form implementation options
- **R060:** User-generated content storage options
- **f139:** Git branching strategy documented (trunk-based on master)


## [0.14.0] - 2026-03-23

### Breaking Changes

- **Binary renamed from `accentcms` to `accent`** (Feature f127)
  - The CLI binary is now `accent serve`, `accent build`, `accent init`, etc.
  - The Rust crate is now `accent` (`use accent::` in downstream code)
  - MCP resource URIs changed from `accentcms://` to `accent://`
  - Release archives renamed from `accentcms-*` to `accent-*`
  - **Migration:** reinstall the binary; update shell aliases, scripts, and Claude Desktop MCP config (`"command": "accent"`, URIs `accent://...`)

### Security

- **CVE-2026-24116 mitigation** (Feature f128) — Enable `signals_based_traps(true)` in wasmtime config for WASM plugin runtime, mitigating segfault/out-of-sandbox vulnerability on x86-64/AVX
- **Dependency upgrades** — extism 1.13.0 to 1.20.0, plus 10 other dependencies to latest compatible versions (chrono, clap, image, minijinja, moka, pulldown-cmark, regex, rustls, tokio, tracing-subscriber)
- **rcgen 0.13 to 0.14** — TLS certificate generation library upgraded; API migrated from `key_pair` to `signing_key`
- **axum-server 0.7 to 0.8** — HTTP server library upgraded

### Added

- **Cross-Platform Config Reload via HTTP Admin Endpoint** (Feature f120b)
  - `POST /_admin/reload` — reload `config.yaml` at runtime without restarting the server. Cross-platform alternative to SIGHUP; the only reload mechanism on Windows where SIGHUP is a no-op.
  - Dev mode: endpoint always open, no token required
  - Production mode: requires `Authorization: Bearer <token>` or `X-Admin-Token: <token>` header matching `ACCENT_ADMIN_TOKEN` env var or `config.admin.token`
  - Returns `401` for invalid token, `503` if no token is configured, `429` when rate limit exceeded (10 req/min), `500` on reload failure
  - Token comparison is timing-safe (constant-time XOR over full length, no early exit on length mismatch)
  - New `admin:` config section: `admin.token` sets the production auth token

- **Windows Runtime Compatibility Audit & Hardening** (Feature f120a)
  - Frontmatter CRLF normalization: `normalize_line_endings()` strips `\r\n` before YAML parsing so content checked out on Windows with `core.autocrlf=true` parses identically to LF content
  - Config tests: `#[cfg(unix)]`/`#[cfg(windows)]` guards on three tests that used Unix-only `/tmp/test-site` path literals, with Windows-native TempDir variants
  - Watcher: all three `std::fs::canonicalize` calls replaced with `dunce::canonicalize` to prevent `\\?\` prefix paths reaching other subsystems
  - `accent validate`: new `#[cfg(windows)]` advisory check warns when `LongPathsEnabled` registry key is not set
  - New `tests/windows_integration.rs`: Windows-gated integration tests for CRLF frontmatter round-tripping
  - `winreg = "0.52"` added as Windows-only target dependency

- **Windows CI** (Feature f073d) — Windows x86_64 quality check job added to CI pipeline

### Fixed

- **Config path resolution on Windows** — `dunce::canonicalize` used in `Config::load` to strip `\\?\` UNC prefix that broke path comparisons
- **Search results dropdown** — now visible on all screen sizes (#345)

## [0.13.0] - 2026-03-16

### Added

- **CLI Template Introspection** (Feature f113, PRs #295, #296)
  - `accentcms docs template-filters` -- list all available MiniJinja filters, tests, and global functions with signatures
  - `accentcms docs template-context` -- print the full template variable schema with types and nesting
  - `accentcms validate --templates` -- syntax-check all Jinja templates in the theme directory without a full render
  - `query list --nav` flag to return only navigation-visible pages (menu-visible, published, top-level) in canonical menu order
  - Fixed `update-frontmatter --set` dotted key handling: `menu.visible=false` now creates nested YAML mappings instead of flat string keys

- **MCP Template Introspection Parity** (Feature f114, PR #296)
  - `accentcms://templates/filters` MCP resource -- exposes filter/test/function reference to MCP clients
  - `accentcms://templates/context` MCP resource -- exposes template context schema to MCP clients
  - `validate_templates` MCP tool -- syntax-checks all theme templates via MCP
  - `list_pages` MCP tool now supports `nav_only` parameter for navigation-aware queries (Feature f114c)

- **Media Plugin Hooks** (Feature f066e, PR #299)
  - `on_media_process` hook -- plugins intercept media processing to apply custom transformations (watermarking, custom format encoding)
  - `on_media_discover` hook -- plugins augment media metadata during scanning (EXIF extraction, blur hashes, video duration)
  - Plugin executor wired into both the serve and build media pipelines

- **Cold-Start Performance Optimization** (Feature f076, PR #304)
  - Production-mode cache fast path: early cache check before filesystem I/O in `serve_page_inner`, skipping `load_page()` for cached pages
  - Cache warming at startup: new `cache.warming` config option (default: `false`) renders all pages via background tokio task
  - `CacheEntry` now stores `language` field so the fast path can build correct `Content-Language` headers without disk access
  - First-hit latency reduced from up to 1,121ms to <5ms on code-heavy pages when warming is enabled

- **HTTP Cache Headers and CORS** (Feature f116, PR #306)
  - Tower middleware layers apply `Cache-Control`, `ETag`, `Vary`, and CORS headers to all responses
  - Dev mode: `Cache-Control: no-store` on all responses
  - Production mode: content-type-based defaults (HTML 5 min, static assets immutable 1yr, media 24h, fonts immutable, feeds 1h)
  - Per-route glob overrides via `http_headers.routes` config section
  - Conditional requests: `If-None-Match` / `If-Modified-Since` return `304 Not Modified`
  - ETags use SipHash (no new dependencies)
  - CORS middleware supports global config and per-route overrides with preflight OPTIONS handling
  - `http_headers.cors` config section supersedes legacy `api.cors` toggle (deprecation warning if both are set)
  - Cache and CORS middleware also applied to `serve-static` command

- **Agent Notification Sound** (Feature f115, PR #302)
  - `.claude/hooks/notify-sound.sh` plays macOS `Hero.aiff` via `afplay` when a Claude Code agent finishes its turn
  - Registered via `Stop` hook in `.claude/settings.json`; runs asynchronously so it never blocks the agent

### Changed

- **Self-Hosted CI Runner** (Feature f073a, PR #307)
  - CI `check` and `editions` jobs now run on `[self-hosted, linux, x64, rust]`
  - macOS and Windows matrix removed from standard CI (retained for release builds)
  - Benchmark workflow moved to merge-only trigger (removed `pull_request` trigger)
  - Concurrency group cancels redundant PR runs; `timeout-minutes` added to all self-hosted jobs

- **Rust File Restructure Phase 1** (Feature f125, PRs #328, #333)
  - 10 critical files (3-6x over the 500-line limit) converted to directory modules with focused sub-modules
  - `commands/build.rs` (3,401L) → `build/{mod,render,taxonomy,supplementary,search,api,media,paths,pagination}.rs`
  - `server/handlers/page.rs` (2,781L) → `page/{mod,context,debug,response,raw}.rs`
  - `render/json_ld.rs` (2,144L) → `json_ld/{mod,builders,common,helpers}.rs`
  - `content/model.rs` (2,120L) → `model/{mod,parse,registry,inheritance,loader}.rs`
  - `content/model_validation.rs` (1,841L) → `model_validation/{mod,constraints}.rs`
  - `render/shortcode.rs` (1,721L) → `shortcode/{mod,processor,builtin,theme}.rs`
  - `content/index.rs` (1,716L) → `index/{mod,hierarchy,taxonomy,media}.rs`
  - All existing import paths preserved via `pub use` re-exports; no API changes

### Performance

- **Syntax Highlight Result Cache** (Feature f126, PR #334)
  - Bounded `moka::sync::Cache` keyed on `hash(code + language + theme)` in `src/render/markdown/highlight.rs`
  - Cache hits skip the syntect tokenizer entirely: `code_with_highlight` benchmark reduced from **836,396 ns** to **1,791 ns** (467x speedup)
  - Variance reduced from 21% to 2.6%
  - 512-entry limit with byte-weight cap; co-located with `SYNTAX_SET` and `THEME_SET` statics
  - New `code_with_highlight_warm` benchmark measures steady-state cache performance

### Fixed

- Gate plugin config access behind `plugins` feature flag to fix compilation in `edition-core` (#308)

## [0.12.0] - 2026-03-03

### Added

- **Document Models** (Epic E011, Features 112a-112e)
  - User-definable YAML schemas in `models/` directory for content types (blog, event, ticket, product, etc.)
  - 15-type field system (string, integer, number, boolean, date, datetime, enum, url, email, list, map, reference, media, object, text) with constraints (min/max, pattern, enum values, list item counts)
  - Model-to-page resolution by template name, explicit `model` frontmatter field, or directory-level `_model.yaml`
  - Model defaults applied to pages during loading (per-field and top-level)
  - Theme-provided models in `themes/<name>/models/` with project-level override
  - `content.models_directory` config option (default: `./models`)
  - `page.model` exposed in template context for introspection

- **Cross-Field Rules and Composition** (Feature f112b)
  - Single inheritance via `extends` with field merging and cycle detection
  - Cross-field validation rules using MiniJinja expressions (e.g., `end_date >= start_date`)
  - Module constraints (allowed/required/max) for modular pages (Feature f058)
  - Section constraints for structured content (Feature f059)
  - Configurable validation mode: `content.validation.mode` (warn/strict/off)

- **Filename Pattern Type** (Feature f112c)
  - Declarative filename constraints in models with 13 segment types (`{order}`, `{slug}`, `{date}`, `{field:name}`, `{enum:...}`, etc.)
  - Bidirectional patterns: validate existing filenames and generate new ones during scaffolding
  - Cross-validation between filename segments and frontmatter field values
  - Multi-level directory patterns for archive structures (e.g., `{year}/{month}/{slug}`)

- **Document Model CLI Tooling** (Feature f112d)
  - `accentcms model list` -- display loaded models with source locations
  - `accentcms model show <name>` -- display full schema with inherited fields, rules, and constraints
  - `accentcms new <model> <title>` -- scaffold content from models with pattern-aware filenames
  - `--models` and `--model <name>` flags on `accentcms validate`
  - Collection `model:` filter for type-aware content queries
  - `accentcms query list --model=<name>` filtering

- **Plugin-Provided Models** (Feature f112e)
  - Plugins can ship YAML models in `plugins/<name>/models/`
  - `register_models` WASM hook for dynamic schema registration
  - Three-tier override priority: plugin > project > theme
  - Model source provenance tracking in `accentcms model list`

- **Research: Document Models** (`specs/research/r041-document-models.md`)
  - Industry survey: Grav blueprints, Jira issue types, Confluence blueprints, AEM Franklin blocks, headless CMS content types (Contentful, Strapi, Sanity)
  - Four implementation strategies evaluated; YAML model files + plugin extensibility recommended

## [0.11.2] - 2026-03-02

### Improved

- **Startup logging** (PR #271): Show config file path (or "built-in defaults") in banner; show theme directory alongside theme name; actionable error messages when paths are missing, suggesting `accentcms init` or `-c <path>`

- **Edition naming** (PR #272): Startup banner shows "License: Core (free, includes serve + build)" instead of "License: none (dev mode only)" for unlicensed installs

### Added

- **Root convenience config**: `config.yaml` at project root points to `site-dev/` so `cargo run -- serve` works without `-c` flag

## [0.11.1] - 2026-03-01

### Fixed

- **Starter template layout** (PR #268): Flatten content structure from `content/main/` to `content/` for direct serving with `accentcms serve -c sites/starter/config.yaml`; fix CSS asset path, MiniJinja filter usage, and custom frontmatter nesting; add missing `tags.html.jinja` and `tag.html.jinja` templates

- **Site reorganization** (PR #269): Update all code paths after `site/` was renamed to `site-dev/` and documentation moved to `site-docs/`; config defaults now use flat paths (`./themes`, `./content`, `./media`) instead of `./site/...` prefixed paths

### Changed

- **Config defaults**: All default paths are now flat (`./themes`, `./content`, `./media`, `./.media-cache`, `./plugins`) instead of `./site/...` prefixed. Projects created with `accentcms init` use this layout directly.

## [0.11.0] - 2026-03-01

### Added

- **Init Starter Templates** (Feature f106, PR #265)
  - `sites/` collection where each subfolder is a self-contained starter template
  - Default "starter" template with home, blog, and events pages using a minimal "simple" theme
  - `--template <name>` flag to select any template from `sites/`
  - `--docs` flag to extract the full documentation site (port 4440)
  - `--list` flag to print available templates
  - Unknown template names show a helpful error with available options

### Changed

- **Config location**: Docs site config at `site-docs/config.yaml`
  - Docs site binds to port 4440 (per m005 port allocation spec)
  - Paths in docs config are relative to `site-docs/` directory
  - Use `cargo run -- serve --config site-docs/config.yaml` for docs development

### Fixed

- **Custom Error Pages with i18n** (Feature f105, PR #262)
  - Custom error page templates with language-aware rendering
  - CI skip for docs-only PRs (PR #261)

- **Debug Panel Upgrade** (Feature f104, PR #260)
  - Positioning, new sections, and security fixes

- Resolve all `cargo doc --no-deps` warnings (PR #266)

## [0.10.0] - 2026-02-27

### Added

- **Versioned Content** (Feature f100, PR #252)
  - Sparse folder versioning: version folders only contain changed pages, missing pages fall back to previous versions
  - Configurable versioning roots in `config.yaml` with version definitions, fallback chains, and deprecated version redirects
  - Fallback chains up to 5 levels deep with circular dependency detection at startup
  - `version` template context with current version, label, badge, all versions list, and fallback status
  - Version dropdown partial (`partials/version-dropdown.html.jinja`) for theme integration
  - Serve/build parity: same `expand_fallbacks()` code path in both modes
  - Deterministic root iteration via `BTreeMap` ordering

- **Frontmatter Redirects and Rewrites** (Feature f099, PR #251)
  - `redirect` frontmatter field for 301/302 redirects (string for 301, object with `url`/`code` for 302)
  - `rewrite` frontmatter field to serve another page's content at the current URL (transparent, 200 response)
  - External redirect targets supported
  - Static build generates meta-refresh HTML files for redirects
  - Redirect pages excluded from collections but visible in menus

- **Client-Side Search** (Feature f092, PR #232)
  - Search index generated at build time with configurable field weights (title, content, tags, lead)
  - Search UI with instant results, keyboard navigation, and highlight matching
  - Configurable exclusion patterns, minimum word length, and content length
  - Search form integrated into default theme header

- **JSON-LD Structured Data** (Feature f095, PR #241)
  - Auto-generated `<script type="application/ld+json">` for all pages
  - Schema.org types: `Article`, `BlogPosting`, `WebPage`
  - Warning on unrecognized schema.org enum values

- **Incremental Static Builds** (Feature f094, PR #239)
  - Content-hash-based change detection skips unchanged pages during `accentcms build`
  - Phase 1: per-page rebuild based on content and frontmatter changes

- **JSON REST API** (Feature f093, PR #234)
  - REST endpoints for querying pages, tags, hierarchy, and collections
  - Standard edition feature

- **Config-Driven Permalink Patterns** (Feature f097, PR #243)
  - `content.permalinks` maps URL prefixes to pattern strings with date and slug tokens
  - Tokens: `:year`, `:month`, `:day`, `:slug`, `:title`, `:section`
  - Automatic 301 redirects from original URLs to rewritten URLs
  - Frontmatter `slug` and `url` overrides

- **Default Theme Redesign** (Feature f096, PR #228)
  - Full Sass pipeline with dark mode toggle
  - Reusable template partials: breadcrumbs, TOC, page-nav, debug panel
  - Card-style previous/next navigation
  - Tag pill design across all pages
  - Dark mode readability fixes for code blocks and prose

- **Plugin Host Context** (Feature f025g, PR #226)
  - WASM plugins receive host runtime context (site config, request metadata)

- **CLI Query and Content Interface** (Features 088-091, PRs #212-#217)
  - Transport-agnostic query/content API layer (Feature f088)
  - Query CLI subcommands with output formatting (Feature f089)
  - Content mutation CLI: `update-frontmatter`, `create`, `move` (Feature f090)
  - Agent discovery docs command (Feature f091)

- **License Key Generator Tool** (`tools/license-gen/`, PR #235)
  - Standalone workspace member for Ed25519 keypair generation and JWT license creation
  - Pure Rust implementation (no OpenSSL dependency)

- **Multi-Platform CI** (Feature f072a, PR #219)
  - CI testing on Linux, macOS, and Windows

- **Installation Scripts** (Feature f072c, PR #221)
  - Shell installer for Linux/macOS, PowerShell installer for Windows

- **Pre-Commit Hook** (Feature f042, PR #222)
  - `prek` pre-commit hook configuration for code quality checks

- **Research Documents**
  - r034: Newsletter tool for Accent CMS
  - r035: Git-based publishing (GitHub to cloud)
  - r036: Static build deployment strategies

### Changed

- **Port Allocation Alignment** (Feature f098, PR #250)
  - Default HTTP port: 2525 -> 4400
  - Default serve-static port: 4443 -> 4403
  - DevDocs port: 3300 -> 4440
  - site-brand port: 3333 -> 4441
  - site-web port: 5555 -> 4442
  - Caddyfile.dev: 4443 -> 4403
  - **Migration**: Update any custom scripts or bookmarks referencing old ports

- CLI API moved to Standard edition (PR #245)

### Fixed

- Orphaned pages and broken link reporting in content validation (PR #244)
- Broken subtopic links in templating-guide, deployment, and integrations docs (PR #230)
- Parity tests updated to use test license key for `--production` mode (PR #225)
- Unused import warning on Windows in `signal.rs` (PR #224)

## [0.9.0] - 2026-02-23

### Added

- **Styling Support** (Feature f026, PR #210)
  - Sass/SCSS compilation via grass (pure Rust) -- `.scss` files compiled to CSS on request
  - Tailwind v4 utility CSS generation via encre-css -- scans templates for utility classes
  - Pure CSS icons from Iconify via encre-css-icons (100+ icon sets, no JavaScript)
  - Typography defaults for prose content via encre-css-typography
  - CSS post-processing via Lightning CSS -- minification, vendor prefixes, syntax lowering
  - Style cache with mtime-based invalidation (moka)
  - Hot reload for `.scss`/`.sass` file changes with `ChangeKind::Style` variant
  - Build command integration: compiles Sass, generates utilities, minifies CSS, rewrites `.scss` -> `.css`
  - Asset handler intercepts CSS requests through `StylePipeline`
  - Tailwind CDN option for rapid prototyping (browser-based JIT)
  - Feature-gated behind `styling` feature (enabled by default in `edition-standard`)
  - Styling documentation page and default theme updates (`prose` class, CDN conditional)

## [0.8.3] - 2026-02-22

### Added

- **Cargo Feature Flags and Edition Profiles** (Feature f078, PR #202)
  - Three edition profiles: `edition-core`, `edition-standard`, `edition-pro`
  - `plugins` feature flag gates the WASM plugin system (extism, toml, reqwest, sha2, semver, base64)
  - `media` feature flag gates image processing and media serving (image, imagesize, serde_urlencoded)
  - Default edition is `edition-standard` matching previous behavior

- **License Key Validation** (Feature f079, PR #203)
  - Ed25519-signed JWT license keys with organization, email, and expiration
  - Three license tiers: Unlicensed (Core), Standard, Pro
  - License loaded from `license.key` in `config.yaml` or `ACCENTCMS_LICENSE` environment variable
  - `--production` flag validates license at startup
  - Helpful error messages with edition comparison and upgrade instructions

- **Static Site Server** (Feature f084, PR #204)
  - `accentcms serve-static` command serves pre-built output via `tower-http::ServeDir`
  - Configurable directory (`--dir`), address, port, and `--open` flag for browser launch
  - Validates directory exists and contains files before starting

- **TLS Support for `serve` and `serve-static`** (Feature f084, PR #204)
  - `--tls` flag on both `serve` and `serve-static` enables HTTPS
  - Self-signed certificate generation for `localhost` and `127.0.0.1` (available on all editions)
  - Custom PEM certificate support via `--cert` and `--key` (requires Standard or Pro license)
  - Shared `tls` module with edition-gated certificate loading

- User documentation for `serve-static` and TLS in CLI reference, getting started, and deployment guides

### Changed

- **Compile Optimization and Module Structure** (Feature f083, PR #201)
  - Module-level `#[cfg(feature)]` gating for plugins and media modules
  - Core edition compiles without plugin or media dependencies
  - Streamlined module imports and conditional compilation across the codebase

## [0.8.0] - 2026-02-15

### Added

- **Multi-Language / i18n Content Support** (Feature f057, PR #140)
  - Filename-based language detection (`default.de.md`, `default.fr.md`)
  - URL-prefixed routing for non-default languages (`/de/home`, `/fr/home`)
  - Language switcher component in templates with active language indication
  - Per-page translation links connecting content across languages
  - `html lang` attribute set per page language
  - Sitemap `hreflang` alternate links for translated pages
  - Serve-mode routing for language-prefixed URLs
  - Deterministic page ordering for serve/build parity
  - Playwright i18n parity test suite (34 tests)

- **RSS Feed Generation** (Feature f068, PR #136)
  - `GET /feed.xml` serves RSS 2.0 feed from content index
  - Configurable feed limit, title, and description via `feed:` config section
  - Includes only dated pages, sorted by date descending
  - `accentcms build` generates static `feed.xml`

- **Sitemap, robots.txt, and .well-known Support** (Feature f069, PR #137)
  - `GET /sitemap.xml` with all page URLs and `lastmod` dates
  - `GET /robots.txt` with configurable rules and sitemap reference
  - `GET /.well-known/*` serving from `site/.well-known/` directory
  - Static generation of all three in `accentcms build`

- **Site Timestamps** (Feature f070, PR #138)
  - `site.last_modified` -- most recent content modification time
  - `site.built_at` -- build timestamp for static output
  - Sitemap `<lastmod>` uses per-page modification times

- **Digital Asset Management** (Features 066a-066d, PRs #126-#130)
  - Media serving foundation with MIME type detection and path traversal protection (066a)
  - Media index with `page.media` in templates and type-filtering functions (066b)
  - Image processing pipeline: on-demand resize, WebP conversion, responsive images, thumbnails (066c)
  - Video support with HTTP range requests, `video()` and `video_embed()` template functions (066d)

- **Arbitrary Content Directories** (Features 067a-067d, PRs #120-#124)
  - Recognize `README.md` and `index.md` as folder index files (067a)
  - Auto-derive page title from first `# heading` or filename (067b)
  - Fall back to `default.html.jinja` when derived template is missing (067c)
  - Stable alphabetical directory sort order across platforms (067d)

- **Plugin WASI Filesystem Access** (Feature f025f, PR #131)
  - Configurable filesystem access for WASM plugins via `allowed_paths`
  - Read-only and read-write path mappings in `config.yaml`

- **DevDocs Theme** (PR #133)
  - Theme for serving `specs/` directories as documentation websites
  - `devdocs.sh` convenience script for local docs serving on port 3300

- **Epic E003: Digital Asset Management** (PR #118) -- 5-phase feature spec
- **Epic E004: Arbitrary Content Directories** (PR #119) -- 4-phase feature spec
- **Epic E005: MCP Server** -- 4-phase epic covering MCP tools, resources, and prompts
- **Research: Islands Architecture** (r027, PR #139)
- **Research: AI Perspective on MCP Server** (r028, PR #141)

### Changed

- Image processing cleanup: trimmed features, unified `MediaQuery`, added dimension filters (PR #129)

### Fixed

- Bare markdown files in arbitrary content directories now resolve correctly (PR #132)

### Security

- `cargo audit`: No CVEs found. 3 unmaintained transitive dependency warnings (bincode, fxhash, yaml-rust -- all via syntect or wasmtime/extism, not directly addressable)

## [0.7.0] - 2026-02-12

### Added

- **Content Collections & Querying** (Feature f053, PR #110)
  - Frontmatter `content` block to define page collections with filtering and sorting
  - Pagination support with configurable page size and URL scheme (`/page:N`)
  - Collection items exposed as `page.collection` and pagination metadata as `page.pagination`

- **Taxonomy Index & Routing** (Feature f054, PR #112)
  - Tag-based taxonomy system with automatic tag indexing from frontmatter
  - Virtual routes `/tags` (tag index) and `/tags/{tag}` (per-tag listing)
  - `tags.html.jinja` and `tag.html.jinja` templates in default theme
  - `taxonomy` context available in all templates with tag counts

- **Content Relationships** (Feature f055, PR #115)
  - Named relationships between pages via frontmatter `relations` field
  - Supports arbitrary relationship types (series, related, prerequisites)
  - Resolved against `ContentIndex` with graceful handling of broken references

- **Content Validation System** (Feature f056, PR #113)
  - Validates frontmatter fields, template references, and content structure
  - Validation issues surfaced in debug panel (`?acdbg`) per page
  - `ValidationReport` tracks issues across the entire content index

- **Kubernetes Health Probes** (Feature f065, PR #116)
  - `GET /healthz` liveness probe - returns 200 if process is running
  - `GET /readyz` readiness probe - checks template engine, theme, and content directory
  - JSON responses with component-level status for debugging
  - Existing `/health` endpoint unchanged for backwards compatibility

- **Markdown Event Processing Pipeline** (Feature f061, PR #103)
  - Extensible `EventProcessor` trait for markdown transformation stages
  - Decouples TOC generation and syntax highlighting from core renderer

- **Table of Contents Generation** (Feature f048, PR #104)
  - Automatic TOC extraction from markdown headings via `TocProcessor`
  - Exposed as `page.toc` in template context with nested heading structure

- **Syntax Highlighting** (Feature f051, PR #105)
  - Server-side code block highlighting via `SyntaxHighlightProcessor` (syntect)
  - Configurable color theme via `code.theme` in config.yaml

- **Previous/Next Navigation** (Feature f052, PR #102)
  - `page.prev` and `page.next` in template context for sequential navigation
  - Based on sibling order within the same parent

- **Page Metadata Enrichment** (Feature f050, PR #101)
  - `page.word_count`, `page.reading_time`, `page.modified_date` in templates
  - Automatic calculation from content with no frontmatter changes needed

- **Auto-Excerpt Generation** (Feature f049, PR #100)
  - Automatic excerpt from first paragraph when frontmatter `lead` is omitted
  - Available as `page.content` summary in collection listings

- **Playwright HTTP Performance Tests** (Feature f063, PR #108)
  - End-to-end performance tests for all content pages in dev and production modes
  - Response time assertions and status code validation

- **Build Paginated Output** (PR #111)
  - Static site generator now renders paginated pages (`/page:2`, `/page:3`, etc.)
  - Playwright parity tests verify serve vs build output match

- **Local Benchmark Collection Script** (PR #106)
  - Script to collect and store benchmark baselines locally

### Changed

- **Content Model Tier 1** (PR #98)
  - Custom frontmatter fields passed through to templates via `page.custom`
  - Typed date handling with proper formatting support (Feature f047)
  - Removed dead `html_content` field from `Page` struct (Feature f046)

- Accent CMS version context exposed to templates as `{{ accentcms.version }}` (PR #97)
- Site template footer updated with Accent CMS branding
- `toml` dependency updated 1.0.0 -> 1.0.1

### Fixed

- **Root URL parity between serve and build modes** (PR #114) - Root path `/` now resolves consistently in both modes
- **Dev mode render performance** (Feature f062, PR #107) - Optimized syntect in debug profile to eliminate multi-second render times
- **Rustdoc warnings** (PR #109) - Resolved all documentation warnings in `cargo doc --no-deps`
- Removed redundant `cargo bench --no-run` from CI (PR #99)

## [0.6.0] - 2026-02-11

### Added

- **Plugin Runtime & Registry** (Feature f025a, PR #81)
  - WebAssembly plugin system powered by Extism
  - Plugin manifest format (`plugin.toml`) with metadata and hook declarations
  - `PluginRegistry` for loading, validating, and managing plugins from a directory
  - Thread-safe `PluginEntry` with interior locking for concurrent access

- **Content Hooks Executor** (Feature f025b, PR #82)
  - Hook execution pipeline: `before_render`, `after_render`, `on_page_load`
  - JSON-based data exchange between host and WASM plugins
  - Priority-ordered hook execution across multiple plugins
  - Graceful error handling: failing plugins log warnings without crashing the server

- **Plugin Filters, Routes & Hot Reload** (Feature f025c, PR #86)
  - Template filter plugins for custom Jinja2 filters (e.g., `{{ text | uppercase }}`)
  - Route handler plugins for custom HTTP endpoints (e.g., `/api/search`)
  - Hot reload support: plugins reload automatically when `.wasm` files change
  - Filter and route declarations in `plugin.toml` manifest

- **Plugin CLI & Distribution** (Feature f025d, PR #87)
  - `accentcms plugin list` - list installed plugins with status
  - `accentcms plugin info <name>` - show plugin details and hooks
  - `accentcms plugin install <name>` - install from remote registry with SHA-256 verification
  - `accentcms plugin remove <name>` - uninstall plugins
  - Configurable registry URL in `config.yaml`

- **Plugin Security Hardening** (Feature f025e, PR #89)
  - Fuel limits for CPU-bound execution control per plugin call
  - Wasmtime compilation caching for faster plugin startup
  - AOT pre-compilation support for production deployments
  - Host API version checking with semver compatibility
  - Fuel consumption logging at debug level for tuning
  - All security features opt-in with backward-compatible defaults

- **Agent Development Skills** (PRs #83, #84, #90)
  - `cargo-doc-md` skill for local crate documentation lookup
  - `dep-upgrade` skill for safe, one-at-a-time dependency upgrades

### Changed

- **Dependency Upgrades** (PRs #91, #92, #93)
  - `pulldown-cmark` 0.12 -> 0.13 (superscript, subscript, wikilinks support)
  - `gray_matter` 0.2 -> 0.3 (generic parse API, direct deserialization)
  - `criterion` 0.5 -> 0.8 (updated benchmark framework)
  - `axum-test` 16 -> 18 (tracks axum 0.8, removes duplicate axum 0.7)
  - `reqwest` 0.12 -> 0.13 (rustls as default TLS backend)
  - `toml` 0.8 -> 1.0 (semver stabilization)
  - All patch/minor dependencies updated to latest compatible versions
- Rust edition upgraded from 2021 to 2024

## [0.5.0] - 2026-02-10

### Added

- **Static Site Generator** (Feature f030, PRs #77, #78)
  - `accentcms build` command pre-renders all pages to static HTML
  - Reuses existing rendering pipeline for output identical to `accentcms serve`
  - Copies theme assets preserving directory structure
  - Generates `sitemap.xml` when base URL is configured
  - Supports `--clean`, `--output`, `--base-url` flags

### Fixed

- **Dynamic asset serving for SIGHUP theme switching** (#75) - Replaced static `ServeDir` with dynamic handler so CSS loads correctly after theme switch via SIGHUP
- **Missing blog.html.jinja in 4 themes** (#76) - Added blog template to cinder, dark, pico, simple themes

### Performance

- **Asset serving optimization** (#79) - Replaced `canonicalize()` syscall with path component validation, reducing asset_request latency by 46%

## [0.4.0] - 2026-02-10

### Added

- **Site Unified Folder Structure** (Feature f021)
  - Moved `content/` and `themes/` under `site/` directory for clean separation of website files from source code
  - New `--site-dir` CLI option to relocate the entire site directory
  - `--content-dir` and `--theme-dir` can partially override `--site-dir`
  - Default paths changed: `./site-docs/content` and `./site/themes`
  - `accentcms init` now creates site structure under `site/`

- **PageHierarchy Shared Interface** (Feature f041)
  - Extracted `PageHierarchy` struct for reusable hierarchy resolution
  - Shared between serve handler and future build command (Feature f030)
  - Resolves parent, children, siblings, and breadcrumbs from `HierarchyIndex`

- **Cinder Theme**
  - New Bootstrap-based theme with navbar, responsive layout, and syntax highlighting

- **Breadcrumb Navigation in All Templates**
  - Added `page.breadcrumbs` navigation to `default.html.jinja` and `blog.html.jinja` across all 6 themes
  - Each theme uses its own markup conventions (Bootstrap breadcrumb, Pico small text, etc.)

- **Documentation Templates for All Themes**
  - Added `docs.html.jinja` to cinder, dark, pico, simple, and skeleton themes
  - Includes breadcrumbs, parent link, children listing, siblings navigation, and debug panel

- **Beads Issue Tracking**
  - Integrated `bd` issue tracking for feature specs and bugs
  - All feature specs tracked as beads with cross-references

### Fixed

- **SIGHUP Config Reload** - `dev.debug` and other config values now update for request handlers after SIGHUP reload. Previously `AppState.config` was immutable `Arc<Config>`; changed to `Arc<RwLock<Config>>`.
- **Cache Benchmark Stability** - Bounded insert benchmark key set to 100 entries instead of unbounded growth, producing stable measurements.

## [0.3.1] - 2026-02-09

### Changed

- Added CI, benchmarks, Rust, and benchmark dashboard badges to README

## [0.3.0] - 2026-02-09

### Added

- **Constants Module** (Feature f030)
  - Centralized path and route string constants to prevent typos
  - `paths::DEFAULT_TEMPLATE`, `THEME_CONFIG`, `TEMPLATES_DIR`, `ASSETS_DIR`
  - `routes::DEV_RELOAD`, `THEME_ASSETS_PREFIX`, `HEALTH`, `CATCH_ALL`

- **Extension Points / Dev Feature Trait System** (Feature f037)
  - Pluggable `DevFeature` trait for development-time features
  - `DevFeatureRegistry` for registering, resolving dependencies, and activating features
  - Built-in `BrowserReloadFeature` and `HotReloadFeature` implementations
  - Extension points architecture documentation (`specs/implementation/m000-extension-points.md`)

- **Hot Reload Integration Tests** (Feature f035)
  - 11 integration tests covering cache invalidation, theme reload, and concurrent access
  - Tests for content index caching and invalidation

- **Continuous Benchmarking** (Feature f031)
  - GitHub Actions workflow runs all 5 Criterion benchmark suites on every PR
  - Compares against baseline stored in `gh-pages` branch
  - Alerts and fails PRs with >30% regressions
  - Local benchmark storage workflow documented in README

- **Content Index Caching** (Feature f027)
  - Cached content index with invalidation support
  - Hierarchy pre-computation for parent/child/sibling relationships (Feature f028)

- **Memory-Based Cache Limits** (Feature f029)
  - Cache entries tracked by weighted size
  - Configurable memory limits with eviction

- Feature specifications for features 025-040

### Changed

- Upgraded `notify` 7.0.0 -> 8.2.0 (removes unmaintained `instant` crate)
- Path traversal protection hardened with canonical path validation and URL decoding (Feature f032)
- Lock scopes minimized in `build_context` for better concurrency (Feature f031)
- Config path validation added for theme and content directories (Feature f033)
- `#[must_use]` attributes added to key return types (Feature f038)
- Improved `Option` handling patterns (Feature f039)

### Fixed

- Patched `bytes` 1.11.0 -> 1.11.1 (RUSTSEC-2026-0007: integer overflow in `BytesMut::reserve`)
- Patched `time` 0.3.44 -> 0.3.47 (RUSTSEC-2026-0009: DoS via stack exhaustion)
- Removed unmaintained `instant` crate (RUSTSEC-2024-0384) by upgrading `notify`

### Security

- RUSTSEC-2026-0007: `bytes` integer overflow - patched
- RUSTSEC-2026-0009: `time` stack exhaustion - patched
- RUSTSEC-2024-0384: `instant` unmaintained - removed from dependency tree
- Path traversal hardening with URL-decode and canonical path checks

## [0.2.6] - 2026-02-03

### Added

- **Debug Query Parameter** (Feature f024)
  - Add `?acdbg` to any page URL to display a debug panel
  - Shows all template context values: site, page, theme, pages, all_pages, dev
  - Syntax-highlighted JSON display with collapsible sections
  - Panel title shows current page URL path
  - Only appears in dev mode (when `dev.browser_reload: true`)
  - Silently ignored in production mode
  - Useful for understanding available template data and debugging

### Changed

- Added rule 15 to claude.md: update `content/main/` documentation when features change
- Updated Getting Started guide with debug panel documentation
- Updated Templating Guide with `?acdbg` quick reference

## [0.2.5] - 2026-02-03

### Added

- **Debug Flag** (Feature f022)
  - New `dev.debug` config option (default: false)
  - `DevContext` exposed to templates with `debug`, `hot_reload`, `browser_reload` flags
  - Templates can use `{% if dev.debug %}` for conditional debug output

- **Hierarchical Page Tree** (Feature f023)
  - `page.parent` - parent page metadata (or none for root)
  - `page.children` - direct child pages sorted by menu.order
  - `page.siblings` - sibling pages with same parent
  - `page.breadcrumbs` - ancestors from root to parent for navigation
  - Hierarchy derived from URL structure, no content changes needed

### Changed

- Updated templating guide documentation with new dev context and page hierarchy features
- Added literate programming rules to CLAUDE.md (rules 12-13)
- Added comprehensive Rust doc comments to config, template, and handler modules

## [0.2.4] - 2026-01-25

### Added

- **Dev Mode Styled Error Pages** (Feature f019)
  - Detailed, styled HTML error pages in development mode
  - Error type classification (Template Error, Page Not Found, Invalid Frontmatter, etc.)
  - Full error context with line numbers for MiniJinja template errors
  - Dark-themed styling matching developer tools aesthetic
  - Production mode continues to show minimal generic messages
  - New `ErrorResponse` wrapper for carrying dev mode context through error handling

### Fixed

- **Hot Reload Latency** (PR #41)
  - Reduced worst-case hot reload latency from ~200ms to ~75ms
  - Decreased poll watcher interval from 100ms to 50ms
  - Decreased hot reload task poll from 100ms to 25ms

## [0.2.3] - 2026-01-25

### Fixed

- **Dev Mode Request Blocking** (Feature f020)
  - Fixed HTTP/1.1 connection exhaustion causing ~54 second request blocking after 6+ navigations
  - SSE connections now properly close on page navigation via `beforeunload`/`pagehide` events
  - Fixed `Content-Length` header mismatch after hot reload script injection

## [0.2.2] - 2026-01-25

### Added

- **Template Functions** (Feature f019)
  - `now()` function returns current datetime object
  - Access date parts: `{{ now().year }}`, `{{ now().month }}`, `{{ now().day }}`
  - Access time parts: `{{ now().hour }}`, `{{ now().minute }}`, `{{ now().second }}`
  - `debug(value)` function for template debugging
- New `chrono` dependency for datetime handling

## [0.2.1] - 2026-01-25

### Added

- **Production Mode Flag** (Feature f018)
  - New `--production` flag disables all dev features
  - Dev mode is now the default (`accentcms serve` enables hot reload)
  - Simpler CLI: just use `--production` for deployments

### Changed

- Dev mode is now the default when running `accentcms serve`
  - `hot_reload: true` by default
  - `browser_reload: true` by default
- Removed `--hot-reload` and `--no-hot-reload` flags (replaced by `--production`)
- Updated documentation in `content/main/` to reflect new CLI

### Fixed

- **Conditional Dev Endpoints** (Feature f017)
  - `/_dev/reload` SSE endpoint now only registered when `browser_reload` is enabled
  - Reload script no longer injected in production mode
  - Reduced memory usage in production (no `DevReloadState` allocation)

## [0.2.0] - 2026-01-25

### Added

- **Project Initialization Command** (Feature f016)
  - New `accentcms init [PATH]` command creates a complete starter project
  - Extracts default config, theme, and demo content
  - Single-binary distribution - all resources embedded at compile time
  - Skips existing files with warning (safe to run multiple times)
  - Creates nested directories automatically
  - Suggests `accentcms init` when config or theme is missing
- New `commands` module with `InitCommand` and `ServeCommand`
- New `include_dir` dependency for compile-time file embedding

### Changed

- **Breaking**: CLI restructured to use subcommands
  - Old: `accentcms [OPTIONS]`
  - New: `accentcms serve [OPTIONS]` or `accentcms init [PATH]`
- Server logic moved from `main.rs` to `commands/serve.rs`
- `main.rs` simplified to CLI parsing and command dispatch

## [0.1.2] - 2026-01-19

### Added

- **CLI Arguments and Version Information** (Feature f015)
  - Command line argument parsing with `clap`
  - `--version` shows version with git commit hash (e.g., `0.1.2 (abc1234)`)
  - `--help` displays all available options
  - `--config` / `-c` to specify config file path
  - `--content-dir` to override content directory
  - `--theme-dir` to override themes directory
  - `--theme` to override theme name
  - `--address` to override server address
  - `--port` / `-p` to override server port
  - `--hot-reload` / `--no-hot-reload` to toggle hot reload
  - CLI arguments take precedence over `config.yaml` values
  - Startup banner shows full build info (version, git hash, build time, target)
- **Dark Theme**
  - New `themes/dark` with GitHub-inspired dark color scheme
  - CSS custom properties for easy customization
  - Usage: `accentcms --theme dark`
- **Test Content Directory**
  - Separate test content at `./content/test`
  - Usage: `accentcms --content-dir ./content/test`
- **Signal-Based Configuration Reload** (Feature f014)
  - Send SIGHUP to reload `config.yaml` without restarting the server
  - Dynamically enable/disable hot reload at runtime
  - Theme and template engine are reloaded on config change
  - All caches are cleared on reload
  - Connected browsers are notified to refresh
  - Unix platforms only (Linux, macOS)
  - Usage: `pkill -HUP accentcms`
- **Browser Hot Reload** (Feature f013)
  - Automatic browser refresh when theme or content files change
  - Server-Sent Events (SSE) endpoint at `/_dev/reload`
  - CSS changes trigger hot-swap without full page reload
  - Clean shutdown handling for SSE connections
  - Enable with `dev.browser_reload: true` in `config.yaml`
- **Theme Hot Reload** (Feature f012)
  - File watcher monitors `./themes` and `./content` directories
  - Template changes automatically reload the template engine
  - `theme.yaml` changes trigger full theme reload
  - Content changes invalidate the page cache
  - Asset changes are served fresh immediately
  - Enable with `dev.hot_reload: true` in `config.yaml`
  - Configurable debounce delay (`dev.debounce_ms`, default: 100ms)
- New `cli` module for command line argument parsing
- New `signal` module for Unix signal handling
- New `watcher` module for cross-platform file system watching
- New `dev_reload` module for browser SSE communication
- New `DevConfig` configuration section for development settings
- New `build.rs` script for capturing git hash and build timestamp
- `WatcherInit` and `ThemeReload` error variants

### Changed

- `AppState` now wraps `Theme` and `TemplateEngine` in `RwLock` to support hot reload
- `AppState.reload_config()` method for runtime configuration reload
- `AppState.reload_templates()` method for template-only reload
- `Config.apply_overrides()` method for applying CLI argument overrides
- Handlers updated to use async read locks for theme access
- Version constants (`VERSION`, `GIT_HASH`, `BUILD_TIME`, `BUILD_TARGET`) exported from lib.rs
- Default content directory changed from `./content` to `./content/main`

### Fixed

- Faster Ctrl+C shutdown - SSE streams now close immediately instead of waiting for keep-alive timeout
