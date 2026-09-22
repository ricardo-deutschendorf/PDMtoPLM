# ============================================================
# TEAMCENTER INTEGRATION FUNCTIONS
# Provides connection, item creation, revision retrieval
# and dataset import functions.
# ============================================================


# ============================================================
# TEAMCENTER CONNECTION
# ============================================================

function Connect-Teamcenter {

    $importerExecutablePath =
    "C:\Temp\ImportarGD\Importar GD.exe"

    $teamcenterServerUrl =
    "http://perto37-novo.perto.com.br:8080/tc"

    Write-Host "TC 1 - Loading importer assembly"

    if (-not (
            Test-Path `
                -LiteralPath $importerExecutablePath `
                -PathType Leaf
        )) {

        throw `
            "Teamcenter importer executable not found at '$importerExecutablePath'."
    }

    $script:ImporterAssembly =
    [System.Reflection.Assembly]::LoadFrom(
        $importerExecutablePath
    )

    if ($null -eq $script:ImporterAssembly) {

        throw `
            "Teamcenter importer assembly could not be loaded."
    }

    Write-Host "TC 2 - Locating Teamcenter session type"

    $sessionType =
    $script:ImporterAssembly.GetType(
        "Teamcenter.ClientX.Session"
    )

    if ($null -eq $sessionType) {

        throw `
            "Teamcenter.ClientX.Session type was not found."
    }

    Write-Host "TC 3 - Creating Teamcenter session"

    $script:TeamcenterSession =
    [System.Activator]::CreateInstance(
        $sessionType,
        @(
            $teamcenterServerUrl
        )
    )

    if ($null -eq $script:TeamcenterSession) {

        throw `
            "Teamcenter session returned NULL."
    }

    Write-Host "TC 4 - Authenticating"

    $authenticatedUser =
    $script:TeamcenterSession.login(
        "infodba",
        "infodba",
        "",
        "",
        "SoaAppX"
    )

    if ($null -eq $authenticatedUser) {

        throw `
            "Teamcenter login returned NULL."
    }

    Write-Host "TC 5 - Locating importer functions"

    $script:TeamcenterFunctions =
    $script:ImporterAssembly.GetType(
        "ImportarGD.Controller.Functions"
    )

    $methodNames = @(
        "NewBomviewRevision",
        "openBOMWindow",
        "Load_Bom_Lines",
        "addAllChildrenInBOM",
        "updateBomLine",
        "saveBOMWindow",
        "closeBOMWindow"
    )

    foreach ($methodName in $methodNames) {
        Write-Host ""
        Write-Host "===================================="
        Write-Host $methodName
        Write-Host "===================================="

        $methods =
        $script:TeamcenterFunctions.GetMethods() |
        Where-Object {
            $_.Name -eq $methodName
        }

        foreach ($method in $methods) {
            Write-Host ""
            Write-Host "Overload:"

            Write-Host "RETORNO:"
            Write-Host $method.ReturnType.FullName

            Write-Host ""
            Write-Host "PARAMETROS:"

            foreach ($param in $method.GetParameters()) {
                Write-Host (
                    $param.ParameterType.FullName +
                    " " +
                    $param.Name
                )
            }
        }
    }
    
    $script:TeamcenterFunctions.GetMethods() |
    Sort-Object Name |
    Select-Object Name -Unique |
    ForEach-Object {
        Write-Host $_.Name
    }

    if ($null -eq $script:TeamcenterFunctions) {

        throw `
            "ImportarGD.Controller.Functions type was not found."
    }

    Write-Host "TC 6 - Teamcenter connection established"

    return $script:TeamcenterSession
}

# ============================================================
# TEAMCENTER METHOD LOOKUP
# ============================================================

function Get-TeamcenterMethod {

    param(
        [Parameter(Mandatory = $true)]
        [string]$MethodName,

        [Parameter(Mandatory = $true)]
        [int]$ParameterCount
    )

    if ($null -eq $script:TeamcenterFunctions) {

        throw `
            "Teamcenter functions are not loaded. Run Connect-Teamcenter first."
    }

    $method =
    $script:TeamcenterFunctions.GetMethods() |
    Where-Object {
        $_.Name -eq $MethodName -and
        $_.GetParameters().Count -eq $ParameterCount
    } |
    Select-Object -First 1

    if ($null -eq $method) {

        throw `
            "Teamcenter method '$MethodName' with $ParameterCount parameter(s) was not found."
    }

    return $method
}


# ============================================================
# ITEM REVISION
# ============================================================

function Get-TeamcenterRevision {

    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    if ($null -eq $Item) {

        throw `
            "Teamcenter item was not provided."
    }

    $getRevisionMethod =
    Get-TeamcenterMethod `
        -MethodName "getItemRevisionfromItem" `
        -ParameterCount 1

    $revision =
    $getRevisionMethod.Invoke(
        $null,
        @(
            $Item
        )
    )

    return $revision
}


# ============================================================
# TEAMCENTER ITEM LOOKUP
# ============================================================

function Get-TeamcenterItem {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [string]$CompanyCode = "02"
    )

    $getItemMethod =
    Get-TeamcenterMethod `
        -MethodName "getItem" `
        -ParameterCount 2

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


# ============================================================
# NEXT AVAILABLE ITEM
# ============================================================

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
    Get-TeamcenterMethod `
        -MethodName "getItem" `
        -ParameterCount 2

    $createItemMethod =
    Get-TeamcenterMethod `
        -MethodName "criarItem" `
        -ParameterCount 3

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

            Write-Host `
                "[WARNING] Item already exists: $candidateCode" `
                -ForegroundColor Yellow

            continue
        }

        Write-Host `
            "[INFO] Creating item: $candidateCode" `
            -ForegroundColor Gray

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

        Write-Host `
            "[OK] Item created: $candidateCode" `
            -ForegroundColor Green

        return [PSCustomObject]@{
            Code = $candidateCode
            Item = $createdItem
        }
    }

    throw `
        "Could not create a Teamcenter item after $MaximumAttempts attempts."
}

# ============================================================
# GENERIC DATASET IMPORT
# ============================================================

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

        throw `
            "Teamcenter revision was not provided for '$ItemCode'."
    }

    if (-not (
            Test-Path `
                -LiteralPath $FilePath `
                -PathType Leaf
        )) {

        throw `
            "Import file not found at '$FilePath'."
    }

    $importMethod =
    Get-TeamcenterMethod `
        -MethodName $ImporterMethod `
        -ParameterCount 5

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


# ============================================================
# PRT IMPORT
# ============================================================

function Import-TeamcenterPrt {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    return Import-TeamcenterDataset `
        -Revision $Revision `
        -ItemCode $ItemCode `
        -FilePath $FilePath `
        -ImporterMethod "ImportarPrt"
}


# ============================================================
# JT IMPORT
# ============================================================

function Import-TeamcenterJt {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    return Import-TeamcenterDataset `
        -Revision $Revision `
        -ItemCode $ItemCode `
        -FilePath $FilePath `
        -ImporterMethod "ImportarJT"
}

# ============================================================
# DWG IMPORT
# ============================================================

function Import-TeamcenterDwg {

    param(
        [Parameter(Mandatory = $true)]
        $Revision,

        [Parameter(Mandatory = $true)]
        [string]$ItemCode,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    return Import-TeamcenterDataset `
        -Revision $Revision `
        -ItemCode $ItemCode `
        -FilePath $FilePath `
        -ImporterMethod "ImportarDWG"
}
# ============================================================
# BOM WINDOW SAFETY NET
# Garante que nenhuma BOM window fica presa no servidor,
# mesmo se addAllChildrenInBOM falhar internamente (a DLL
# engole exceções de save/close e não avisa o chamador).
# ============================================================

function Close-LeftoverBomWindow {

    param(
        [Parameter(Mandatory = $true)]
        $Revision
    )

    $openBomMethod =
    Get-TeamcenterMethod `
        -MethodName "openBOMWindow" `
        -ParameterCount 1

    $closeBomMethod =
    Get-TeamcenterMethod `
        -MethodName "closeBOMWindow" `
        -ParameterCount 1

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

            Write-Host `
                "  [OK] BOM window fechada (safety net)." `
                -ForegroundColor Green
        }
    }
    catch {

        Write-Host `
            "  [AVISO] Falha ao confirmar fechamento de BOM window: $($_.Exception.Message)" `
            -ForegroundColor Yellow
    }
}

# ============================================================
# SUBSTITUI addAllChildrenInBOM (bug: nao forca carregamento
# de bl_child_lines antes de le-lo, e trava com excecao)
# ============================================================

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

        # FORCA o carregamento de bl_child_lines ANTES de ler (fix do bug)
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