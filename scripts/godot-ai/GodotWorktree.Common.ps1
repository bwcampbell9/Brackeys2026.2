Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not ('GodotWorktree.NativePath' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace GodotWorktree
{
    public static class NativePath
    {
        private const uint OpenExisting = 3;
        private const uint FileFlagBackupSemantics = 0x02000000;
        private const uint ShareReadWriteDelete = 7;

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern SafeFileHandle CreateFile(
            string fileName,
            uint desiredAccess,
            uint shareMode,
            IntPtr securityAttributes,
            uint creationDisposition,
            uint flagsAndAttributes,
            IntPtr templateFile);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern uint GetFinalPathNameByHandle(
            SafeFileHandle file,
            [Out] StringBuilder path,
            uint pathLength,
            uint flags);

        public static string Canonicalize(string path)
        {
            using (SafeFileHandle handle = CreateFile(
                path, 0, ShareReadWriteDelete, IntPtr.Zero, OpenExisting,
                FileFlagBackupSemantics, IntPtr.Zero))
            {
                if (handle.IsInvalid)
                    throw new Win32Exception(Marshal.GetLastWin32Error());

                StringBuilder result = new StringBuilder(32768);
                uint length = GetFinalPathNameByHandle(
                    handle, result, (uint)result.Capacity, 0);
                if (length == 0)
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                if (length >= result.Capacity)
                    throw new InvalidOperationException("Canonical path exceeds the Windows long-path limit.");

                string finalPath = result.ToString();
                if (finalPath.StartsWith(@"\\?\UNC\", StringComparison.OrdinalIgnoreCase))
                    return @"\\" + finalPath.Substring(8);
                if (finalPath.StartsWith(@"\\?\", StringComparison.OrdinalIgnoreCase))
                    return finalPath.Substring(4);
                return finalPath;
            }
        }
    }
}
'@
}

function Resolve-CanonicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $absolutePath = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).ProviderPath)
    return [GodotWorktree.NativePath]::Canonicalize($absolutePath).TrimEnd('\', '/')
}

function Find-GodotProject {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SearchRoot,

        [string] $ProjectPath
    )

    if ($ProjectPath) {
        $candidate = Resolve-CanonicalPath -Path $ProjectPath
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            if ([System.IO.Path]::GetFileName($candidate) -ne 'project.godot') {
                throw "The project path must name project.godot or its parent directory: $ProjectPath"
            }
            $candidate = Split-Path -Parent $candidate
        }
        if (-not (Test-Path -LiteralPath (Join-Path $candidate 'project.godot') -PathType Leaf)) {
            throw "project.godot was not found at '$candidate'."
        }
        return $candidate
    }

    $root = Resolve-CanonicalPath -Path $SearchRoot
    if (Test-Path -LiteralPath (Join-Path $root 'project.godot') -PathType Leaf) {
        return $root
    }

    $projects = @(Get-ChildItem -LiteralPath $root -Filter 'project.godot' -File -Recurse |
        ForEach-Object { Resolve-CanonicalPath -Path $_.DirectoryName } |
        Select-Object -Unique)
    if ($projects.Count -eq 0) {
        throw "No project.godot was found under '$root'."
    }
    if ($projects.Count -gt 1) {
        throw "Multiple Godot projects were found under '$root': $($projects -join ', '). Pass -ProjectPath explicitly."
    }
    return $projects[0]
}

function Assert-GodotAiPlugin {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProjectPath
    )

    $pluginConfig = Join-Path $ProjectPath 'addons\godot_ai\plugin.cfg'
    if (-not (Test-Path -LiteralPath $pluginConfig -PathType Leaf)) {
        throw "The Godot AI plugin is unavailable. Expected '$pluginConfig'."
    }

    $projectConfig = Get-Content -LiteralPath (Join-Path $ProjectPath 'project.godot') -Raw
    if ($projectConfig -notmatch 'res://addons/godot_ai/plugin\.cfg') {
        throw 'The Godot AI plugin is installed but is not enabled in project.godot.'
    }
}

function Resolve-GodotExecutable {
    param([string] $GodotPath)

    function Confirm-GodotExecutable {
        param([string] $Candidate)

        $resolved = Resolve-CanonicalPath -Path $Candidate
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($resolved)
        if ($versionInfo.ProductName -ne 'Godot Engine') {
            throw "'$resolved' is not a Godot Engine executable."
        }
        return $resolved
    }

    $candidates = @($GodotPath, $env:GODOT_EXE, $env:GODOT_PATH)
    foreach ($candidate in $candidates) {
        if (-not $candidate) {
            continue
        }
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $executables = @(Get-ChildItem -LiteralPath $candidate -Filter 'Godot*.exe' -File |
                Where-Object {
                    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).ProductName -eq 'Godot Engine'
                })
            if ($executables.Count -ne 1) {
                throw "Godot directory '$candidate' must contain exactly one Godot*.exe."
            }
            return Confirm-GodotExecutable -Candidate $executables[0].FullName
        }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return Confirm-GodotExecutable -Candidate $candidate
        }
        throw "Godot executable '$candidate' does not exist."
    }

    foreach ($commandName in @('godot', 'godot4')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return Confirm-GodotExecutable -Candidate $command.Source
        }
    }

    throw 'Godot was not found. Pass -GodotPath, set GODOT_EXE (or GODOT_PATH), or add godot/godot4 to PATH.'
}

function Get-WindowsExecutableArchitecture {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $reader = [System.IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) {
            throw "'$Path' is not a Windows executable."
        }

        $stream.Position = 0x3C
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "'$Path' has an invalid PE header."
        }

        $machine = $reader.ReadUInt16()
        switch ($machine) {
            0x014C { return 'x86' }
            0x8664 { return 'x64' }
            0xAA64 { return 'arm64' }
            default { throw "'$Path' uses unsupported PE machine type 0x$($machine.ToString('X4'))." }
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Set-DotNetSdkEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('x86', 'x64', 'arm64')]
        [string] $RequiredArchitecture
    )

    $candidates = @(
        Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'dotnet\dotnet.exe'
        Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)) 'dotnet\x64\dotnet.exe'
        Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)) 'dotnet\dotnet.exe'
    )
    foreach ($registryPath in @(
        "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\$RequiredArchitecture",
        "HKLM:\SOFTWARE\WOW6432Node\dotnet\Setup\InstalledVersions\$RequiredArchitecture"
    )) {
        $registeredInstall = Get-ItemProperty -LiteralPath $registryPath -ErrorAction SilentlyContinue
        if ($registeredInstall -and $registeredInstall.PSObject.Properties['InstallLocation']) {
            $candidates += Join-Path $registeredInstall.InstallLocation 'dotnet.exe'
        }
    }
    if ($env:DOTNET_ROOT) {
        $candidates += Join-Path $env:DOTNET_ROOT 'dotnet.exe'
    }
    if ($env:USERPROFILE) {
        $candidates += Join-Path $env:USERPROFILE '.dotnet\dotnet.exe'
    }

    $dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($dotnetCommand) {
        $candidates += $dotnetCommand.Source
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }

        if ((Get-WindowsExecutableArchitecture -Path $candidate) -ne $RequiredArchitecture) {
            continue
        }

        $installedSdks = @(& $candidate --list-sdks 2>$null)
        if ($LASTEXITCODE -ne 0 -or $installedSdks.Count -eq 0) {
            continue
        }

        $dotnetRoot = Split-Path -Parent $candidate
        $env:DOTNET_ROOT = $dotnetRoot
        $remainingPathEntries = @($env:PATH -split ';' | Where-Object {
            -not [string]::Equals($_, $dotnetRoot, [System.StringComparison]::OrdinalIgnoreCase)
        })
        $env:PATH = (@($dotnetRoot) + $remainingPathEntries) -join ';'
        return $candidate
    }

    throw "No $RequiredArchitecture .NET SDK was found for the $RequiredArchitecture Godot executable. Install a matching SDK or set DOTNET_ROOT before starting Godot."
}

function Get-GodotEditorProjectPath {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CommandLine
    )

    if ($CommandLine -notmatch '(?i)(?:^|\s)--editor(?:\s|$)') {
        return $null
    }
    $match = [regex]::Match(
        $CommandLine,
        '(?i)(?:^|\s)--path(?:=|\s+)(?:"([^"]+)"|''([^'']+)''|(\S+))'
    )
    if (-not $match.Success) {
        return $null
    }
    foreach ($groupIndex in 1..3) {
        if ($match.Groups[$groupIndex].Success) {
            return $match.Groups[$groupIndex].Value
        }
    }
    return $null
}

function Get-GodotEditorsForProject {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProjectPath
    )

    $canonicalProjectPath = Resolve-CanonicalPath -Path $ProjectPath
    $matchingEditors = @()
    $processes = @(Get-CimInstance Win32_Process |
        Where-Object { $_.Name -match '(?i)^Godot(?!-ai).*\.exe$' -and $_.CommandLine })
    foreach ($process in $processes) {
        $processProjectPath = Get-GodotEditorProjectPath -CommandLine $process.CommandLine
        if (-not $processProjectPath -or -not [System.IO.Path]::IsPathRooted($processProjectPath)) {
            continue
        }
        try {
            $canonicalProcessPath = Resolve-CanonicalPath -Path $processProjectPath
        }
        catch {
            continue
        }
        if ([string]::Equals(
            $canonicalProjectPath,
            $canonicalProcessPath,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            $matchingEditors += $process
        }
    }
    return $matchingEditors
}

function Get-GodotAiPluginVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProjectPath
    )

    $pluginConfig = Get-Content -LiteralPath (Join-Path $ProjectPath 'addons\godot_ai\plugin.cfg') -Raw
    $match = [regex]::Match($pluginConfig, '(?m)^version="([^"]+)"')
    if (-not $match.Success) {
        throw 'The Godot AI plugin version is missing from plugin.cfg.'
    }
    return $match.Groups[1].Value
}

function Write-WorktreeDiagnostic {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProjectPath,

        [Parameter(Mandatory = $true)]
        [hashtable] $Data
    )

    $localRoot = if ($env:LOCALAPPDATA) {
        $env:LOCALAPPDATA
    }
    else {
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    }
    $diagnosticRoot = Join-Path $localRoot 'Nottingham\godot-ai-worktrees'
    $null = New-Item -ItemType Directory -Path $diagnosticRoot -Force

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($ProjectPath.ToLowerInvariant())
        $hash = ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').Substring(0, 16)
    }
    finally {
        $sha256.Dispose()
    }

    $record = @{
        timestamp_utc = [DateTime]::UtcNow.ToString('o')
        project_path = $ProjectPath
    }
    foreach ($key in $Data.Keys) {
        $record[$key] = $Data[$key]
    }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $diagnosticRoot "$hash.json") -Encoding UTF8
}
