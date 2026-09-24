# === PDM vault functions ===

# Section: Validate the conversion environment
function Test-Environment {

    Write-Section  -Title "VALIDATING ENVIRONMENT"

    $requiredItems = @(
        @{
            Path = $pdmLibraryPath
            Name = "Interop.EdmLib.dll"
        },
        @{
            Path = $runJournalPath
            Name = "run_journal.exe"
        },
        @{
            Path = $importSwLibraryPath
            Name = "ImportSW2NX.dll"
        }
    )

    foreach ($requiredItem in $requiredItems) {

        if (-not (
                Test-Path -LiteralPath $requiredItem.Path
            )) {

            throw "$($requiredItem.Name) not found at '$($requiredItem.Path)'."
        }
    }

    if (-not (
            Test-Path -LiteralPath $vaultCredentialPath
        )) {

        Write-WarningMessage  -Message "Vault credential was not found."

        $credentialConfigurationScript =
        Join-Path  (Split-Path -Parent $PSScriptRoot)  "configure_vaultCredentials.ps1"

        if (-not (
                Test-Path -LiteralPath $credentialConfigurationScript
            )) {

            throw "configure_vaultCredentials.ps1 not found."
        }

        $credentialProcess =
        Start-Process  -FilePath "powershell.exe"  -ArgumentList @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            ('"' + $credentialConfigurationScript + '"')
        )  -Wait  -PassThru

        if ($credentialProcess.ExitCode -ne 0) {

            throw  "Vault credential configuration failed with code $($credentialProcess.ExitCode)."
        }

        if (-not (
                Test-Path -LiteralPath $vaultCredentialPath
            )) {

            throw "Vault credential file was not created."
        }
    }

    Add-Type  -Path $pdmLibraryPath

    if (-not (
            Test-Path -LiteralPath $downloadRootPath
        )) {

        New-Item  -ItemType Directory  -Path $downloadRootPath  -Force |
        Out-Null
    }

    Write-Success  -Message "Environment validated."
}

# Section: Connect to the PDM vault
function Connect-PdmVault {

    Write-Section  -Title "CONNECTING TO PDM VAULT"

    $credential =
    Import-Clixml  -LiteralPath $vaultCredentialPath

    if ($null -eq $credential) {
        throw "Vault credential file could not be loaded."
    }

    $securePassword =
    $credential.SenhaCriptografada |
    ConvertTo-SecureString

    $passwordPointer =
    [System.IntPtr]::Zero

    try {

        $passwordPointer =
        [Runtime.InteropServices.Marshal]::
        SecureStringToBSTR(
            $securePassword
        )

        $plainTextPassword =
        [Runtime.InteropServices.Marshal]::
        PtrToStringBSTR(
            $passwordPointer
        )

        $vault =
        New-Object EdmLib.EdmVault5Class

        $vault.Login(
            $credential.Usuario,
            $plainTextPassword,
            $vaultName
        )
    }
    finally {

        if (
            $passwordPointer -ne
            [System.IntPtr]::Zero
        ) {

            [Runtime.InteropServices.Marshal]::
            ZeroFreeBSTR(
                $passwordPointer
            )
        }

        Remove-Variable  plainTextPassword  -ErrorAction SilentlyContinue
    }

    if (-not $vault.IsLoggedIn) {

        throw  "Could not authenticate to vault '$vaultName'."
    }

    Write-Success  -Message "Connected to vault '$vaultName'."

    return $vault
}

# Section: Search PDM files
function Search-PdmFiles {

    param(
        [Parameter(Mandatory = $true)]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]$SearchText
    )

    $searchPattern =
    $SearchText.Replace(
        "*",
        "%"
    )

    if ($searchPattern -notmatch "%") {
        $searchPattern = "%$searchPattern%"
    }

    $search =
    $Vault.CreateSearch()

    $search.FileName =
    $searchPattern

    $search.FindHistoricStates =
    $false

    $searchResults =
    [System.Collections.Generic.List[object]]::new()

    if ($SearchText.Contains("*")) {
        Write-Host ""
        Write-Host "Pesquisando no Vault..." -ForegroundColor Yellow
    }

    $currentResult =
    $search.GetFirstResult()

    while ($null -ne $currentResult) {

        $searchResults.Add(
            $currentResult
        )

        $currentResult =
        $search.GetNextResult()
    }
    if ($SearchText.Contains("*")) {
        Write-Host "Pesquisa concluÃ­da." -ForegroundColor Green
    }

    return $searchResults.ToArray()
}

# Section: Select a PDM part code
function Select-PdmPartCode {

    param(
        [Parameter(Mandatory = $true)]
        $Vault
    )

    Write-Section  -Title "PDM DOCUMENT SEARCH"

    Write-Host "Part code example: 260.02.002"
    Write-Host "Wildcard example: 260.*"
    Write-Host ""

    while ($true) {

        $partCode =
        (
            Read-Host "Enter the part code"
        ).Trim()

        if ($partCode.Length -eq 0) {

            Write-WarningMessage  -Message "Part code cannot be empty."

            continue
        }

        $searchResults =
        @(
            Search-PdmFiles  -Vault $Vault  -SearchText $partCode
        )

        if ($searchResults.Count -eq 0) {

            Write-WarningMessage  -Message "No results were found."

            continue
        }

        $foundCodes =
        @(
            foreach ($searchResult in $searchResults) {

                $fileNameWithoutExtension =
                [System.IO.Path]::
                GetFileNameWithoutExtension(
                    $searchResult.Name
                )

                if (
                    $fileNameWithoutExtension -match
                    '\d+\.\d+\.\d+'
                ) {
                    $Matches[0]
                }
            }
        ) |
        Sort-Object -Unique

        if (-not $partCode.Contains("*")) {

            if ($foundCodes -contains $partCode) {

                return [PSCustomObject]@{
                    PartCode      = $partCode
                    SearchResults = $searchResults
                }
            }

            Write-WarningMessage  -Message "Exact part code was not found."

            continue
        }

        if ($foundCodes.Count -eq 0) {

            Write-WarningMessage  -Message "Files were found, but no valid part codes were identified."

            continue
        }

        Write-Section  -Title "PART CODES FOUND"

        foreach ($foundCode in $foundCodes) {
            Write-Host "  $foundCode"
        }

        Write-Host ""
    }
}

# Section: Resolve the local download path
function Get-PartDownloadPath {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PartCode
    )

    $safeFolderName =
    $PartCode

    foreach (
        $invalidCharacter in
        [System.IO.Path]::GetInvalidFileNameChars()
    ) {

        $safeFolderName =
        $safeFolderName.Replace(
            $invalidCharacter,
            "_"
        )
    }

    $partDownloadPath =
    Join-Path  $downloadRootPath  $safeFolderName

    if (-not (
            Test-Path -LiteralPath $partDownloadPath
        )) {

        New-Item  -ItemType Directory  -Path $partDownloadPath  -Force |
        Out-Null

        Write-Info  -Message "Folder created: $partDownloadPath"
    }

    return $partDownloadPath
}

# Section: Copy PDM files locally
function Copy-PdmFiles {

    param(
        [Parameter(Mandatory = $true)]
        $Vault,

        [Parameter(Mandatory = $true)]
        [object[]]$SearchResults,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Write-Section  -Title "DOWNLOADING PDM FILES"

    $copiedCount = 0
    $existingCount = 0
    $failureCount = 0

    foreach ($searchResult in $SearchResults) {

        try {

            $destinationFilePath =
            Join-Path  $DestinationPath  $searchResult.Name

            if (
                Test-Path -LiteralPath $destinationFilePath
            ) {

                Write-WarningMessage  -Message "Already downloaded: $($searchResult.Name)"

                $existingCount++
                continue
            }

            $parentFolder =
            $null

            $pdmFile =
            $Vault.GetFileFromPath(
                $searchResult.Path,
                [ref]$parentFolder
            )

            if ($null -eq $pdmFile) {

                throw  "Could not retrieve the file from the vault."
            }

            if ($null -eq $parentFolder) {

                throw  "Could not retrieve the parent folder from the vault."
            }

            $fileVersion =
            0

            $folderId =
            $parentFolder.ID

            $pdmFile.GetFileCopy(
                0,
                [ref]$fileVersion,
                [ref]$folderId,
                0,
                ""
            )

            $localCachePath =
            $pdmFile.GetLocalPath(
                $parentFolder.ID
            )

            if (-not (
                    Test-Path -LiteralPath $localCachePath
                )) {

                throw  "File was not found in the local PDM cache."
            }

            Copy-Item  -LiteralPath $localCachePath  -Destination $destinationFilePath

            Write-Success  -Message "Copied: $($searchResult.Name)"

            $copiedCount++
        }
        catch {

            Write-Failure  -Message "$($searchResult.Name) - $($_.Exception.Message)"

            $failureCount++
        }
    }

    Write-Host ""

    Write-Info  -Message "New files: $copiedCount"

    Write-Info  -Message "Existing files: $existingCount"

    Write-Info  -Message "Failures: $failureCount"

    if (
        $copiedCount -eq 0 -and
        $existingCount -eq 0
    ) {

        throw  "No files are available for NX conversion."
    }
}
