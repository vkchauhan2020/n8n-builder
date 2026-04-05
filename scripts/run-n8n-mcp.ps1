$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$nodeDir = "C:\Users\vkcha\AppData\Local\Microsoft\WinGet\Packages\OpenJS.NodeJS.LTS_Microsoft.Winget.Source_8wekyb3d8bbwe\node-v24.14.1-win-x64"
$envFile = Join-Path $projectRoot ".env.n8n-mcp"

if (-not (Test-Path $nodeDir)) {
    throw "Node.js directory not found at $nodeDir"
}

# Ensure the Node.js install used by winget is available to npx during MCP startup.
$env:Path = "$nodeDir;$env:Path"

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            return
        }

        $parts = $line.Split("=", 2)
        if ($parts.Count -ne 2) {
            return
        }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim()

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        Set-Item -Path "Env:$name" -Value $value
    }
}

if (-not $env:MCP_MODE) {
    $env:MCP_MODE = "stdio"
}

if (-not $env:LOG_LEVEL) {
    $env:LOG_LEVEL = "error"
}

if (-not $env:DISABLE_CONSOLE_OUTPUT) {
    $env:DISABLE_CONSOLE_OUTPUT = "true"
}

& (Join-Path $nodeDir "npx.cmd") "-y" "n8n-mcp"
