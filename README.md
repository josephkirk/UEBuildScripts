# Unreal Engine Build Scripts

This directory contains scripts for building Unreal Engine projects, plugins, and generating solutions.

## Scripts Overview

1. `Build-UnrealProject.ps1` - The main build script with comprehensive functionality
2. `Build-Wrapper.ps1` - A convenient wrapper script for common build configurations
3. `build.bat` - Easy-to-use batch file that auto-detects project and engine paths

## Quick Start

### Using the Batch File (Recommended)

The batch file automatically detects your project and Unreal Engine installation. Simply run:

```batch
# Build editor (default)
build.bat

# Build with specific target and config
build.bat -target Editor -config Development

# Available targets: Editor, Game, Plugin, Solution, All
build.bat -target Game -config Shipping

# Build with clean
build.bat -target Editor -clean

# Fast build
build.bat -target All -fast
```

Batch file parameters:
- `-target`: Build target (Editor/Game/Plugin/Solution/All)
- `-config`: Build configuration (Development/Shipping/DebugGame/Test)
- `-clean`: Perform clean build
- `-fast`: Enable fast build mode

[Rest of the README content remains the same...]