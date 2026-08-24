[CmdletBinding()]
param(
    [ValidateSet('Start', 'Status', 'Stop')]
    [string] $Action = 'Start',

    [string] $ProjectPath,

    [string] $GodotPath,

    [ValidateRange(1, 120)]
    [int] $StartupTimeoutSeconds = 30,

    [ValidateRange(1, 120)]
    [int] $ShutdownTimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GodotWorktree.Common.ps1')

$repositoryRoot = Resolve-CanonicalPath -Path (Join-Path $PSScriptRoot '..\..')
$canonicalProjectPath = Find-GodotProject -SearchRoot $repositoryRoot -ProjectPath $ProjectPath
Assert-GodotAiPlugin -ProjectPath $canonicalProjectPath
$editors = @(Get-GodotEditorsForProject -ProjectPath $canonicalProjectPath)

if ($editors.Count -gt 1) {
    throw "Multiple Godot editors are running for '$canonicalProjectPath'. Stop the duplicate manually before continuing."
}

if ($Action -eq 'Status') {
    Write-Output ([pscustomobject]@{
        project_path = $canonicalProjectPath
        running = $editors.Count -eq 1
        process_id = if ($editors.Count -eq 1) { $editors[0].ProcessId } else { $null }
    })
    return
}

if ($Action -eq 'Stop') {
    if ($editors.Count -eq 0) {
        Write-Output "No Godot editor is running for '$canonicalProjectPath'."
        return
    }
    $editorProcess = Get-Process -Id $editors[0].ProcessId
    if (-not $editorProcess.CloseMainWindow()) {
        throw "Godot did not accept a graceful close request for '$canonicalProjectPath'. Close that editor manually; it was not terminated."
    }
    $shutdownDeadline = [DateTime]::UtcNow.AddSeconds($ShutdownTimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $editorProcess.Refresh()
    } while (-not $editorProcess.HasExited -and [DateTime]::UtcNow -lt $shutdownDeadline)
    if (-not $editorProcess.HasExited) {
        throw "Godot did not close within $ShutdownTimeoutSeconds seconds, possibly because it is showing a save prompt. Resolve the prompt in this worktree's editor; it was not force-terminated."
    }
    Write-WorktreeDiagnostic -ProjectPath $canonicalProjectPath -Data @{
        action = 'stopped'
        process_id = $editors[0].ProcessId
    }
    Write-Output "Stopped the Godot editor for '$canonicalProjectPath'."
    return
}

if ($editors.Count -eq 1) {
    Write-WorktreeDiagnostic -ProjectPath $canonicalProjectPath -Data @{
        action = 'already_running'
        process_id = $editors[0].ProcessId
        executable_path = $editors[0].ExecutablePath
    }
    Write-Output "Godot is already running for '$canonicalProjectPath'."
    return
}

$godotExecutable = Resolve-GodotExecutable -GodotPath $GodotPath
$dotnetExecutable = $null
if (Get-ChildItem -LiteralPath $canonicalProjectPath -Filter '*.csproj' -File | Select-Object -First 1) {
    $godotArchitecture = Get-WindowsExecutableArchitecture -Path $godotExecutable
    $dotnetExecutable = Set-DotNetSdkEnvironment -RequiredArchitecture $godotArchitecture
}
$process = Start-Process -FilePath $godotExecutable -ArgumentList @(
    '--editor',
    '--path',
    "`"$canonicalProjectPath`""
) -PassThru

$deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
do {
    Start-Sleep -Milliseconds 250
    $editors = @(Get-GodotEditorsForProject -ProjectPath $canonicalProjectPath)
} while ($editors.Count -eq 0 -and [DateTime]::UtcNow -lt $deadline -and -not $process.HasExited)

if ($editors.Count -ne 1) {
    $exitDetail = if ($process.HasExited) { " It exited with code $($process.ExitCode)." } else { '' }
    throw "Godot did not start an identifiable editor for '$canonicalProjectPath' within $StartupTimeoutSeconds seconds.$exitDetail"
}

Write-WorktreeDiagnostic -ProjectPath $canonicalProjectPath -Data @{
    action = 'started'
    process_id = $editors[0].ProcessId
    executable_path = $godotExecutable
    dotnet_executable = $dotnetExecutable
    plugin_version = Get-GodotAiPluginVersion -ProjectPath $canonicalProjectPath
}
Write-Output "Started Godot for '$canonicalProjectPath'."
