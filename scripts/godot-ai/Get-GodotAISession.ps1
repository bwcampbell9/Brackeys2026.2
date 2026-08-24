[CmdletBinding()]
param(
    [string] $ProjectPath,

    [string] $GodotPath,

    [string] $McpUrl = $(if ($env:GODOT_AI_MCP_URL) { $env:GODOT_AI_MCP_URL } else { 'http://127.0.0.1:8000/mcp' }),

    [string] $ExpectedSessionId,

    [ValidateRange(1, 120)]
    [int] $TimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'GodotWorktree.Common.ps1')
$script:McpProtocolVersion = $null
$requestTimeoutSeconds = [Math]::Min($TimeoutSeconds, 10)

function ConvertFrom-McpResponse {
    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject] $Response
    )

    $dataLine = $Response.Content -split "`r?`n" |
        Where-Object { $_ -like 'data: *' } |
        Select-Object -Last 1
    if (-not $dataLine) {
        throw "Godot AI returned an unexpected MCP response with content type '$($Response.Headers['Content-Type'])'."
    }
    return $dataLine.Substring(6) | ConvertFrom-Json
}

function Invoke-McpPost {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable] $Message,

        [string] $McpSessionId
    )

    $headers = @{ Accept = 'application/json, text/event-stream' }
    if ($McpSessionId) {
        $headers['Mcp-Session-Id'] = $McpSessionId
    }
    if ($script:McpProtocolVersion) {
        $headers['MCP-Protocol-Version'] = $script:McpProtocolVersion
    }
    return Invoke-WebRequest -UseBasicParsing -Uri $McpUrl -Method Post -Headers $headers `
        -ContentType 'application/json' -TimeoutSec $requestTimeoutSeconds `
        -Body ($Message | ConvertTo-Json -Depth 12 -Compress)
}

function Invoke-McpTool {
    param(
        [Parameter(Mandatory = $true)]
        [string] $McpSessionId,

        [Parameter(Mandatory = $true)]
        [int] $Id,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [hashtable] $Arguments
    )

    $response = Invoke-McpPost -McpSessionId $McpSessionId -Message @{
        jsonrpc = '2.0'
        id = $Id
        method = 'tools/call'
        params = @{
            name = $Name
            arguments = $Arguments
        }
    }
    $envelope = ConvertFrom-McpResponse -Response $response
    if ($envelope.PSObject.Properties['error']) {
        throw "Godot AI MCP error: $($envelope.error.message)"
    }
    if ($envelope.result.PSObject.Properties['isError'] -and $envelope.result.isError) {
        $message = ($envelope.result.content | ForEach-Object { $_.text }) -join [Environment]::NewLine
        throw "Godot AI tool '$Name' failed: $message"
    }
    if ($envelope.result.PSObject.Properties['structuredContent'] -and $envelope.result.structuredContent) {
        return $envelope.result.structuredContent
    }
    $text = ($envelope.result.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
    return $text | ConvertFrom-Json
}

$repositoryRoot = Resolve-CanonicalPath -Path (Join-Path $PSScriptRoot '..\..')
$canonicalProjectPath = Find-GodotProject -SearchRoot $repositoryRoot -ProjectPath $ProjectPath
$pluginVersion = Get-GodotAiPluginVersion -ProjectPath $canonicalProjectPath

& (Join-Path $PSScriptRoot 'Start-GodotWorktree.ps1') -ProjectPath $canonicalProjectPath `
    -GodotPath $GodotPath -StartupTimeoutSeconds $TimeoutSeconds | Write-Verbose

$mcpSessionId = $null
try {
    $initializeDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $initializeResponse = $null
    $lastInitializeError = $null
    do {
        try {
            $initializeResponse = Invoke-McpPost -Message @{
                jsonrpc = '2.0'
                id = 1
                method = 'initialize'
                params = @{
                    protocolVersion = '2025-06-18'
                    capabilities = @{}
                    clientInfo = @{
                        name = 'nottingham-godot-worktree-bootstrap'
                        version = '1.0'
                    }
                }
            }
            break
        }
        catch {
            $lastInitializeError = $_.Exception.Message
            Start-Sleep -Milliseconds 500
        }
    } while ([DateTime]::UtcNow -lt $initializeDeadline)

    if (-not $initializeResponse) {
        throw "Godot AI MCP at '$McpUrl' did not become available within $TimeoutSeconds seconds. Last error: $lastInitializeError"
    }
    $initialize = ConvertFrom-McpResponse -Response $initializeResponse
    if ($initialize.PSObject.Properties['error']) {
        throw "Godot AI MCP initialization failed: $($initialize.error.message)"
    }
    $script:McpProtocolVersion = $initialize.result.protocolVersion
    if (-not $script:McpProtocolVersion) {
        throw 'Godot AI MCP initialization did not negotiate a protocol version.'
    }
    $mcpSessionId = $initializeResponse.Headers['Mcp-Session-Id']
    if (-not $mcpSessionId) {
        throw 'Godot AI MCP initialization did not return an Mcp-Session-Id header.'
    }
    $null = Invoke-McpPost -McpSessionId $mcpSessionId -Message @{
        jsonrpc = '2.0'
        method = 'notifications/initialized'
        params = @{}
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $sessionList = Invoke-McpTool -McpSessionId $mcpSessionId -Id 2 `
            -Name 'session_manage' -Arguments @{ op = 'list' }
        $matchingSessions = @($sessionList.sessions | Where-Object {
            try {
                $sessionProjectPath = Resolve-CanonicalPath -Path $_.project_path
                [string]::Equals(
                    $canonicalProjectPath,
                    $sessionProjectPath,
                    [System.StringComparison]::OrdinalIgnoreCase
                )
            }
            catch {
                $false
            }
        })
        if ($matchingSessions.Count -eq 1) {
            break
        }
        if ($matchingSessions.Count -gt 1) {
            throw "Godot AI reported multiple sessions for '$canonicalProjectPath': $($matchingSessions.session_id -join ', '). Close duplicate editors; routing is ambiguous."
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)

    if ($matchingSessions.Count -eq 0) {
        $reportedPaths = @($sessionList.sessions | ForEach-Object { "'$($_.project_path)'" })
        $detail = if ($reportedPaths.Count) { " Reported project paths: $($reportedPaths -join ', ')." } else { ' No editor sessions were reported.' }
        throw "No Godot AI session matched canonical project path '$canonicalProjectPath'.$detail"
    }

    $target = $matchingSessions[0]
    if ($ExpectedSessionId -and $target.session_id -ne $ExpectedSessionId) {
        throw "Godot AI session changed for '$canonicalProjectPath': expected '$ExpectedSessionId', found '$($target.session_id)'. Re-resolve and retain the new ID before continuing."
    }
    if ($target.plugin_version -ne $pluginVersion) {
        throw "The matched session uses Godot AI plugin $($target.plugin_version), but this worktree contains $pluginVersion. Restart this worktree's editor."
    }

    # This read proves explicit routing without changing the server-global active session.
    $null = Invoke-McpTool -McpSessionId $mcpSessionId -Id 3 -Name 'editor_state' `
        -Arguments @{ session_id = $target.session_id }

    Write-WorktreeDiagnostic -ProjectPath $canonicalProjectPath -Data @{
        action = 'session_resolved'
        session_id = $target.session_id
        plugin_version = $target.plugin_version
        mcp_url = $McpUrl
    }
    Write-Output $target.session_id
}
finally {
    if ($mcpSessionId) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $McpUrl -Method Delete -Headers @{
                Accept = 'application/json, text/event-stream'
                'Mcp-Session-Id' = $mcpSessionId
                'MCP-Protocol-Version' = $script:McpProtocolVersion
            } -TimeoutSec $requestTimeoutSeconds | Out-Null
        }
        catch {
            Write-Verbose "Could not close the bootstrap MCP client session: $($_.Exception.Message)"
        }
    }
}
