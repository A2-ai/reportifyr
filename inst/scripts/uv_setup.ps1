# uv_setup.ps1 venv_directory python-docx_version pyyaml_version pillow_version uv_version [python_version]

param(
    [Parameter(Mandatory=$true)][string]$VenvDirectory,
    [Parameter(Mandatory=$true)][string]$PythonDocxVersion,
    [Parameter(Mandatory=$true)][string]$PyYamlVersion,
    [Parameter(Mandatory=$true)][string]$PillowVersion,
    [Parameter(Mandatory=$true)][string]$UvVersion,
    [Parameter(Mandatory=$false)][string]$PythonVersion
)

# Ensure local bin directories are in PATH at start
$LocalBin = Join-Path $env:USERPROFILE ".local\bin"
$CargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
if ($env:PATH -notlike "*$LocalBin*") {
    $env:PATH = "$LocalBin;$env:PATH"
}
if ($env:PATH -notlike "*$CargoBin*") {
    $env:PATH = "$CargoBin;$env:PATH"
}

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Check if uv is installed
if (-not (Test-Command "uv")) {
    Write-Host "'uv' is not installed. Installing version $UvVersion..."
    
    try {
        # Use official uv installer
        $InstallScript = "irm https://astral.sh/uv/$UvVersion/install.ps1 | iex"
        Invoke-Expression $InstallScript
        
        Write-Host "uv installed successfully"
        
        # Refresh PATH for current session
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
    } catch {
        Write-Error "Failed to install uv: $_"
        exit 1
    }
} else {
    Write-Host "uv already installed"
}

# Setup PowerShell autocompletion for uv
try {
    if (!(Test-Path -Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    
    # Check if autocompletion is already configured
    $ProfileContent = Get-Content -Path $PROFILE -ErrorAction SilentlyContinue
    if ($ProfileContent -notmatch "uv generate-shell-completion") {
        Add-Content -Path $PROFILE -Value '(& uv generate-shell-completion powershell) | Out-String | Invoke-Expression'
        Write-Host "Added uv autocompletion to PowerShell profile"
    }
} catch {
    Write-Warning "Could not setup uv autocompletion: $_"
}

# Create virtual environment if it doesn't exist
$VenvPath = Join-Path $VenvDirectory ".venv"
if (-not (Test-Path $VenvPath)) {
    if ($PythonVersion) {
        & uv venv $VenvPath --python=$PythonVersion
        Write-Host "Created venv at $VenvPath using python v$PythonVersion"
    } else {
        & uv venv $VenvPath
        Write-Host "Created venv at $VenvPath"
    }
} else {
    Write-Host "venv already exists at $VenvPath"
}

# Activate virtual environment (for uv pip commands)
# Note: We don't need to source activate script, uv pip works with --python flag

# Function to get Python package version
function Get-PythonPackageVersion {
    param([string]$PackageName, [string]$ImportName)
    try {
        $PythonExe = Join-Path $VenvPath "Scripts\python.exe"
        $Version = & $PythonExe -c "import $ImportName; print($ImportName.__version__)" 2>$null
        return $Version.Trim()
    } catch {
        return $null
    }
}

# Function to install or update Python package
function Install-PythonPackage {
    param(
        [string]$PackageName,
        [string]$ImportName,
        [string]$RequestedVersion,
        [string]$DefaultVersion
    )
    
    $Version = if ($RequestedVersion) { $RequestedVersion } else { $DefaultVersion }
    $PythonExe = Join-Path $VenvPath "Scripts\python.exe"
    
    try {
        # Check if package can be imported
        & $PythonExe -c "import $ImportName" 2>$null
        $ImportSuccess = $LASTEXITCODE -eq 0
    } catch {
        $ImportSuccess = $false
    }
    
    if (-not $ImportSuccess) {
        Write-Host "Installing $PackageName v$Version"
        & uv pip install "$PackageName==$Version" --python $PythonExe
        Write-Host "Installed $PackageName v$Version"
    } else {
        # Package exists, check version
        $CurrentVersion = Get-PythonPackageVersion -PackageName $PackageName -ImportName $ImportName
        Write-Host "Current $PackageName version: $CurrentVersion"
        
        if ($CurrentVersion -and $CurrentVersion -ne $Version) {
            Write-Host "Updating $PackageName from v$CurrentVersion to v$Version"
            & uv pip install "$PackageName==$Version" --python $PythonExe
            Write-Host "Installed $PackageName v$Version"
        } else {
            Write-Host "$PackageName already at correct version (v$CurrentVersion)"
        }
    }
}

# Install/update python-docx
Install-PythonPackage -PackageName "python-docx" -ImportName "docx" -RequestedVersion $PythonDocxVersion -DefaultVersion "1.1.2"

# Install/update PyYAML
Install-PythonPackage -PackageName "pyyaml" -ImportName "yaml" -RequestedVersion $PyYamlVersion -DefaultVersion "6.0.2"

# Install/update Pillow
Install-PythonPackage -PackageName "Pillow" -ImportName "PIL" -RequestedVersion $PillowVersion -DefaultVersion "11.1.0"

Write-Host "Python environment setup completed successfully"