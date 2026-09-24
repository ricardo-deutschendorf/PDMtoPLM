# === Console output functions ===

# Section: Print a console section heading
function Write-Section {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor White
    Write-Host " $Title" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor White
}

# Section: Print a success message
function Write-Success {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [OK] $Message" -ForegroundColor Green
}

# Section: Print a failure message
function Write-Failure {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

# Section: Print a warning message
function Write-WarningMessage {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}

# Section: Print an informational message
function Write-Info {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  -> $Message" -ForegroundColor Gray
}
