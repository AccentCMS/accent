# Accent CMS

Accent CMS is a high-performance markdown CMS in a single binary, written in
Rust. It serves markdown files as HTML with on-the-fly rendering, caching,
Jinja-style templating, WASM plugins, image processing, client-side search,
diagrams, and an admin authoring UI.

This repository is the official download location for Accent CMS release
binaries. Product information, documentation, and pricing live at
[accentcms.dev](https://accentcms.dev).

## Install

One binary per platform: every download contains the full feature set, and
your license key decides which tier is unlocked at runtime. Building a site
(`accent build`) and the development server (`accent serve`) are free and
need no license key at all.

### Linux and macOS

```bash
curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh
```

Re-running the installer when Accent CMS is already current reports
"Already up to date" and changes nothing. To reinstall or update in place,
pass force -- note that in the piped form, flags must go to `sh`, not to
`curl` (a flag placed after the URL is consumed by curl):

```bash
curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh -s -- --force
# or, using the environment-variable form:
curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | ACCENT_FORCE=1 sh
```

To install a specific version, use `--version v0.23.1` (via `sh -s --`) or
`ACCENT_VERSION=v0.23.1`; the `v` prefix is optional.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex
```

Re-running the installer when Accent CMS is already current reports
"Already up to date" and changes nothing. The piped form cannot receive
parameters at all, so the installer honors environment variables set in
the same session before the pipe:

```powershell
# Reinstall or update in place
$env:ACCENT_FORCE = "1"; irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex

# Install a specific version (the v prefix is optional)
$env:ACCENT_VERSION = "v0.23.1"; irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex
```

`$env:ACCENT_FORCE` stays set for the rest of the session;
`Remove-Item Env:ACCENT_FORCE` clears it. Any value other than empty or
`"0"` counts as force. The parameterized form is also available, and an
explicit parameter always wins over its environment variable:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1))) -Version v0.23.1 -Force
```

### Manual download

Grab the archive for your platform from the
[latest release](https://github.com/AccentCMS/accent/releases/latest):

| Platform | Archive |
|---|---|
| Linux x86_64 | `accent-<version>-x86_64-unknown-linux-gnu.tar.gz` |
| Linux ARM64 | `accent-<version>-aarch64-unknown-linux-gnu.tar.gz` |
| macOS Intel | `accent-<version>-x86_64-apple-darwin.tar.gz` |
| macOS Apple Silicon | `accent-<version>-aarch64-apple-darwin.tar.gz` |
| Windows x86_64 | `accent-<version>-x86_64-pc-windows-msvc.zip` |
| Windows ARM64 | `accent-<version>-aarch64-pc-windows-msvc.zip` |

Stable URLs for automation follow the pattern:

```
https://github.com/AccentCMS/accent/releases/latest/download/<asset-name>
```

## Verifying your download

Every release ships a `checksums-<version>.txt` covering all archives, plus
a detached GPG signature `checksums-<version>.txt.asc` made with the Accent
CMS release signing key ([`release-signing-key.asc`](release-signing-key.asc)
in this repository).

```bash
# 0. One-time: import the release signing key
curl -fsSLO https://raw.githubusercontent.com/AccentCMS/accent/main/release-signing-key.asc
gpg --import release-signing-key.asc

# 1. Verify the signature on the checksums file
gpg --verify checksums-<version>.txt.asc checksums-<version>.txt

# 2. Verify the downloaded archive against the checksums
sha256sum -c --ignore-missing checksums-<version>.txt
```

The Linux/macOS install script performs both steps automatically when `gpg`
is on your PATH, and always verifies the SHA-256 checksum.

### Publication attestation

On every release, a workflow in this repository re-runs the verification
above and records a signed attestation in the Sigstore transparency log.
This is a **publication** attestation -- it proves the exact bytes were
published here and passed signature verification, with the GPG signature as
the primary trust root (builds happen in a private repository, so build
provenance is not attested). Verify with the GitHub CLI:

```bash
gh attestation verify accent-<version>-<target>.tar.gz --repo AccentCMS/accent
```

## Editions and licensing

The binary is the same for everyone; a license key unlocks paid tiers at
runtime. Keys are verified offline (Ed25519-signed) -- the binary never
phones home.

| Capability | Free (no key) | Core+ | Standard | Pro |
|---|:---:|:---:|:---:|:---:|
| `accent serve` (development) | yes | yes | yes | yes |
| `accent build` (static output) | yes | yes | yes | yes |
| Plugins, media, search, styling, diagrams | yes | yes | yes | yes |
| Admin authoring UI (`/_admin/`) | -- | yes | yes | yes |
| `accent serve --production` | -- | -- | yes | yes |
| Custom TLS certificates | -- | -- | yes | yes |
| MCP server + CDN integration | -- | -- | -- | yes |

See [accentcms.dev](https://accentcms.dev) for pricing and license terms.

## Getting started

```bash
# Create a new site
accent init my-site
cd my-site

# Start the development server (free, no key needed)
accent serve

# Build a static site
accent build
```

Full documentation: [accentcms.dev](https://accentcms.dev).

## Support

- Questions and help: [Discussions](https://github.com/AccentCMS/accent/discussions)
- Product and licensing: [accentcms.dev](https://accentcms.dev)

## License

The binaries distributed here are proprietary software; see
[LICENSE](LICENSE). Free tiers may be used per the published pricing terms.
