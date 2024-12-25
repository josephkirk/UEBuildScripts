# Wrapper script for common build configurations
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Editor", "Game", "Plugin", "Solution", "All")]
    [string]$Target,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$true)]
    [string]$EnginePath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Development", "Shipping", "DebugGame", "Test")]
    [string]$Config = "Development",
    
    [switch]$Clean,
    [switch]$Fast
)

$ScriptPath = Join-Path $PSScriptRoot "Build-UnrealProject.ps1"

# Build configuration based on target
switch ($Target) {
    "Editor" {
        $Args = @{
            ProjectPath = $ProjectPath
            EnginePath = $EnginePath
            BuildConfig = $Config
            BuildEditor = $true
            UseIncrementalBuilds = -not $Clean
            FastBuild = $Fast
        }
    }
    "Game" {
        $Args = @{
            ProjectPath = $ProjectPath
            EnginePath = $EnginePath
            BuildConfig = $Config
            PackageGame = $true
            OutputPath = "Build\$Config"
            CleanBuild = $Clean
            FastBuild = $Fast
        }
    }
    "Plugin" {
        $PluginPath = Join-Path (Split-Path $ProjectPath) "Plugins\*\*.uplugin"
        $Plugins = Get-ChildItem -Path $PluginPath
        
        $Args = @{
            ProjectPath = $ProjectPath
            EnginePath = $EnginePath
            BuildConfig = $Config
            BuildPlugin = $true
            AdditionalPluginPaths = $Plugins.FullName
            CleanBuild = $Clean
            FastBuild = $Fast
        }
    }
    "Solution" {
        $Args = @{
            ProjectPath = $ProjectPath
            EnginePath = $EnginePath
            GenerateSolution = $true
            VSVersion = "2022"
        }
    }
    "All" {
        $PluginPath = Join-Path (Split-Path $ProjectPath) "Plugins\*\*.uplugin"
        $Plugins = Get-ChildItem -Path $PluginPath
        
        $Args = @{
            ProjectPath = $ProjectPath
            EnginePath = $EnginePath
            BuildConfig = $Config
            BuildEditor = $true
            PackageGame = $true
            BuildPlugin = $true
            GenerateSolution = $true
            OutputPath = "Build\$Config"
            AdditionalPluginPaths = $Plugins.FullName
            CleanBuild = $Clean
            FastBuild = $Fast
            VSVersion = "2022"
        }
    }
}

# Convert hashtable to arguments
$ArgumentList = $Args.GetEnumerator() | ForEach-Object {
    if ($_.Value -is [bool] -and $_.Value) {
        "-$($_.Key)"
    }
    elseif ($_.Value -is [array]) {
        "-$($_.Key) $($_.Value -join ',')"
    }
    else {
        "-$($_.Key) `"$($_.Value)`""
    }
}

# Execute build script
try {
    Write-Host "Executing build script with target: $Target" -ForegroundColor Cyan
    Write-Host "Arguments: $ArgumentList" -ForegroundColor Gray
    
    & $ScriptPath @Args
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Build completed successfully" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "Build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}
catch {
    Write-Host "Error executing build script: $_" -ForegroundColor Red
    exit 1
}
