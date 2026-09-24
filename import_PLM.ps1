# === PLM importer deployment workflow ===


$ErrorActionPreference = "Stop"



$networkDriveName =
    "Q"

$networkDrivePath =
    "\\perto38-novo\NX_Custom"

$sourcePath =
    "Q:\ImportByPDM\Brazil\ImportarGD_V11"

$temporaryDirectory =
    "C:\Temp"

$destinationPath =
    "C:\Temp\ImportarGD"
$executableName =
    "Importar GD.exe"

$executablePath =
    Join-Path  $destinationPath  $executableName



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



# Section: Connect the network drive
function Connect-NetworkDrive {

    Write-Section  -Title "NETWORK DRIVE"

    $existingDrive =
        Get-PSDrive  -Name $networkDriveName  -ErrorAction SilentlyContinue

    if ($null -ne $existingDrive) {

        if (
            $existingDrive.Root -ieq
            "$networkDrivePath\"
        ) {

            Write-Success  -Message "Network drive $networkDriveName`: is already mapped."

            Write-Info  -Message "Path: $($existingDrive.Root)"

            return
        }

        Write-WarningMessage  -Message "Drive $networkDriveName`: is mapped to another directory."

        Write-Info  -Message "Current path: $($existingDrive.Root)"

        Write-Info  -Message "Expected path: $networkDrivePath"

        Write-WarningMessage  -Message "Removing the existing mapping."

        & net.exe use "$networkDriveName`:" /delete /yes |
            Out-Null

        if ($LASTEXITCODE -ne 0) {

            throw  "Could not remove the existing network drive mapping."
        }
    }

    Write-Info  -Message "Mapping network drive $networkDriveName`:..."

    & net.exe use "$networkDriveName`:" $networkDrivePath |
        Out-Null

    if ($LASTEXITCODE -ne 0) {

        throw  "Could not map '$networkDrivePath' to drive $networkDriveName`:."
    }

    if (-not (
        Test-Path -LiteralPath "$networkDriveName`:\"
    )) {

        throw  "Network drive $networkDriveName`: was mapped but is not accessible."
    }

    Write-Success  -Message "Network drive mapped successfully."

    Write-Info  -Message "Path: $networkDriveName`:\"
}



# Section: Validate the importer source
function Test-ImporterSource {

    Write-Section  -Title "VALIDATING IMPORTER SOURCE"

    Write-Info  -Message "Source: $sourcePath"

    Write-Info  -Message "Destination: $destinationPath"

    if (-not (
        Test-Path -LiteralPath $sourcePath
    )) {

        throw  "Importer source was not found at '$sourcePath'."
    }

    $sourceExecutablePath =
        Join-Path  $sourcePath  $executableName

    if (-not (
        Test-Path -LiteralPath $sourceExecutablePath
    )) {

        throw  "$executableName was not found at '$sourcePath'."
    }

    Write-Success  -Message "Importer source validated."
}



# Section: Initialize the destination directory
function Initialize-DestinationDirectory {

    if (-not (
        Test-Path -LiteralPath $temporaryDirectory
    )) {

        New-Item  -ItemType Directory  -Path $temporaryDirectory  -Force |
        Out-Null

        Write-Info  -Message "Directory created: $temporaryDirectory"
    }

    if (-not (
        Test-Path -LiteralPath $destinationPath
    )) {

        New-Item  -ItemType Directory  -Path $destinationPath  -Force |
        Out-Null

        Write-Info  -Message "Directory created: $destinationPath"
    }
}



# Section: Synchronize importer files
function Sync-TeamcenterImporter {

    Write-Section  -Title "INSTALLING TEAMCENTER IMPORTER"

    Initialize-DestinationDirectory

    Write-Info  -Message "Synchronizing importer files..."

    $robocopyArguments = @(
        $sourcePath
        $destinationPath
        "/E"
        "/COPY:DAT"
        "/DCOPY:DAT"
        "/R:2"
        "/W:1"
        "/FFT"
        "/XO"
        "/XN"
        "/XC"
        "/NP"
        "/NFL"
        "/NDL"
    )

    & robocopy.exe @robocopyArguments

    $robocopyExitCode =
        $LASTEXITCODE

    if ($robocopyExitCode -ge 8) {

        throw  "Importer synchronization failed with Robocopy code $robocopyExitCode."
    }

    if ($robocopyExitCode -eq 0) {

        Write-Success  -Message "Importer files are already up to date."
    }
    else {

        Write-Success  -Message "Importer files synchronized successfully."
    }

    if (-not (
        Test-Path -LiteralPath $executablePath
    )) {

        throw  "$executableName was not found after synchronization."
    }
}



# Section: Unblock importer files
function Unblock-ImporterFiles {

    Write-Section  -Title "UNBLOCKING IMPORTER FILES"

    $files =
        @(
            Get-ChildItem  -LiteralPath $destinationPath  -File  -Recurse  -ErrorAction Stop
        )

    if ($files.Count -eq 0) {

        throw  "No importer files were found at '$destinationPath'."
    }

    foreach ($file in $files) {

        Unblock-File  -LiteralPath $file.FullName  -ErrorAction Stop
    }

    Write-Success  -Message "Importer files unblocked."

    Write-Info  -Message "Files processed: $($files.Count)"
}



# Section: Show installation results
function Show-InstallationResult {

    Write-Section  -Title "INSTALLATION RESULT"

    $installedFiles =
        @(
            Get-ChildItem  -LiteralPath $destinationPath  -File  -Recurse  -ErrorAction Stop
        )

    foreach ($installedFile in $installedFiles) {

        Write-Success  -Message $installedFile.Name
    }

    Write-Host ""

    Write-Info  -Message "Executable: $executablePath"
}



try {

    Connect-NetworkDrive

    Test-ImporterSource

    Sync-TeamcenterImporter

    Unblock-ImporterFiles

    Show-InstallationResult

    Write-Section  -Title "INSTALLATION COMPLETED"

    Write-Success  -Message "Teamcenter importer is ready to use."

    Write-Info  -Message "Location: $destinationPath"

    exit 0
}
catch {

    Write-Host ""

    Write-Failure  -Message $_.Exception.Message

    Write-Host ""
    Write-Host "[FULL ERROR]" -ForegroundColor DarkGray
    Write-Host $_.Exception.ToString() -ForegroundColor DarkGray
    Write-Host ""

    exit 1
}