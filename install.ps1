# Accent CMS installer for Windows.
#
# Usage:
#   irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex
#
# The piped form above cannot receive parameters at all (there is no
# parameter binding on a piped script body), so the installer honors
# environment-variable equivalents, set in the same session before the
# pipe:
#   $env:ACCENT_VERSION = "v0.22.0"   # same as -Version; the v prefix is optional
#   $env:ACCENT_FORCE   = "1"         # same as -Force; any value except empty or "0"
#   irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex
#
# Or with parameters (an explicit parameter always wins over its env var):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1))) -Version v0.22.0 -Force
#
# There is one binary per platform: every download contains the full
# feature set, and your license key decides which tier is unlocked at
# runtime. Releases before v0.22.0 were never published here.
#
# Failure style: this script uses `throw`, never `exit`. Under the
# documented `irm | iex` invocation there is no script frame on the call
# stack, so `exit` would terminate the user's whole PowerShell session;
# `throw` stops the installer and returns to the prompt. The successful
# already-up-to-date short-circuit is likewise a plain conditional in the
# main flow rather than an early `exit 0`.

param(
    [string]$Version = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Repo = "AccentCMS/accent"
$InstallDir = Join-Path $env:LOCALAPPDATA "accent"

# Env-var equivalents of -Version / -Force, applied only when the
# corresponding parameter was not explicitly bound, so an explicit
# parameter always wins (matching install.sh, where CLI flags override
# ACCENT_VERSION / ACCENT_FORCE). Any ACCENT_FORCE value other than
# empty or "0" behaves like -Force.
if (-not $PSBoundParameters.ContainsKey('Version') -and $env:ACCENT_VERSION) {
    $Version = $env:ACCENT_VERSION
}
if (-not $PSBoundParameters.ContainsKey('Force') -and $env:ACCENT_FORCE -and $env:ACCENT_FORCE -ne '0') {
    $Force = $true
}

# Whether to render a progress bar for the archive download (the one
# multi-megabyte transfer in this script; the metadata fetches below are
# a few KB and stay silent regardless). Mirrors install.sh's `[ -t 2 ]`
# check: when stderr is redirected (CI logs, captured output) a progress
# bar is just noise.
$ShowProgress = $true
try {
    if ([Console]::IsErrorRedirected) { $ShowProgress = $false }
} catch {
    $ShowProgress = $false
}

# --- Download helper ---
#
# Invoke-WebRequest renders its default progress stream only when
# $ProgressPreference says so; a function-local preference variable is
# honored by cmdlets called from that scope, so no global state is
# touched. Progress is opt-in per download and additionally gated on
# $ShowProgress (interactive stderr).

function Invoke-Download {
    param(
        [string]$Uri,
        [string]$OutFile,
        [switch]$WithProgress
    )
    # $ShowProgress resolves via dynamic scoping to the top-level
    # assignment (a $script: read would miss it under the parameterized
    # scriptblock invocation, where top-level variables are scriptblock-
    # local, not script-scoped).
    if ($WithProgress -and $ShowProgress) {
        $ProgressPreference = "Continue"
    } else {
        $ProgressPreference = "SilentlyContinue"
    }
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
}

# --- Platform detection ---

function Detect-Platform {
    $arch = $env:PROCESSOR_ARCHITECTURE
    switch ($arch) {
        "AMD64" {
            $script:TargetArch = "x86_64"
            $script:Target = "x86_64-pc-windows-msvc"
        }
        "ARM64" {
            $script:TargetArch = "aarch64"
            $script:Target = "aarch64-pc-windows-msvc"
        }
        default {
            throw "Unsupported architecture: $arch. Accent CMS supports AMD64 and ARM64."
        }
    }
    Write-Host "Detected platform: Windows $script:TargetArch ($script:Target)"
}

# --- Version resolution ---
#
# Resolves the latest tag from the releases/latest redirect instead of the
# GitHub API: the redirect target ends in /tag/<version>, and this path is
# not subject to the unauthenticated API rate limit.
#
# Returns the resolved version rather than assigning $script:Version: under
# the parameterized `& ([scriptblock]::Create(...))` invocation the
# scriptblock's parameter scope sits between function scopes and the
# global scope, so a $script: write would land in a different variable
# than later reads resolve to. An explicit return assigned in the main
# flow stays correct under all three documented invocation forms (file,
# piped iex, parameterized scriptblock).

function Resolve-Version {
    param([string]$Requested)

    if ($Requested) {
        # Accept the tag with or without its v prefix (-Version 0.23.1 and
        # -Version v0.23.1 are both natural spellings). Release tags always
        # carry the v, so normalize once here; this keeps the download URL
        # and the up-to-date comparison in Check-Existing consistent for
        # either spelling.
        if ($Requested -cnotmatch '^v') {
            $Requested = "v$Requested"
        }
        Write-Host "Installing version: $Requested"
        return $Requested
    }

    Write-Host "Fetching latest version..."
    $resolved = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create("https://github.com/$Repo/releases/latest")
        $request.AllowAutoRedirect = $false
        try {
            $response = $request.GetResponse()
        } catch [System.Net.WebException] {
            # .NET (Core) surfaces the 3xx as a WebException when
            # AllowAutoRedirect is off; the redirect response still rides
            # on the exception. .NET Framework returns it directly above.
            $response = $_.Exception.Response
            if (-not $response) { throw }
        }
        $location = $response.Headers["Location"]
        $response.Close()
        if ($location -and $location -match "/tag/(.+)$") {
            $resolved = $Matches[1]
        }
    } catch {
        throw "Could not determine latest version. There may be no published release yet, or the network request failed. Check https://github.com/$Repo/releases or specify a version with -Version."
    }

    if (-not $resolved) {
        throw "Could not determine latest version. There may be no published release yet. Check https://github.com/$Repo/releases or specify a version with -Version."
    }

    Write-Host "Latest version: $resolved"
    return $resolved
}

# --- Check existing installation ---
#
# Runs after Resolve-Version, so $Version is already the resolved target
# (explicit -Version / $env:ACCENT_VERSION, or the latest tag). That lets
# the up-to-date check below compare against it directly instead of
# re-resolving. Returns $true when the install is already current and the
# main flow should stop (successfully); $false when installation should
# proceed.

function Check-Existing {
    $binary = Join-Path $InstallDir "accent.exe"
    if (-not (Test-Path $binary)) { return $false }
    if ($Force) { return $false }

    # Stderr is discarded, not merged: PowerShell's 2>&1 interleaves the
    # streams in nondeterministic order, so any stderr chatter during
    # --version could displace the version token parsed below. install.sh
    # does the same (2>/dev/null with an "unknown" fallback).
    $existing = ""
    try {
        $existing = ((& $binary --version 2>$null) -join ' ').Trim()
    } catch {
        $existing = ""
    }
    if ($existing) {
        Write-Host "Accent CMS is already installed: $existing"
    } else {
        $existing = "unknown"
        Write-Host "Accent CMS is already installed at: $binary"
    }

    # `accent --version` prints "accent X.Y.Z ..."; the second token is the
    # bare version number (same field install.sh takes with awk).
    $existingNumber = ""
    $parts = $existing -split '\s+'
    if ($parts.Count -ge 2) { $existingNumber = $parts[1] }

    if ($existingNumber -and ("v$existingNumber" -ceq $Version)) {
        Write-Host "Already up to date ($Version)."
        # A correct file at $InstallDir\accent.exe is not the whole story:
        # the shell resolves accent by PATH order, and a stale binary
        # earlier in PATH silently wins (the b117 incident was exactly
        # this, and a cheerful "up to date" would be a false success
        # signal there). Run the same PATH checks a real install ends
        # with before stopping.
        Check-Path
        Check-Shadowing
        return $true
    }

    Write-Host "To reinstall or update in place, re-run with force:"
    Write-Host '  $env:ACCENT_FORCE = "1"; irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex'
    Write-Host "or, with parameters:"
    Write-Host "  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1))) -Force"
    Write-Host "Or remove it first:"
    Write-Host "  Remove-Item `"$InstallDir`" -Recurse"
    throw "Accent CMS is already installed (re-run with -Force or `$env:ACCENT_FORCE=1 to overwrite)."
}

# --- Download and verify ---

function Download-And-Install {
    $archiveName = "accent-${Version}-${Target}.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$Version/$archiveName"
    $checksumsUrl = "https://github.com/$Repo/releases/download/$Version/checksums-${Version}.txt"

    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "accent-install-$([System.Guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

    try {
        Write-Host "Downloading $archiveName..."
        try {
            Invoke-Download -Uri $downloadUrl -OutFile (Join-Path $tmpDir $archiveName) -WithProgress
        } catch {
            throw "Download failed. URL: $downloadUrl`nCheck that the version exists (only v0.22.0 and later are published here): https://github.com/$Repo/releases"
        }

        # Verify checksum. Only the network fetch lives inside try/catch --
        # the comparison itself runs outside it, so a hash mismatch can
        # never be swallowed by the could-not-download fallback and always
        # aborts the install.
        Write-Host "Downloading checksums..."
        $checksumsPath = Join-Path $tmpDir "checksums.txt"
        $checksumsDownloaded = $false
        try {
            Invoke-Download -Uri $checksumsUrl -OutFile $checksumsPath
            $checksumsDownloaded = $true
        } catch {
            Write-Host "Warning: Could not download checksums. Skipping verification."
        }

        if ($checksumsDownloaded) {
            Write-Host "Verifying checksum..."
            $checksumLines = Get-Content $checksumsPath
            $expectedLine = $checksumLines | Where-Object { $_ -match [regex]::Escape($archiveName) }

            if ($expectedLine) {
                $expected = ($expectedLine -split '\s+')[0]
                $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $tmpDir $archiveName)).Hash.ToLower()

                if ($expected -ne $actual) {
                    throw "Checksum verification failed! Expected: $expected Actual: $actual -- the downloaded file may be corrupted or tampered with. Do not use it."
                }
                Write-Host "Checksum verified."
            } else {
                Write-Host "Warning: Archive not found in checksums file. Skipping verification."
            }
        }

        # The checksums file also carries a detached GPG signature
        # (checksums-<version>.txt.asc). PowerShell has no built-in OpenPGP
        # support, so signature verification is documented in the README for
        # users with Gpg4win installed rather than performed here.

        # Extract and install
        Write-Host "Extracting..."
        $extractDir = Join-Path $tmpDir "extracted"
        Expand-Archive -Path (Join-Path $tmpDir $archiveName) -DestinationPath $extractDir -Force

        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        Copy-Item (Join-Path $extractDir "accent.exe") -Destination (Join-Path $InstallDir "accent.exe") -Force

        Write-Host "Installed accent.exe to $InstallDir"

    } finally {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}

# --- PATH check ---

function Check-Path {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$InstallDir*") {
        Write-Host ""
        Write-Host "Note: $InstallDir is not on your PATH."
        Write-Host "To add it, run:"
        Write-Host ""
        Write-Host "  `$path = [Environment]::GetEnvironmentVariable('Path', 'User')"
        Write-Host "  [Environment]::SetEnvironmentVariable('Path', `"`$path;$InstallDir`", 'User')"
        Write-Host ""
        Write-Host "Then restart your terminal."
    }
}

# --- Shadowing check ---
#
# The user's shell resolves `accent` by PATH order, not by what this
# installer just wrote. A stale accent.exe earlier in PATH -- a
# cargo-installed one under %USERPROFILE%\.cargo\bin is the common case
# -- silently shadows the fresh install, and `accent --version` keeps
# reporting the old build while the user believes they upgraded. Surface
# the mismatch with both paths and versions whenever this script asserts
# the install dir holds the right binary -- after a fresh install, and
# equally on the "already up to date" path, where a cheerful success
# message would otherwise hide exactly this drift.

function Check-Shadowing {
    $installed = Join-Path $InstallDir "accent.exe"
    $resolved = $null
    try {
        $resolved = (Get-Command accent -CommandType Application -ErrorAction Stop |
            Select-Object -First 1).Source
    } catch {
        return
    }
    if (-not $resolved) { return }

    try {
        $resolvedFull = [System.IO.Path]::GetFullPath($resolved)
        $installedFull = [System.IO.Path]::GetFullPath($installed)
    } catch {
        $resolvedFull = $resolved
        $installedFull = $installed
    }
    # Windows paths are case-insensitive; -ieq makes that explicit.
    if ($resolvedFull -ieq $installedFull) { return }

    # 2>$null, not 2>&1: keep stderr out of the displayed version (see
    # the same choice in Check-Existing).
    $shadowVersion = "unknown version"
    try {
        $shadowVersion = ((& $resolved --version 2>$null) -join ' ').Trim()
        if (-not $shadowVersion) { $shadowVersion = "unknown version" }
    } catch {
        $shadowVersion = "unknown version"
    }

    Write-Host ""
    Write-Host "Warning: 'accent' currently resolves to a different binary:"
    Write-Host "  $resolved ($shadowVersion)"
    Write-Host "which shadows the up-to-date binary at $installed."
    Write-Host "Remove the shadowing binary or move $InstallDir earlier in your"
    Write-Host "PATH, then start a new terminal."
}

# --- Main ---

Write-Host "Accent CMS Installer"
Write-Host "==================="
Write-Host ""

Detect-Platform
$Version = Resolve-Version $Version

if (-not (Check-Existing)) {
    Download-And-Install
    Check-Path
    Check-Shadowing

    Write-Host ""
    Write-Host "Installation complete! Run 'accent --version' to verify."
}
