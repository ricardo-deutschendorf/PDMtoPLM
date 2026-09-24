# === PDM to PLM extraction workflow ===
Write-Host ""
Write-Host "=== NETWORK DRIVE SETUP ===" -ForegroundColor Cyan
Write-Host "[1/2] Cleaning previous Q: mapping..." -ForegroundColor DarkGray
& net.exe use Q: /delete /yes *> $null
Write-Host "[2/2] Connecting Q: to \\perto38-novo\NX_Custom..." -ForegroundColor DarkGray
& net.exe use Q: \\perto38-novo\NX_Custom
Write-Host "[OK] Q: drive is ready." -ForegroundColor Green

$ErrorActionPreference = "Stop"

$pdmLibraryPath =
"C:\Perto\Templates\CodAplic\Interop.EdmLib.dll"

$vaultName =
"Perto"

$vaultCredentialPath =
Join-Path  $PSScriptRoot  "vault_credentials.xml"

$downloadRootPath =
"C:\temp\importados"

$runJournalPath = "C:\Siemens\NX2312\NXBIN\run_journal.exe"

$importSwLibraryPath =
"\\perto38-novo\NX_Custom\ImportSW2NX.dll"

$companyName =
"Perto"

$nxLogPath =
"C:\temp\wrapper_silent_log.txt"

$temporaryWrapperPath =
Join-Path  $env:TEMP  "PDMtoPLM_wrapper.vb"

$teamcenterFunctionsPath =
Join-Path $PSScriptRoot "functions\teamcenter_functions.ps1"

if (-not (
        Test-Path -LiteralPath $teamcenterFunctionsPath -PathType Leaf
    )) {

    throw "teamcenter_functions.ps1 not found at '$teamcenterFunctionsPath'."
}

. $teamcenterFunctionsPath

. (Join-Path $PSScriptRoot "functions\load_archives.ps1")

try {

    Test-Environment

    $itemTargetSelection =
    Select-TeamcenterItemTarget

    $pdmVault =
    Connect-PdmVault

    if ($itemTargetSelection.ItemAlreadyExists) {

        Write-Section `
            -Title "PDM SOURCE DOCUMENT"

        Write-Info `
            -Message (
            "O codigo Teamcenter '$($itemTargetSelection.ExistingItemCode)' " +
            "sera usado somente como destino do 3D."
        )

        Write-Info `
            -Message "Agora informe o codigo-fonte do documento no PDM."
    }

    $partSelection =
    Select-PdmPartCode `
        -Vault $pdmVault

    $selectedPartCode =
    $partSelection.PartCode

    $pdmSearchResults =
    @(
        $partSelection.SearchResults
    )

    $partDownloadPath =
    Get-PartDownloadPath  -PartCode $selectedPartCode

    Copy-PdmFiles  -Vault $pdmVault  -SearchResults $pdmSearchResults  -DestinationPath $partDownloadPath

    $mainSolidWorksFile =
    Get-MainSolidWorksFile  -FolderPath $partDownloadPath  -PartCode $selectedPartCode

    $solidWorksDocument =
    Get-SolidWorksDocumentInfo  -MainFile $mainSolidWorksFile

    Write-Info  -Message "Main file: $($mainSolidWorksFile.Name)"

    Write-Section  -Title "SOLIDWORKS DOCUMENT TYPE"

    Write-Success  -Message "Tipo identificado: $($solidWorksDocument.Description)"

    Write-Info  -Message "DocumentType: $($solidWorksDocument.Type)"

    Write-Info  -Message "Extensao: $($mainSolidWorksFile.Extension)"

    $nxMigratedFolderPath =
    Invoke-NxConversion  -InputFolderPath $partDownloadPath

    $conversionResult =
    Show-ConversionResult  -NxFolderPath $nxMigratedFolderPath

    if ($solidWorksDocument.IsPart) {

        Confirm-PartNxNameFile `
            -SolidWorksFile $mainSolidWorksFile `
            -NxFolderPath $nxMigratedFolderPath `
            -NxPartFiles $conversionResult.PrtFiles
    }

    Write-Section  -Title "TESTES PRE-IMPORT"

    $posFile =
    Join-Path  $nxMigratedFolderPath  "Posicionamento.txt"

    if ($solidWorksDocument.IsPart) {

        Write-Success  -Message "Peca individual identificada."

        Write-Info  -Message "Posicionamento.txt nao e necessario."

        Write-Info  -Message "Somente o PRT sera enviado ao importador."
    }
    elseif ($solidWorksDocument.IsAssembly) {

        if (-not (
                Test-Path  -LiteralPath $posFile  -PathType Leaf
            )) {

            throw (
                "Montagem identificada, mas Posicionamento.txt " +
                "nao foi encontrado: $posFile"
            )
        }

        Write-Success  -Message "Montagem identificada."

        Write-Success  -Message "Posicionamento.txt encontrado."

        $children =
        [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        Get-Content  -LiteralPath $posFile  -Encoding Default |
        ForEach-Object {

            $parts =
            $_ -split '\|', 3

            if ($parts.Count -lt 2) {
                return
            }

            $child =
            $parts[1].Trim()

            if ([System.String]::IsNullOrWhiteSpace($child)) {
                return
            }

            $child =
            $child -replace '_\d+$', ''

            $null =
            $children.Add(
                $child
            )
        }

        Write-Host ""
        Write-Host "MONTAGEM:"
        Write-Host "  $selectedPartCode"

        Write-Host ""
        Write-Host "VIEW ESPERADA:"
        Write-Host ""

        $children |
        Sort-Object |
        ForEach-Object {
            Write-Host "  $_"
        }
    }
    else {

        throw  "Nao foi possivel identificar o tipo do documento SolidWorks."
    }
    if (
        $conversionResult.PrtFiles.Count -eq 0
    ) {

        throw  "No PRT file is available for Teamcenter import."
    }

    Invoke-TeamcenterImport `
        -NxFolderPath $nxMigratedFolderPath `
        -DocumentType $solidWorksDocument.Type `
        -ItemTargetMode $itemTargetSelection.Mode `
        -ExistingItemCode $itemTargetSelection.ExistingItemCode

    Write-Section  -Title "PROCESS COMPLETED"

    Write-Success  -Message "Processed part code: $selectedPartCode"

    Write-Info  -Message "NX output: $nxMigratedFolderPath"

    exit 0
}
catch {

    Write-Host ""

    Write-Failure  -Message $_.Exception.Message

    Write-Host ""
    Write-Host "[FULL ERROR]" -ForegroundColor DarkGray
    Write-Host $_.Exception.ToString() -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "Finalizando..."
    exit 1
}
finally {

    Remove-Variable  plainTextPassword  -ErrorAction SilentlyContinue
}