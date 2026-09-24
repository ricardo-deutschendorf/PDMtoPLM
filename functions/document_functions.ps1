# === SolidWorks document methods ===

# Section: Find the main SolidWorks file
function Get-MainSolidWorksFile {

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FolderPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PartCode
    )

    if (-not (
            Test-Path  -LiteralPath $FolderPath  -PathType Container
        )) {

        throw "Pasta local nao encontrada: $FolderPath"
    }

    $escapedPartCode =
    [System.Text.RegularExpressions.Regex]::Escape(
        $PartCode
    )

    $mainFilePattern =
    "^$escapedPartCode(?:-\d+)?(?:#|$)"

    $candidateFiles =
    @(
        Get-ChildItem  -LiteralPath $FolderPath  -File  -ErrorAction Stop |
        Where-Object {

            (
                $_.Extension -ieq ".SLDASM" -or
                $_.Extension -ieq ".SLDPRT"
            ) -and
            $_.BaseName -match $mainFilePattern
        }
    )

    if ($candidateFiles.Count -eq 0) {

        $availableFiles =
        @(
            Get-ChildItem  -LiteralPath $FolderPath  -File |
            Select-Object -ExpandProperty Name
        )

        throw (
            "Nenhum SLDASM ou SLDPRT principal foi encontrado " +
            "para o codigo '$PartCode'. Arquivos locais: " +
            ($availableFiles -join ", ")
        )
    }

    $assemblyFile =
    $candidateFiles |
    Where-Object {
        $_.Extension -ieq ".SLDASM"
    } |
    Sort-Object Name |
    Select-Object -First 1

    if ($null -ne $assemblyFile) {
        return $assemblyFile
    }

    $partFile =
    $candidateFiles |
    Where-Object {
        $_.Extension -ieq ".SLDPRT"
    } |
    Sort-Object Name |
    Select-Object -First 1

    if ($null -eq $partFile) {

        throw (
            "Nao foi possivel determinar o arquivo principal " +
            "do codigo '$PartCode'."
        )
    }

    return $partFile
}

# Section: Identify the SolidWorks document type
function Get-SolidWorksDocumentInfo {

    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$MainFile
    )

    $extension =
    $MainFile.Extension.ToUpperInvariant()

    switch ($extension) {

        ".SLDPRT" {

            return [PSCustomObject]@{
                Type        = "Part"
                IsPart      = $true
                IsAssembly  = $false
                Description = "Peca individual"
                MainFile    = $MainFile
            }
        }

        ".SLDASM" {

            return [PSCustomObject]@{
                Type        = "Assembly"
                IsPart      = $false
                IsAssembly  = $true
                Description = "Montagem"
                MainFile    = $MainFile
            }
        }

        default {

            throw (
                "Tipo SolidWorks nao suportado: " +
                $MainFile.FullName
            )
        }
    }
}

# ============================================================
# PART DESCRIPTION FALLBACK
# Cria ou complementa NomesNx.txt usando o nome do SLDPRT.
#
# Exemplo:
# 260.02.002-1#PE DE BORRACHA#.SLDPRT
#
# Resultado:
# 260.02.002-1|PE DE BORRACHA
# ============================================================

function Confirm-PartNxNameFile {

    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$SolidWorksFile,

        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath,

        [Parameter(Mandatory = $true)]
        [object[]]$NxPartFiles
    )

    if ($SolidWorksFile.Extension -ine ".SLDPRT") {
        return
    }

    if (-not (
            Test-Path `
                -LiteralPath $NxFolderPath `
                -PathType Container
        )) {

        throw "Pasta NX nao encontrada: $NxFolderPath"
    }

    if ($NxPartFiles.Count -eq 0) {

        throw (
            "Nenhum arquivo PRT foi informado para criar " +
            "o fallback de nome."
        )
    }

    $solidWorksBaseName =
    $SolidWorksFile.BaseName

    $partDescription =
    $null

    if ($solidWorksBaseName -match '^[^#]+#([^#]+)#?$') {

        $partDescription =
        $Matches[1].Trim()
    }

    if ([string]::IsNullOrWhiteSpace($partDescription)) {

        Write-WarningMessage `
            -Message (
                "Nao foi encontrada uma descricao entre # no arquivo " +
                "'$($SolidWorksFile.Name)'."
            )

        return
    }

    $nxPartFile =
    $NxPartFiles |
    Where-Object {
        $_.BaseName -ieq (
            $solidWorksBaseName -replace '#.*$', ''
        )
    } |
    Select-Object -First 1

    if ($null -eq $nxPartFile) {

        $nxPartFile =
        $NxPartFiles |
        Select-Object -First 1
    }

    if ($null -eq $nxPartFile) {

        throw (
            "Nao foi possivel identificar o PRT correspondente " +
            "ao arquivo '$($SolidWorksFile.Name)'."
        )
    }

    $nxCode =
    $nxPartFile.BaseName

    $nxNamesFile =
    Join-Path `
        $NxFolderPath `
        "NomesNx.txt"

    $existingNames =
    @{}

    if (
        Test-Path `
            -LiteralPath $nxNamesFile `
            -PathType Leaf
    ) {

        Get-Content `
            -LiteralPath $nxNamesFile `
            -Encoding UTF8 |
        ForEach-Object {

            $parts =
            $_ -split '\|', 2

            if ($parts.Count -ne 2) {
                return
            }

            $existingCode =
            $parts[0].Trim()

            $existingDescription =
            $parts[1].Trim()

            if (-not [string]::IsNullOrWhiteSpace($existingCode)) {

                $existingNames[$existingCode] =
                $existingDescription
            }
        }
    }

    if (
        $existingNames.ContainsKey($nxCode) -and
        -not [string]::IsNullOrWhiteSpace(
            $existingNames[$nxCode]
        )
    ) {

        Write-Success `
            -Message (
                "Nome da peca ja disponivel: " +
                "$nxCode = $($existingNames[$nxCode])"
            )

        return
    }

    $nameLine =
    "$nxCode|$partDescription"

    Add-Content `
        -LiteralPath $nxNamesFile `
        -Value $nameLine `
        -Encoding UTF8

    Write-Success `
        -Message "Nome da peca recuperado do SolidWorks."

    Write-Info `
        -Message "$nxCode = $partDescription"

    Write-Info `
        -Message "Arquivo: $nxNamesFile"
}