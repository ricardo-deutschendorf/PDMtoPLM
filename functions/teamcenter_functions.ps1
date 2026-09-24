# === Teamcenter integration helper functions ===

# Section: Establish the Teamcenter connection
# ============================================================
# TEAMCENTER IMPORTER AVAILABILITY
# Verifica se o Importar GD ja esta instalado localmente.
# Caso nao esteja, executa o instalador existente.
# ============================================================

function Confirm-TeamcenterImporter {

    $importerExecutablePath =
    "C:\Temp\ImportarGD\Importar GD.exe"

    if (
        Test-Path `
            -LiteralPath $importerExecutablePath `
            -PathType Leaf
    ) {

        Write-Host `
            "  [OK] Importar GD ja esta instalado." `
            -ForegroundColor Green

        Write-Host `
            "  -> $importerExecutablePath" `
            -ForegroundColor Gray

        return $importerExecutablePath
    }

    Write-Host `
        "  [WARNING] Importar GD nao foi encontrado localmente." `
        -ForegroundColor Yellow

    Write-Host `
        "  -> Iniciando instalacao automatica..." `
        -ForegroundColor Gray

    $projectRoot =
    Split-Path `
        -Parent $PSScriptRoot

    $installerScript =
    Join-Path `
        $projectRoot `
        "import_PLM.ps1"

    if (-not (
            Test-Path `
                -LiteralPath $installerScript `
                -PathType Leaf
        )) {

        throw `
            "Instalador do Importar GD nao encontrado: $installerScript"
    }

    $powerShell64Path =
    Join-Path `
        $env:WINDIR `
        "Sysnative\WindowsPowerShell\v1.0\powershell.exe"

    if (-not (
            Test-Path `
                -LiteralPath $powerShell64Path `
                -PathType Leaf
        )) {

        $powerShell64Path =
        Join-Path `
            $env:WINDIR `
            "System32\WindowsPowerShell\v1.0\powershell.exe"
    }

    if (-not (
            Test-Path `
                -LiteralPath $powerShell64Path `
                -PathType Leaf
        )) {

        throw `
            "Windows PowerShell 64-bit nao foi encontrado."
    }

    & $powerShell64Path `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $installerScript |
    Out-Host
    
    $installerExitCode =
    $LASTEXITCODE

    if ($installerExitCode -ne 0) {

        throw (
            "A instalacao automatica do Importar GD falhou. " +
            "Codigo de saida: $installerExitCode"
        )
    }

    if (-not (
            Test-Path `
                -LiteralPath $importerExecutablePath `
                -PathType Leaf
        )) {

        throw (
            "O instalador terminou sem erro, mas o executavel " +
            "nao foi encontrado em '$importerExecutablePath'."
        )
    }

    Write-Host `
        "  [OK] Importar GD instalado automaticamente." `
        -ForegroundColor Green

    Write-Host `
        "  -> $importerExecutablePath" `
        -ForegroundColor Gray

    return $importerExecutablePath
}
function Connect-Teamcenter {

    $importerExecutablePath =
    Confirm-TeamcenterImporter

    $teamcenterServerUrl =
    "http://perto37-novo.perto.com.br:8080/tc"

    if (-not (
            Test-Path  -LiteralPath $importerExecutablePath  -PathType Leaf
        )) {

        throw  "Teamcenter importer executable not found at '$importerExecutablePath'."
    }

    $script:ImporterAssembly =
    [System.Reflection.Assembly]::LoadFrom(
        $importerExecutablePath
    )

    if ($null -eq $script:ImporterAssembly) {

        throw  "Teamcenter importer assembly could not be loaded."
    }

    $sessionType =
    $script:ImporterAssembly.GetType(
        "Teamcenter.ClientX.Session"
    )

    if ($null -eq $sessionType) {

        throw  "Teamcenter.ClientX.Session type was not found."
    }

    $script:TeamcenterSession =
    [System.Activator]::CreateInstance(
        $sessionType,
        @(
            $teamcenterServerUrl
        )
    )

    if ($null -eq $script:TeamcenterSession) {

        throw  "Teamcenter session returned NULL."
    }

    $authenticatedUser =
    $script:TeamcenterSession.login(
        "infodba",
        "infodba",
        "",
        "",
        "SoaAppX"
    )

    if ($null -eq $authenticatedUser) {

        throw  "Teamcenter login returned NULL."
    }

    $script:TeamcenterFunctions =
    $script:ImporterAssembly.GetType(
        "ImportarGD.Controller.Functions"
    )

    if ($null -eq $script:TeamcenterFunctions) {

        throw  "ImportarGD.Controller.Functions type was not found."
    }

    return $script:TeamcenterSession
}


# Section: Resolve a Teamcenter API method
function Get-TeamcenterMethod {

    param(
        [Parameter(Mandatory = $true)]
        [string]$MethodName,

        [Parameter(Mandatory = $true)]
        [int]$ParameterCount
    )

    if ($null -eq $script:TeamcenterFunctions) {

        throw  "Teamcenter functions are not loaded. Run Connect-Teamcenter first."
    }

    $method =
    $script:TeamcenterFunctions.GetMethods() |
    Where-Object {
        $_.Name -eq $MethodName -and
        $_.GetParameters().Count -eq $ParameterCount
    } |
    Select-Object -First 1

    if ($null -eq $method) {

        throw  "Teamcenter method '$MethodName' with $ParameterCount parameter(s) was not found."
    }

    return $method
}



# Section: Retrieve a Teamcenter revision
function Get-TeamcenterRevision {

    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    if ($null -eq $Item) {

        throw  "Teamcenter item was not provided."
    }

    $getRevisionMethod =
    Get-TeamcenterMethod  -MethodName "getItemRevisionfromItem"  -ParameterCount 1

    $revision =
    $getRevisionMethod.Invoke(
        $null,
        @(
            $Item
        )
    )

    return $revision
}



# Section: Retrieve a Teamcenter item
function Get-TeamcenterItem {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [string]$CompanyCode = "02"
    )

    $getItemMethod =
    Get-TeamcenterMethod  -MethodName "getItem"  -ParameterCount 2

    $item =
    $getItemMethod.Invoke(
        $null,
        @(
            $ItemCode,
            $CompanyCode
        )
    )

    return $item
}



# Section: Create the next Teamcenter item
function New-NextTeamcenterItem {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceCode,

        [string]$CompanyCode = "02",

        [string]$ItemType = "GD5DesignPerto",

        [ValidateRange(1, 10000)]
        [int]$MaximumAttempts = 100
    )

    if ($SourceCode -match '^(.*)-(\d+)$') {

        $baseCode =
        $Matches[1]
    }
    else {

        $baseCode =
        $SourceCode
    }

    $getItemMethod =
    Get-TeamcenterMethod  -MethodName "getItem"  -ParameterCount 2

    $createItemMethod =
    Get-TeamcenterMethod  -MethodName "criarItem"  -ParameterCount 3

    for (
        $attempt = 0
        $attempt -le $MaximumAttempts
        $attempt++
    ) {

        if ($attempt -eq 0) {

            $candidateCode =
            $baseCode
        }
        else {

            $candidateCode =
            "$baseCode-$attempt"
        }

        Write-Host "Checking: $candidateCode"

        $existingItem =
        $getItemMethod.Invoke(
            $null,
            @(
                $candidateCode,
                $CompanyCode
            )
        )

        if ($null -ne $existingItem) {

            Write-Host  "[WARNING] Item already exists: $candidateCode"  -ForegroundColor Yellow

            continue
        }

        Write-Host  "[INFO] Creating item: $candidateCode"  -ForegroundColor Gray

        $createdItem =
        $createItemMethod.Invoke(
            $null,
            @(
                $candidateCode,
                $ItemType,
                $CompanyCode
            )
        )

        if ($null -eq $createdItem) {

            continue
        }

        Write-Host  "[OK] Item created: $candidateCode"  -ForegroundColor Green

        return [PSCustomObject]@{
            Code = $candidateCode
            Item = $createdItem
        }
    }

    throw  "Could not create a Teamcenter item after $MaximumAttempts attempts."
}


# Section: Import a dataset into Teamcenter
function Import-TeamcenterDataset {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "ImportarPrt",
            "ImportarJT",
            "ImportarDWG"
        )]
        [string]$ImporterMethod
    )

    if ($null -eq $Revision) {

        throw  "Teamcenter revision was not provided for '$ItemCode'."
    }

    if (-not (
            Test-Path  -LiteralPath $FilePath  -PathType Leaf
        )) {

        throw  "Import file not found at '$FilePath'."
    }

    $importMethod =
    Get-TeamcenterMethod  -MethodName $ImporterMethod  -ParameterCount 5

    $importResult =
    $importMethod.Invoke(
        $null,
        @(
            $ItemCode,
            "",
            $FilePath,
            $Revision,
            $true
        )
    )

    return $importResult
}



# Section: Import a PRT file
function Import-TeamcenterPrt {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    return Import-TeamcenterDataset  -Revision $Revision  -ItemCode $ItemCode  -FilePath $FilePath  -ImporterMethod "ImportarPrt"
}



# Section: Import a JT file
function Import-TeamcenterJt {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    return Import-TeamcenterDataset  -Revision $Revision  -ItemCode $ItemCode  -FilePath $FilePath  -ImporterMethod "ImportarJT"
}


# Section: Import a DWG file
function Import-TeamcenterDwg {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    return Import-TeamcenterDataset  -Revision $Revision  -ItemCode $ItemCode  -FilePath $FilePath  -ImporterMethod "ImportarDWG"
}

# Section: Close any leftover BOM window
function Close-LeftoverBomWindow {

    param(
        [Parameter(Mandatory = $true)]
        $Revision
    )

    $openBomMethod =
    Get-TeamcenterMethod  -MethodName "openBOMWindow"  -ParameterCount 1

    $closeBomMethod =
    Get-TeamcenterMethod  -MethodName "closeBOMWindow"  -ParameterCount 1

    try {

        $windowResult =
        $openBomMethod.Invoke(
            $null,
            @(
                $Revision
            )
        )

        if ($null -ne $windowResult -and $windowResult.Count -gt 0) {

            $closeBomMethod.Invoke(
                $null,
                @(
                    $windowResult[0]
                )
            )

            Write-Host  "  [OK] BOM window fechada (safety net)."  -ForegroundColor Green
        }
    }
    catch {

        Write-Host  "  [AVISO] Falha ao confirmar fechamento de BOM window: $($_.Exception.Message)"  -ForegroundColor Yellow
    }
}


# Section: Add BOM children safely
function Add-TeamcenterBomChildrenSafe {

    param(
        [Parameter(Mandatory = $true)]
        $ParentRevision,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[Teamcenter.Soa.Client.Model.Strong.ItemRevision]]$ChildRevisions
    )

    $openBomMethod = Get-TeamcenterMethod -MethodName "openBOMWindow"  -ParameterCount 1
    $saveBomMethod = Get-TeamcenterMethod -MethodName "saveBOMWindow"  -ParameterCount 1
    $closeBomMethod = Get-TeamcenterMethod -MethodName "closeBOMWindow" -ParameterCount 1

    $windowResult = $openBomMethod.Invoke($null, @($ParentRevision))
    $bomWindow = $windowResult[0]
    $parentLine = $windowResult[1]

    $connection = [Teamcenter.ClientX.Session]::getConnection()
    $dmService = [Teamcenter.Services.Strong.Core.DataManagementService]::getService($connection)
    $structService = [Teamcenter.Services.Strong.Bom.StructureManagementService]::getService($connection)

    try {

        $itemLines = @()
        foreach ($childRev in $ChildRevisions) {
            $lineInfo = New-Object Teamcenter.Services.Strong.Bom.ItemLineInfo
            $lineInfo.ItemRev = $childRev
            $itemLines += $lineInfo
        }

        $parentInfo = New-Object Teamcenter.Services.Strong.Bom.AddOrUpdateChildrenToParentLineInfo
        $parentInfo.Items = $itemLines
        $parentInfo.ParentLine = $parentLine

        $response = $structService.AddOrUpdateChildrenToParentLine(@($parentInfo))

        $newBomline = $response.ItemLines[0].Bomline

        $dmService.GetProperties(@($newBomline), @("bl_child_lines")) | Out-Null

        if ($newBomline.Bl_child_lines.Length -ne 0) {

            $transformProps = New-Object 'System.Collections.Hashtable'
            $vecStruct = New-Object Teamcenter.Soa.Client.Model.VecStruct
            $vecStruct.StringVec = @("1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1")
            $transformProps.Add("bl_plmxml_occ_xform", $vecStruct)

            $dmService.SetProperties(@($newBomline), $transformProps) | Out-Null
        }

        $saveBomMethod.Invoke($null, @($bomWindow))

        return $newBomline
    }
    finally {

        $closeBomMethod.Invoke($null, @($bomWindow))
    }
}