# === NX conversion and Teamcenter methods ===

# Section: Find generated NX files
function Get-NxConvertedFiles {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath
    )

    if (-not (
            Test-Path -LiteralPath $NxFolderPath
        )) {

        return [PSCustomObject]@{
            PrtFiles = @()
            JtFiles  = @()
        }
    }

    $convertedFiles =
    @(
        Get-ChildItem  -LiteralPath $NxFolderPath  -File  -Recurse  -ErrorAction SilentlyContinue
    )

    return [PSCustomObject]@{
        PrtFiles = @(
            $convertedFiles |
            Where-Object {
                $_.Extension -ieq ".prt"
            }
        )

        JtFiles  = @(
            $convertedFiles |
            Where-Object {
                $_.Extension -ieq ".jt"
            }
        )
    }
}

# Section: Run NX conversion
function Invoke-NxConversion {

    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFolderPath
    )

    $nxMigratedFolderPath =
    Join-Path  $InputFolderPath  "NXmigratedFiles"

    $existingConvertedFiles =
    Get-NxConvertedFiles `
        -NxFolderPath $nxMigratedFolderPath

    if ($existingConvertedFiles.PrtFiles.Count -gt 0) {

        Write-Section `
            -Title "NX CONVERSION"

        Write-WarningMessage `
            -Message "NX conversion will not be repeated."

        foreach ($existingPrtFile in $existingConvertedFiles.PrtFiles) {

            Write-Info `
                -Message "Existing PRT: $($existingPrtFile.Name)"
        }

        return [string]$nxMigratedFolderPath
    }

    if (
        Test-Path -LiteralPath $nxMigratedFolderPath
    ) {

        Write-WarningMessage  -Message "Incomplete NX conversion folder found."

        Write-WarningMessage  -Message "Removing only the incomplete output."

        Remove-Item  -LiteralPath $nxMigratedFolderPath  -Recurse  -Force
    }

    Write-Section  -Title "RUNNING NX CONVERSION"

    New-NxImportWrapper

    Write-Info  -Message "Running NX batch..."

    & $runJournalPath  $temporaryWrapperPath  "-args"  $InputFolderPath  $companyName |
    Out-Host

    $nxExitCode =
    $LASTEXITCODE

    if ($nxExitCode -ne 0) {

        throw  "NX returned error code $nxExitCode. Check '$nxLogPath'."
    }

    $generatedFiles =
    Get-NxConvertedFiles  -NxFolderPath $nxMigratedFolderPath

    if ($generatedFiles.PrtFiles.Count -eq 0) {

        throw  "NX conversion completed, but no PRT file was generated."
    }

    Write-Success  -Message "NX conversion completed."

    return [string]$nxMigratedFolderPath
}

# Section: Show conversion results
function Show-ConversionResult {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath
    )

    $conversionResult =
    Get-NxConvertedFiles  -NxFolderPath $NxFolderPath

    Write-Section  -Title "CONVERSION RESULT"

    foreach (
        $prtFile in
        $conversionResult.PrtFiles
    ) {

        Write-Success  -Message "PRT: $($prtFile.Name)"
    }

    if ($conversionResult.JtFiles.Count -eq 0) {

        Write-WarningMessage  -Message "No JT file was found."
    }
    else {

        foreach (
            $jtFile in
            $conversionResult.JtFiles
        ) {

            Write-Success  -Message "JT: $($jtFile.Name)"
        }
    }

    return $conversionResult
}

# Section: Run the Teamcenter import
function Invoke-TeamcenterImport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "Part",
            "Assembly"
        )]
        [string]$DocumentType,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "Create",
            "Existing"
        )]
        [string]$ItemTargetMode,

        [string]$ExistingItemCode
    )

    Write-Section  -Title "TEAMCENTER IMPORT"

    $teamcenterImportScript =
    Join-Path  (Split-Path -Parent $PSScriptRoot)  "import_toTeamcenter.ps1"

    if (-not (
            Test-Path  -LiteralPath $teamcenterImportScript  -PathType Leaf
        )) {

        throw  "import_toTeamcenter.ps1 not found at '$teamcenterImportScript'."
    }

    $powerShell64Path =
    Join-Path  $env:WINDIR  "Sysnative\WindowsPowerShell\v1.0\powershell.exe"

    if (-not (
            Test-Path  -LiteralPath $powerShell64Path  -PathType Leaf
        )) {

        $powerShell64Path =
        Join-Path  $env:WINDIR  "System32\WindowsPowerShell\v1.0\powershell.exe"
    }

    if (-not (
            Test-Path  -LiteralPath $powerShell64Path  -PathType Leaf
        )) {

        throw  "64-bit Windows PowerShell was not found."
    }

    Write-Info  -Message "Document type: $DocumentType"

$importArguments =
@(
    "-NoProfile"
    "-ExecutionPolicy"
    "Bypass"
    "-File"
    $teamcenterImportScript
    "-PastaNx"
    $NxFolderPath
    "-DocumentType"
    $DocumentType
    "-ItemTargetMode"
    $ItemTargetMode
)

if ($ItemTargetMode -eq "Existing") {

    if (
        [System.String]::IsNullOrWhiteSpace(
            $ExistingItemCode
        )
    ) {

        throw `
            "O codigo do item existente nao foi informado."
    }

    $importArguments +=
    @(
        "-ExistingItemCode"
        $ExistingItemCode
    )
}

& $powerShell64Path @importArguments

    $teamcenterExitCode =
    $LASTEXITCODE

    if ($teamcenterExitCode -ne 0) {

        throw  "Teamcenter import failed with code $teamcenterExitCode."
    }

}
