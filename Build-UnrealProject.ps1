# Enhanced Unreal Engine Build Script
# Handles: Editor, Game, Plugins, Solutions

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$true)] 
    [string]$EnginePath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Development", "Shipping", "DebugGame", "Test")]
    [string]$BuildConfig = "Development",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "Build",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Win64", "Linux", "Mac")]
    [string]$Platform = "Win64",
    
    [Parameter(Mandatory=$false)]
    [string]$PluginPath,

    [Parameter(Mandatory=$false)]
    [string[]]$AdditionalPluginPaths,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("2019", "2022")]
    [string]$VSVersion = "2022",
    
    [switch]$CleanBuild,
    [switch]$BuildEditor,
    [switch]$PackageGame,
    [switch]$BuildPlugin,
    [switch]$GenerateSolution,
    [switch]$UseIncrementalBuilds,
    [switch]$SkipCook,
    [switch]$FastBuild
)

# Environment Setup
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Speeds up web requests
$StartTime = Get-Date
$LogFile = Join-Path $PSScriptRoot "UnrealBuild_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Global:BuildSuccess = $true

# Enhanced Logging Function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ColorMap = @{
        "Info" = "White"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Success" = "Green"
    }
    
    $FormattedMessage = "[$TimeStamp] [$Level] $Message"
    Write-Host $FormattedMessage -ForegroundColor $ColorMap[$Level]
    $FormattedMessage | Out-File -FilePath $LogFile -Append
}

# Path Validation
function Test-Paths {
    $Paths = @{
        "Project" = $ProjectPath
        "Engine" = $EnginePath
        "Output" = $OutputPath
    }
    
    if ($PluginPath) {
        $Paths["Plugin"] = $PluginPath
    }
    
    foreach ($Path in $AdditionalPluginPaths) {
        if (-not [string]::IsNullOrEmpty($Path)) {
            $Paths["AdditionalPlugin_$Path"] = $Path
        }
    }
    
    foreach ($Entry in $Paths.GetEnumerator()) {
        if (-not (Test-Path $Entry.Value)) {
            if ($Entry.Key -eq "Output") {
                Write-Log "Creating output directory: $($Entry.Value)" -Level "Info"
                New-Item -ItemType Directory -Path $Entry.Value -Force | Out-Null
            }
            else {
                throw "Path not found: $($Entry.Key) - $($Entry.Value)"
            }
        }
    }
}

# Enhanced Editor Build
function Build-Editor {
    Write-Log "Starting Editor build..." -Level "Info"
    
    $UBTPath = Join-Path $EnginePath "Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe"
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
    
    $BuildArgs = @(
        "$ProjectName",
        "$Platform",
        "$BuildConfig",
        "-Project=`"$ProjectPath`"",
        "-Progress",
        "-NoHotReloadFromIDE"
    )
    
    if ($CleanBuild) {
        $BuildArgs += "-Clean"
    }
    
    if ($FastBuild) {
        $BuildArgs += "-FastBuild"
    }
    
    if ($UseIncrementalBuilds) {
        $BuildArgs += "-IncrementalBuild"
    }
    
    try {
        Write-Log "Running UnrealBuildTool with args: $BuildArgs" -Level "Info"
        $BuildProcess = Start-Process -FilePath $UBTPath -ArgumentList $BuildArgs -NoNewWindow -PassThru -Wait
        if ($BuildProcess.ExitCode -ne 0) {
            throw "Editor build failed with exit code: $($BuildProcess.ExitCode)"
        }
        Write-Log "Editor build completed successfully" -Level "Success"
    }
    catch {
        Write-Log "Error during editor build: $_" -Level "Error"
        $Global:BuildSuccess = $false
        throw
    }
}

# Enhanced Plugin Build
function Build-Plugin {
    param(
        [string]$CurrentPluginPath
    )
    
    Write-Log "Starting plugin build for: $CurrentPluginPath" -Level "Info"
    
    $UBTPath = Join-Path $EnginePath "Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe"
    $PluginName = [System.IO.Path]::GetFileNameWithoutExtension($CurrentPluginPath)
    
    $BuildArgs = @(
        "$PluginName",
        "$Platform",
        "$BuildConfig",
        "-Plugin=`"$CurrentPluginPath`"",
        "-Progress"
    )
    
    if ($CleanBuild) {
        $BuildArgs += "-Clean"
    }
    
    if ($FastBuild) {
        $BuildArgs += "-FastBuild"
    }
    
    try {
        Write-Log "Running UnrealBuildTool for plugin with args: $BuildArgs" -Level "Info"
        $BuildProcess = Start-Process -FilePath $UBTPath -ArgumentList $BuildArgs -NoNewWindow -PassThru -Wait
        if ($BuildProcess.ExitCode -ne 0) {
            throw "Plugin build failed with exit code: $($BuildProcess.ExitCode)"
        }
        Write-Log "Plugin build completed successfully" -Level "Success"
    }
    catch {
        Write-Log "Error during plugin build: $_" -Level "Error"
        $Global:BuildSuccess = $false
        throw
    }
}

# Enhanced Solution Generation
function Generate-Solution {
    Write-Log "Starting solution generation..." -Level "Info"
    
    $GenerateProjectPath = Join-Path $EnginePath "Generate-Project.bat"
    $VSVersionArg = "-$VSVersion"
    
    $GenArgs = @(
        "-ProjectFiles",
        "-Project=`"$ProjectPath`"",
        "-Game",
        $VSVersionArg,
        "-Progress"
    )
    
    if ($PluginPath) {
        $GenArgs += "-Plugin=`"$PluginPath`""
    }
    
    try {
        Write-Log "Generating solution with args: $GenArgs" -Level "Info"
        $GenProcess = Start-Process -FilePath $GenerateProjectPath -ArgumentList $GenArgs -NoNewWindow -PassThru -Wait
        if ($GenProcess.ExitCode -ne 0) {
            throw "Solution generation failed with exit code: $($GenProcess.ExitCode)"
        }
        Write-Log "Solution generation completed successfully" -Level "Success"
        
        # Generate solutions for additional plugins
        foreach ($Path in ($PluginPath, $AdditionalPluginPaths)) {
            if (-not [string]::IsNullOrEmpty($Path)) {
                $PluginGenArgs = @(
                    "-ProjectFiles",
                    "-Plugin=`"$Path`"",
                    $VSVersionArg,
                    "-Progress"
                )
                
                Write-Log "Generating solution for plugin: $Path" -Level "Info"
                $PluginGenProcess = Start-Process -FilePath $GenerateProjectPath -ArgumentList $PluginGenArgs -NoNewWindow -PassThru -Wait
                if ($PluginGenProcess.ExitCode -ne 0) {
                    throw "Plugin solution generation failed with exit code: $($PluginGenProcess.ExitCode)"
                }
                Write-Log "Plugin solution generation completed successfully" -Level "Success"
            }
        }
    }
    catch {
        Write-Log "Error during solution generation: $_" -Level "Error"
        $Global:BuildSuccess = $false
        throw
    }
}

# Enhanced Game Packaging
function Package-Game {
    Write-Log "Starting game packaging..." -Level "Info"
    
    $UATPath = Join-Path $EnginePath "Build\BatchFiles\RunUAT.bat"
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
    
    $PackageArgs = @(
        "BuildCookRun",
        "-Project=`"$ProjectPath`"",
        "-Platform=$Platform",
        "-ClientConfig=$BuildConfig",
        "-Stage",
        "-Package",
        "-Archive",
        "-ArchiveDirectory=`"$OutputPath`"",
        "-NoP4",
        "-BuildMachine",
        "-Progress"
    )
    
    if (-not $SkipCook) {
        $PackageArgs += "-Cook"
    }
    
    if ($CleanBuild) {
        $PackageArgs += "-Clean"
    }
    
    if ($FastBuild) {
        $PackageArgs += "-FastBuild"
    }
    
    try {
        Write-Log "Running UnrealAutomationTool with args: $PackageArgs" -Level "Info"
        $PackageProcess = Start-Process -FilePath $UATPath -ArgumentList $PackageArgs -NoNewWindow -PassThru -Wait
        if ($PackageProcess.ExitCode -ne 0) {
            throw "Game packaging failed with exit code: $($PackageProcess.ExitCode)"
        }
        Write-Log "Game packaging completed successfully" -Level "Success"
    }
    catch {
        Write-Log "Error during game packaging: $_" -Level "Error"
        $Global:BuildSuccess = $false
        throw
    }
}

# Performance Monitoring
function Get-ElapsedTime {
    $EndTime = Get-Date
    $TimeSpan = New-TimeSpan -Start $StartTime -End $EndTime
    return "$($TimeSpan.Hours)h $($TimeSpan.Minutes)m $($TimeSpan.Seconds)s"
}

# Main Execution
try {
    Write-Log "Build script started" -Level "Info"
    Write-Log "Configuration: Platform=$Platform, BuildConfig=$BuildConfig" -Level "Info"
    
    # Validate paths
    Test-Paths
    
    # Build plugins first
    if ($BuildPlugin) {
        if ($PluginPath) {
            Build-Plugin -CurrentPluginPath $PluginPath
        }
        
        foreach ($Path in $AdditionalPluginPaths) {
            if (-not [string]::IsNullOrEmpty($Path)) {
                Build-Plugin -CurrentPluginPath $Path
            }
        }
    }
    
    # Generate solutions
    if ($GenerateSolution) {
        Generate-Solution
    }
    
    # Build editor
    if ($BuildEditor) {
        Build-Editor
    }
    
    # Package game
    if ($PackageGame) {
        Package-Game
    }
    
    $ElapsedTime = Get-ElapsedTime
    if ($Global:BuildSuccess) {
        Write-Log "Build script completed successfully in $ElapsedTime" -Level "Success"
        exit 0
    }
    else {
        Write-Log "Build completed with errors in $ElapsedTime" -Level "Warning"
        exit 1
    }
}
catch {
    $ElapsedTime = Get-ElapsedTime
    Write-Log "Build script failed after $ElapsedTime : $_" -Level "Error"
    exit 1
}
finally {
    Write-Log "Log file location: $LogFile" -Level "Info"
}