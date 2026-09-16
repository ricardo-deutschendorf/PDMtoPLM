param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PastaNx
)

# ============================================================
# TEAMCENTER IMPORT
# Imports generated NX PRT files into Teamcenter.
# ============================================================

$ErrorActionPreference = "Stop"


# ============================================================
# CONFIGURATION
# ============================================================

$companyCode =
"02"

$itemType =
"GD5DesignPerto"

$teamcenterFunctionsPath =
Join-Path `
    $PSScriptRoot `
    "teamcenter_functions.ps1"


# ============================================================
# VALIDATION
# ============================================================

if (-not (
        Test-Path `
            -LiteralPath $teamcenterFunctionsPath `
            -PathType Leaf
    )) {

    Write-Host `
        "[ERROR] Teamcenter functions file not found:" `
        -ForegroundColor Red

    Write-Host `
        $teamcenterFunctionsPath `
        -ForegroundColor Red

    exit 1
}

. $teamcenterFunctionsPath


# ============================================================
# CONSOLE OUTPUT
# ============================================================

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


function Write-Success {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host `
        "  [OK] $Message" `
        -ForegroundColor Green
}


function Write-Failure {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host `
        "  [ERROR] $Message" `
        -ForegroundColor Red
}


function Write-Info {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host `
        "  -> $Message" `
        -ForegroundColor Gray
}


# ============================================================
# NX INPUT VALIDATION
# ============================================================

function Get-NxPartFiles {

    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    if (-not (
            Test-Path `
                -LiteralPath $FolderPath `
                -PathType Container
        )) {

        throw `
            "NX folder not found at '$FolderPath'."
    }

    $partFiles =
    @(
        Get-ChildItem `
            -LiteralPath $FolderPath `
            -Filter "*.prt" `
            -File `
            -Recurse `
            -ErrorAction Stop
    ) |
    Where-Object {

        $_.BaseName -notmatch '^[_-]?\d+$'
    }

    if ($partFiles.Count -eq 0) {

        throw `
            "No PRT files were found at '$FolderPath'."
    }

    return $partFiles
}


# ============================================================
# TEAMCENTER PART IMPORT
# ============================================================

function Import-NxPartToTeamcenter {

    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$PartFile
    )

    $sourcePartCode =
    $PartFile.BaseName

    $originalFolder =
    $PartFile.Directory.Parent.FullName

    $originalSolidWorksFile =
    Get-ChildItem `
        -LiteralPath $originalFolder `
        -Filter "*.SLDPRT" `
        -File |
    Select-Object -First 1

    $itemDescription = $null

    if ($null -ne $originalSolidWorksFile) {

        if ($originalSolidWorksFile.BaseName -match '#(.*?)#') {

            $itemDescription =
            $Matches[1]
        }
    }

    Write-Host ""

    Write-Info `
        -Message "Processing: $($PartFile.Name)"

    $teamcenterDestination =
    New-NextTeamcenterItem `
        -SourceCode $sourcePartCode `
        -CompanyCode $companyCode `
        -ItemType $itemType

    if ($null -eq $teamcenterDestination) {

        throw `
            "Teamcenter destination was not returned for '$sourcePartCode'."
    }

    $teamcenterCode =
    $teamcenterDestination.Code

    $teamcenterItem =
    $teamcenterDestination.Item

    if ($null -eq $teamcenterItem) {

        throw `
            "Teamcenter item was not returned for '$teamcenterCode'."
    }

    $teamcenterRevision =
    Get-TeamcenterRevision `
        -Item $teamcenterItem

    if (-not [string]::IsNullOrWhiteSpace($itemDescription)) {

        $itemProperties =
        New-Object `
            "System.Collections.Generic.Dictionary``2[System.String,System.String]"

        $itemProperties.Add(
            "object_name",
            $itemDescription
        )

        [ImportarGD.Controller.Functions]::setProperty(
            $teamcenterItem,
            $itemProperties
        )

        $revisionProperties =
        New-Object `
            "System.Collections.Generic.Dictionary``2[System.String,System.String]"

        $revisionProperties.Add(
            "object_name",
            $itemDescription
        )

        [ImportarGD.Controller.Functions]::setProperty(
            $teamcenterRevision,
            $revisionProperties
        )

        $revisionProperties =
        New-Object `
            "System.Collections.Generic.Dictionary``2[System.String,System.String]"

        $revisionProperties.Add(
            "gd5DescReduzida",
            $itemDescription
        )

        $revisionProperties.Add(
            "gd5descEspec",
            $itemDescription
        )

        [ImportarGD.Controller.Functions]::setProperty(
            $teamcenterRevision,
            $revisionProperties
        )
    }

    if ($null -eq $teamcenterRevision) {

        throw `
            "Teamcenter revision was not found for '$teamcenterCode'."
    }
    $importResult =
    Import-TeamcenterPrt `
        -Revision $teamcenterRevision `
        -ItemCode $teamcenterCode `
        -FilePath $PartFile.FullName


    Write-Success `
        -Message "PRT imported: $teamcenterCode"

    Write-Info `
        -Message "Import result: $importResult"

    return [PSCustomObject]@{
        SourceFile     = $PartFile.FullName
        SourcePartCode = $sourcePartCode
        TeamcenterCode = $teamcenterCode
        ImportResult   = $importResult
    }
}


# ============================================================
# MAIN EXECUTION
# ============================================================

try {

    Write-Section `
        -Title "TEAMCENTER CONNECTION"

    Connect-Teamcenter

    Write-Success `
        -Message "Teamcenter connection established."

    Write-Section `
        -Title "NX FILE VALIDATION"

    $nxPartFiles =
    @(
        Get-NxPartFiles `
            -FolderPath $PastaNx
    )

    Write-Success `
        -Message "$($nxPartFiles.Count) PRT file(s) found."

    Write-Info `
        -Message "NX folder: $PastaNx"

    Write-Section `
        -Title "TEAMCENTER IMPORT"

    $importResults =
    [System.Collections.Generic.List[object]]::new()

    foreach ($nxPartFile in $nxPartFiles) {

        $importResult =
        Import-NxPartToTeamcenter `
            -PartFile $nxPartFile

        $importResults.Add(
            $importResult
        )
    }

    Write-Section `
        -Title "IMPORT RESULT"

    foreach ($result in $importResults) {

        Write-Success `
            -Message "$($result.SourcePartCode) -> $($result.TeamcenterCode)"
    }

    Write-Host ""

    Write-Success `
        -Message "Teamcenter import completed."

    Write-Info `
        -Message "Imported files: $($importResults.Count)"

    exit 0
}
catch {

    Write-Host ""

    Write-Failure `
        -Message $_.Exception.Message

    Write-Host ""
    Write-Host "[FULL ERROR]" -ForegroundColor DarkGray
    Write-Host $_.Exception.ToString() -ForegroundColor DarkGray
    Write-Host ""

    exit 1
}
