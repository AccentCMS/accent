# Accent CMS installer for Windows.
#
# Usage:
#   irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1 | iex
#
# Or with parameters:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/AccentCMS/accent/main/install.ps1))) -Version v0.22.0
#
# There is one binary per platform: every download contains the full
# feature set, and your license key decides which tier is unlocked at
# runtime. Releases before v0.22.0 were never published here.
#
# Failure style: this script uses `throw`, never `exit`. Under the
# documented `irm | iex` invocation there is no script frame on the call
# stack, so `exit` would terminate the user's whole PowerShell session;
# `throw` stops the installer and returns to the prompt.

param(
    [string]$Version = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Repo = "AccentCMS/accent"
$InstallDir = Join-Path $env:LOCALAPPDATA "accent"

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

function Resolve-Version {
    if ($Version) {
        Write-Host "Installing version: $Version"
        return
    }

    Write-Host "Fetching latest version..."
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
            $script:Version = $Matches[1]
        }
    } catch {
        throw "Could not determine latest version. There may be no published release yet, or the network request failed. Check https://github.com/$Repo/releases or specify a version with -Version."
    }

    if (-not $script:Version) {
        throw "Could not determine latest version. There may be no published release yet. Check https://github.com/$Repo/releases or specify a version with -Version."
    }

    Write-Host "Latest version: $script:Version"
}

# --- Check existing installation ---

function Check-Existing {
    $binary = Join-Path $InstallDir "accent.exe"
    if ((Test-Path $binary) -and -not $Force) {
        try {
            $existing = & $binary --version 2>&1
            Write-Host "Accent CMS is already installed: $existing"
        } catch {
            Write-Host "Accent CMS is already installed at: $binary"
        }
        Write-Host "Use -Force to overwrite, or remove it first:"
        Write-Host "  Remove-Item `"$InstallDir`" -Recurse"
        throw "Accent CMS is already installed (re-run with -Force to overwrite)."
    }
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
            Invoke-WebRequest -Uri $downloadUrl -OutFile (Join-Path $tmpDir $archiveName) -UseBasicParsing
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
            Invoke-WebRequest -Uri $checksumsUrl -OutFile $checksumsPath -UseBasicParsing
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

# --- Main ---

Write-Host "Accent CMS Installer"
Write-Host "==================="
Write-Host ""

Detect-Platform
Resolve-Version
Check-Existing
Download-And-Install
Check-Path

Write-Host ""
Write-Host "Installation complete! Run 'accent --version' to verify."
