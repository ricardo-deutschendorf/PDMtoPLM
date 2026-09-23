param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PastaNx,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "Part",
        "Assembly"
    )]
    [string]$DocumentType
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

$nxNamesFile =
Join-Path `
    $PastaNx `
    "NomesNx.txt"

$nxNames =
@{}

if (-not (
        Test-Path `
            -LiteralPath $nxNamesFile `
            -PathType Leaf
    )) {

    throw `
        "NomesNx.txt nao encontrado: $nxNamesFile"
}

Get-Content `
    -LiteralPath $nxNamesFile `
    -Encoding UTF8 |
ForEach-Object {

    $parts =
    $_ -split '\|', 2

    if ($parts.Count -ne 2) {
        return
    }

    $fileCode =
    $parts[0].Trim()

    if ($fileCode -match '^(.+)_\d+$') {
        $fileCode =
        $Matches[1]
    }

    $attributeValue =
    $parts[1].Trim()

    $itemDescription =
    $attributeValue

    if ($attributeValue -match '^[^#]+#(.*?)#?$') {
        $itemDescription =
        $Matches[1].Trim()
    }

    if (
        -not [string]::IsNullOrWhiteSpace($fileCode) -and
        -not [string]::IsNullOrWhiteSpace($itemDescription)
    ) {
        $nxNames[$fileCode] =
        $itemDescription
    }
}

$aliasFallback = @{
    "_2" = "_1"
    "_4" = "_3"
    "_6" = "_5"
}

foreach ($alias in $aliasFallback.Keys) {

    $sourceAlias =
    $aliasFallback[$alias]

    if (
        -not $nxNames.ContainsKey($alias) -and
        $nxNames.ContainsKey($sourceAlias)
    ) {
        $nxNames[$alias] =
        $nxNames[$sourceAlias]
    }
}

if (-not $nxNames.ContainsKey("_7")) {
    $nxNames["_7"] =
    "PORCA REBITE CAB CONICA E_P"
}

$structureNamesFile =
Join-Path `
(Split-Path -Parent $PastaNx) `
    "estrutura_montagem.txt"

if (Test-Path -LiteralPath $structureNamesFile) {

    Get-Content `
        -LiteralPath $structureNamesFile `
        -Encoding UTF8 |
    ForEach-Object {

        $line =
        $_.Trim()

        # Remove o prefixo "MONTAGEM: " se existir, para tratar a linha do item pai igual as outras
        $line =
        $line -replace '^MONTAGEM:\s*', ''

        if ($line -match '^(\d+\.\d+\.\d+)[_#\s-]+(.+)$') {

            $code =
            $Matches[1].Trim()

            $description =
            $Matches[2].Trim()

            $description =
            $description -replace '__sld(prt|asm)$', ''

            $description =
            $description.Trim('_', '#', ' ')

            if (
                -not [string]::IsNullOrWhiteSpace($description) -and
                -not $nxNames.ContainsKey($code)
            ) {
                $nxNames[$code] =
                $description

                Write-Host `
                    "  [OK] Nome recuperado da estrutura NX: $code = $description" `
                    -ForegroundColor Green
            }
        }
    }
}
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
            -Recurse
    ) |
    Where-Object {

        $_.BaseName -notmatch '^[_-]?\d+$' -and
        $_.BaseName -notmatch '^\d+\.\d+\.\d+_\d+$'
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

    $descriptionCode =
    $sourcePartCode -replace '_\d+$', ''

    $itemDescription =
    $null

    if ($nxNames.ContainsKey($descriptionCode)) {
        $itemDescription =
        $nxNames[$descriptionCode]
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

    if ($null -eq $teamcenterRevision) {

        throw `
            "Teamcenter revision was not found for '$teamcenterCode'."
    }

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

        Write-Success `
            -Message "Nome NX aplicado: $sourcePartCode = $itemDescription"
    }
    else {

        Write-Host `
            "  [WARNING] Nome NX nao encontrado para: $sourcePartCode" `
            -ForegroundColor Yellow
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
    $posFile =
    Join-Path `
        $PastaNx `
        "Posicionamento.txt"

    $estruturaView =
    [System.Collections.Generic.List[object]]::new()

    if ($DocumentType -eq "Assembly") {

        Write-Host ""
        Write-Host "POS FILE:"
        Write-Host $posFile

        if (-not (
                Test-Path `
                    -LiteralPath $posFile `
                    -PathType Leaf
            )) {

            throw `
                "Posicionamento.txt nao encontrado: $posFile"
        }

        Write-Section `
            -Title "VIEW DETECTADA PELO NX"

        Get-Content `
            -LiteralPath $posFile |
        ForEach-Object {

            $parts =
            $_ -split '\|', 3

            if ($parts.Count -ne 3) {
                return
            }

            $parentCode =
            $parts[0].Trim()

            $occurrenceCode =
            $parts[1].Trim()

            $childCode =
            $occurrenceCode

            if ($occurrenceCode -match '^(.+)_\d+$') {
                $childCode =
                $Matches[1]
            }

            $transform =
            $parts[2].Trim() -replace ',', '.'

            if (-not [string]::IsNullOrWhiteSpace(
                    $occurrenceCode
                )) {

                $estruturaView.Add(
                    [PSCustomObject]@{
                        Parent         = $parentCode
                        Child          = $childCode
                        OccurrenceCode = $occurrenceCode
                        Transform      = $transform
                    }
                )
            }
        }

        if ($estruturaView.Count -eq 0) {

            throw `
                "Nenhuma ocorrencia valida foi encontrada em '$posFile'."
        }

        Write-Host ""
        Write-Host "MONTAGEM:"
        Write-Host "  $($estruturaView[0].Parent)"

        Write-Host ""
        Write-Host "VIEW ESPERADA:"
        Write-Host ""

        $estruturaView |
        Select-Object -ExpandProperty Child |
        Sort-Object -Unique |
        ForEach-Object {
            Write-Host "  $_"
        }
    }
    else {

        Write-Section `
            -Title "PECA INDIVIDUAL"

        Write-Success `
            -Message "Peca individual confirmada pelo importador."

        Write-Info `
            -Message "Posicionamento.txt nao sera utilizado."

        Write-Info `
            -Message "A criacao da BOM sera ignorada."
    }

    foreach ($f in $nxPartFiles) {
        Write-Host $f.FullName
    }

    Write-Success `
        -Message "$($nxPartFiles.Count) PRT file(s) found."

    Write-Info `
        -Message "NX folder: $PastaNx"

    Write-Section `
        -Title "TEAMCENTER IMPORT"

    Write-Host ""
    Write-Host "ATENCAO: as proximas linhas vao CRIAR itens reais no Teamcenter." -ForegroundColor Yellow
    $confirmacao = Read-Host "Digite 'sim' para continuar, ou qualquer outra coisa para abortar"

    if ($confirmacao -ne "sim") {
        Write-Host ""
        Write-Host "Abortado pelo usuario. Nenhum item foi criado." -ForegroundColor Yellow
        exit 0
    }

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

    if ($DocumentType -eq "Assembly") {

        $parentSourceCode =
        $estruturaView |
        Select-Object -ExpandProperty Parent -First 1

        $parentResult =
        $importResults |
        Where-Object {
            $_.SourcePartCode -eq $parentSourceCode
        } |
        Select-Object -First 1

        if ($null -eq $parentResult) {
            throw "Item pai nao encontrado nos resultados: $parentSourceCode"
        }

        # O restante da logica da BOM continua aqui sem alteracao
        $parentItem =
        Get-TeamcenterItem `
            -ItemCode $parentResult.TeamcenterCode

        $parentRevision =
        Get-TeamcenterRevision `
            -Item $parentItem

        $policyProps =
        New-Object `
            'System.Collections.Generic.List[string[]]'

        $policyProps.Add(
            [string[]]@(
                "BOMLine",
                "bl_child_lines"
            )
        )

        [ImportarGD.Controller.Functions]::setObjectPolicy(
            $policyProps
        )

        try {

            foreach ($occurrence in $estruturaView) {

                $resolvedChildCode =
                $occurrence.Child

                if ($nxNames.ContainsKey($occurrence.OccurrenceCode)) {
                    $resolvedChildCode =
                    $nxNames[$occurrence.OccurrenceCode]
                }
                elseif ($nxNames.ContainsKey($occurrence.Child)) {
                    $resolvedChildCode =
                    $nxNames[$occurrence.Child]
                }

                $childResult =
                $importResults |
                Where-Object {
                    $_.SourcePartCode -ieq $resolvedChildCode
                } |
                Select-Object -First 1

                if ($null -eq $childResult) {

                    Write-Host `
                        "  [WARNING] Filho nao importado: $($occurrence.Child)" `
                        -ForegroundColor Yellow

                    continue
                }

                $childItem =
                Get-TeamcenterItem `
                    -ItemCode $childResult.TeamcenterCode

                $childRevision =
                Get-TeamcenterRevision `
                    -Item $childItem

                if ($null -eq $childRevision) {

                    Write-Host `
                        "  [WARNING] Revisao nao encontrada: $($occurrence.Child)" `
                        -ForegroundColor Yellow

                    continue
                }

                $singleChildList =
                New-Object `
                    'System.Collections.Generic.List[Teamcenter.Soa.Client.Model.Strong.ItemRevision]'

                $singleChildList.Add(
                    $childRevision
                )

                $attributes =
                New-Object `
                    'System.Collections.Generic.List[System.Collections.Hashtable]'

                $occurrenceAttributes =
                New-Object System.Collections.Hashtable

                $occurrenceAttributes.Add(
                    "bl_plmxml_occ_xform",
                    $occurrence.Transform
                )

                $attributes.Add(
                    $occurrenceAttributes
                )

                Write-Info `
                    -Message "Adicionando ocorrencia: $($occurrence.OccurrenceCode)"

                Write-Info `
                    -Message "Transform: $($occurrence.Transform)"

                $occurrenceParentResult =
                $importResults |
                Where-Object {
                    $_.SourcePartCode -ieq $occurrence.Parent
                } |
                Select-Object -First 1

                if ($null -eq $occurrenceParentResult) {

                    Write-Host `
                        "  [WARNING] Pai nao localizado: $($occurrence.Parent)" `
                        -ForegroundColor Yellow

                    continue
                }

                $occurrenceParentItem =
                Get-TeamcenterItem `
                    -ItemCode $occurrenceParentResult.TeamcenterCode

                $occurrenceParentRevision =
                Get-TeamcenterRevision `
                    -Item $occurrenceParentItem

                if ($null -eq $occurrenceParentRevision) {

                    Write-Host `
                        "  [WARNING] Revisao do pai nao localizada: $($occurrence.Parent)" `
                        -ForegroundColor Yellow

                    continue
                }

                [ImportarGD.Controller.Functions]::addAllChildrenInBOM(
                    $occurrenceParentRevision,
                    $singleChildList,
                    $attributes
                )

            }

            Write-Host ""
            Write-Success `
                -Message "BOM criada com posicionamento."
        }
        catch {

            Write-Host ""

            Write-Failure `
                -Message "Erro ao criar BOM: $($_.Exception.Message)"

            throw
        }
        finally {

            Close-LeftoverBomWindow `
                -Revision $parentRevision
        }

        }
else {

    Write-Host ""

    Write-Info `
        -Message "Criacao da BOM ignorada para peca individual."
}

        Write-Host ""

        Write-Success `
            -Message "Teamcenter import completed."

        Write-Info `
            -Message "Imported files: $($importResults.Count)"

        exit 0
    }
    catch {

        Write-Failure `
            -Message $_.Exception.Message

        Write-Host ""
        Write-Host "[FULL ERROR]" -ForegroundColor DarkGray
        Write-Host $_.Exception.ToString() -ForegroundColor DarkGray
        Write-Host ""

        exit 1
    }
