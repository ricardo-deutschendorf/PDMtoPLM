# === Teamcenter integration helper functions ===

# Section: Establish the Teamcenter connection
. (Join-Path $PSScriptRoot "environment_functions.ps1")
Import-ProjectEnvironment -ProjectRoot (Split-Path $PSScriptRoot -Parent)

# ============================================================
# TEAMCENTER IMPORTER AVAILABILITY
# Verifica se o Importar GD ja esta instalado localmente.
# Caso nao esteja, executa o instalador existente.
# ============================================================

function Confirm-TeamcenterImporter {

    $importerExecutablePath = $env:TEAMCENTER_IMPORTER_EXECUTABLE

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
function Get-TeamcenterSettings {

    $teamcenterEnvironment = [string]$env:TEAMCENTER_ENV

    if ([string]::IsNullOrWhiteSpace($teamcenterEnvironment)) {

        throw "TEAMCENTER_ENV nao foi configurado no arquivo .env."
    }

    switch ($teamcenterEnvironment.Trim().ToLowerInvariant()) {

        "teste" {

            $teamcenterEnvironment = "Teste"
            $teamcenterServerUrl = [string]$env:TEAMCENTER_TEST_URL
            $expectedHost = [string]$env:TEAMCENTER_TEST_EXPECTED_HOST
            $teamcenterUser = [string]$env:TEAMCENTER_TEST_USER
            $teamcenterPassword = [string]$env:TEAMCENTER_TEST_PASSWORD
            $companyCode = [string]$env:TEAMCENTER_TEST_COMPANY_CODE
            $itemType = [string]$env:TEAMCENTER_TEST_ITEM_TYPE
            $companyCodeSetting = "TEAMCENTER_TEST_COMPANY_CODE"
            $itemTypeSetting = "TEAMCENTER_TEST_ITEM_TYPE"
        }

        "processo" {

            $teamcenterEnvironment = "Processo"
            $teamcenterServerUrl = [string]$env:TEAMCENTER_PROCESS_URL
            $expectedHost = [string]$env:TEAMCENTER_PROCESS_EXPECTED_HOST
            $teamcenterUser = [string]$env:TEAMCENTER_PROCESS_USER
            $teamcenterPassword = [string]$env:TEAMCENTER_PROCESS_PASSWORD
            $companyCode = [string]$env:TEAMCENTER_PROCESS_COMPANY_CODE
            $itemType = [string]$env:TEAMCENTER_PROCESS_ITEM_TYPE
            $companyCodeSetting = "TEAMCENTER_PROCESS_COMPANY_CODE"
            $itemTypeSetting = "TEAMCENTER_PROCESS_ITEM_TYPE"
        }

        default {

            throw (
                "Ambiente Teamcenter invalido: '$teamcenterEnvironment'. " +
                "Use Teste ou Processo."
            )
        }
    }

    foreach ($setting in @(
            @{ Name = "URL"; Value = $teamcenterServerUrl },
            @{ Name = "servidor esperado"; Value = $expectedHost },
            @{ Name = "usuario"; Value = $teamcenterUser },
            @{ Name = $companyCodeSetting; Value = $companyCode },
            @{ Name = $itemTypeSetting; Value = $itemType }
        )) {

        if ([string]::IsNullOrWhiteSpace([string]$setting.Value)) {

            throw (
                "A configuracao de $($setting.Name) nao foi preenchida " +
                "para o ambiente '$teamcenterEnvironment' no .env."
            )
        }
    }

    $parsedUri = $null

    if (-not [System.Uri]::TryCreate(
            $teamcenterServerUrl.Trim(),
            [System.UriKind]::Absolute,
            [ref]$parsedUri
        )) {

        throw "URL invalida para o ambiente '$teamcenterEnvironment'."
    }

    if (
        $parsedUri.Scheme -notin @("http", "https") -or
        $parsedUri.Host -ine $expectedHost
    ) {

        throw (
            "A URL configurada nao corresponde ao ambiente " +
            "'$teamcenterEnvironment'. Servidor esperado: " +
            "'$expectedHost'; servidor recebido: '$($parsedUri.Host)'."
        )
    }

    if ([string]::IsNullOrWhiteSpace($teamcenterPassword)) {

        $securePassword = Read-Host `
            "Senha do Teamcenter para '$teamcenterUser' ($teamcenterEnvironment)" `
            -AsSecureString

        $teamcenterPassword = [System.Net.NetworkCredential]::new(
            "",
            $securePassword
        ).Password
    }

    if ([string]::IsNullOrWhiteSpace($teamcenterPassword)) {

        throw "A senha do Teamcenter nao foi informada."
    }

    return [PSCustomObject]@{
        Environment = $teamcenterEnvironment
        Url = $teamcenterServerUrl.Trim()
        User = $teamcenterUser.Trim()
        Password = $teamcenterPassword
        CompanyCode = $companyCode.Trim()
        ItemType = $itemType.Trim()
    }
}

function Connect-Teamcenter {

    $importerExecutablePath =
    Confirm-TeamcenterImporter

    $settings = Get-TeamcenterSettings

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
            $settings.Url
        )
    )

    if ($null -eq $script:TeamcenterSession) {

        throw  "Teamcenter session returned NULL."
    }

    $teamcenterGroup = [string]$env:TEAMCENTER_GROUP
    $teamcenterRole = [string]$env:TEAMCENTER_ROLE
    $script:TeamcenterEnvironment = $settings.Environment
    $script:TeamcenterCompanyCode = $settings.CompanyCode
    $script:TeamcenterItemType = $settings.ItemType

    $authenticatedUser =
    $script:TeamcenterSession.login(
        $settings.User,
        $settings.Password,
        $teamcenterGroup,
        $teamcenterRole,
        $env:TEAMCENTER_APPLICATION
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

        [string]$CompanyCode
    )

    if ([string]::IsNullOrWhiteSpace($CompanyCode)) {

        $CompanyCode = [string]$script:TeamcenterCompanyCode
    }

    if ([string]::IsNullOrWhiteSpace($CompanyCode)) {

        throw "CompanyCode nao foi configurado para o ambiente Teamcenter ativo."
    }

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

        [string]$CompanyCode,

        [string]$ItemType,

        [switch]$ReuseExisting,

        [ValidateRange(1, 10000)]
        [int]$MaximumAttempts = 100
    )

    if ([string]::IsNullOrWhiteSpace($CompanyCode)) {

        $CompanyCode = [string]$script:TeamcenterCompanyCode
    }

    if ([string]::IsNullOrWhiteSpace($ItemType)) {

        $ItemType = [string]$script:TeamcenterItemType
    }

    if (
        [string]::IsNullOrWhiteSpace($CompanyCode) -or
        [string]::IsNullOrWhiteSpace($ItemType)
    ) {

        throw "CompanyCode e ItemType devem estar configurados para o ambiente Teamcenter ativo."
    }

    if (-not $ReuseExisting -and $SourceCode -match '^(.*)-(\d+)$') {

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

            if ($ReuseExisting -and $attempt -eq 0) {

                Write-Host  "[INFO] Reusing existing item: $candidateCode"  -ForegroundColor Gray

                return [PSCustomObject]@{
                    Code = $candidateCode
                    Item = $existingItem
                }
            }

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

        $null =
        $saveBomMethod.Invoke(
            $null,
            @(
                $bomWindow
            )
        )

        return $newBomline
    }
    finally {

        $null =
        $closeBomMethod.Invoke(
            $null,
            @(
                $bomWindow
            )
        )
    }
}

function Get-TeamcenterBomOccurrenceKey {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ItemCode,

        [AllowEmptyString()]
        [string]$Transform
    )

    $normalizedTransform =
    [System.Text.RegularExpressions.Regex]::Replace(
        ([string]$Transform).Trim(),
        '\s+',
        ' '
    )

    return "$($ItemCode.Trim())|$normalizedTransform"
}

function Get-TeamcenterBomOccurrenceKeys {

    param(
        [Parameter(Mandatory = $true)]
        $ParentRevision
    )

    $occurrenceKeys =
    [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $openBomMethod =
    Get-TeamcenterMethod -MethodName "openBOMWindow" -ParameterCount 1

    $closeBomMethod =
    Get-TeamcenterMethod -MethodName "closeBOMWindow" -ParameterCount 1

    $windowResult =
    $openBomMethod.Invoke(
        $null,
        @(
            $ParentRevision
        )
    )

    if ($null -eq $windowResult -or $windowResult.Count -lt 2) {

        throw "BOM window could not be opened to inspect existing occurrences."
    }

    $bomWindow = $windowResult[0]
    $parentLine = $windowResult[1]

    try {

        $connection =
        [Teamcenter.ClientX.Session]::getConnection()

        $dmService =
        [Teamcenter.Services.Strong.Core.DataManagementService]::getService(
            $connection
        )

        $dmService.GetProperties(
            @($parentLine),
            @("bl_child_lines")
        ) | Out-Null

        $childLines =
        @($parentLine.Bl_child_lines)

        if ($childLines.Count -eq 0) {
            return ,$occurrenceKeys
        }

        $dmService.GetProperties(
            $childLines,
            @(
                "bl_item",
                "bl_plmxml_occ_xform"
            )
        ) | Out-Null

        $childItems =
        [System.Collections.Generic.List[object]]::new()

        foreach ($childLine in $childLines) {

            $itemProperty =
            $childLine.getPropertyObject("bl_item")

            if ($null -eq $itemProperty) {
                throw "Existing BOM line has no bl_item property."
            }

            $childItem =
            $itemProperty.getModelObjectValue()

            if ($null -eq $childItem) {
                throw "Existing BOM line has no child item."
            }

            $childItems.Add($childItem)
        }

        $dmService.GetProperties(
            $childItems.ToArray(),
            @("item_id")
        ) | Out-Null

        for ($index = 0; $index -lt $childLines.Count; $index++) {

            $itemIdProperty =
            $childItems[$index].getPropertyObject("item_id")

            if ($null -eq $itemIdProperty) {
                throw "Existing BOM child item has no item_id property."
            }

            $childItemCode =
            [string]$itemIdProperty.getStringValue()

            $transformProperty =
            $childLines[$index].getPropertyObject("bl_plmxml_occ_xform")

            $transformValues =
            if ($null -eq $transformProperty) {
                @()
            }
            else {
                @($transformProperty.getStringValueArray())
            }

            $transform =
            ($transformValues | ForEach-Object { [string]$_ }) -join ' '

            $occurrenceKey =
            Get-TeamcenterBomOccurrenceKey `
                -ItemCode $childItemCode `
                -Transform $transform

            [void]$occurrenceKeys.Add($occurrenceKey)
        }

        return ,$occurrenceKeys
    }
    finally {

        $null =
        $closeBomMethod.Invoke(
            $null,
            @(
                $bomWindow
            )
        )
    }
}

function Resolve-TeamcenterCatalogItem {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$NomeGenerico
    )

    # restante da funcao
}