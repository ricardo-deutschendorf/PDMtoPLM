function Connect-TC {

    Write-Host "TC 1 - Carregando EXE"

    $script:Asm =
    [Reflection.Assembly]::LoadFrom(
        "C:\Temp\ImportarGD\Importar GD.exe"
    )

    Write-Host "TC 2 - Procurando Session"

    $sessionType =
    $script:Asm.GetType(
        "Teamcenter.ClientX.Session"
    )

    if ($null -eq $sessionType) {
        throw "Tipo Teamcenter.ClientX.Session nao encontrado."
    }

    Write-Host "TC 3 - Criando Session"

    $session =
    [System.Activator]::CreateInstance(
        $sessionType,
        @(
            "http://perto37-novo.perto.com.br:8080/tc"
        )
    )

    if ($null -eq $session) {
        throw "Session retornou NULL."
    }

    Write-Host "TC 4 - Login"

    $usuario =
    $session.login(
        "infodba",
        "infodba",
        "",
        "",
        "SoaAppX"
    )

    if ($null -eq $usuario) {
        throw "Login retornou NULL."
    }

    Write-Host "TC 5 - Procurando Functions"

    $script:Functions =
    $script:Asm.GetType(
        "ImportarGD.Controller.Functions"
    )

    if ($null -eq $script:Functions) {
        throw "ImportarGD.Controller.Functions nao encontrado."
    }

    Write-Host "TC 6 - Conexao concluida"
}

function Get-Revision {

    param($Item)

    $getRev =
    $script:Functions.GetMethods() |
    Where-Object {
        $_.Name -eq "getItemRevisionfromItem"
    } |
    Where-Object {
        $_.GetParameters().Count -eq 1
    } |
    Select-Object -First 1

    $getRev.Invoke(
        $null,
        @($Item)
    )
}

function New-NextItemTC {

    param(
        [Parameter(Mandatory = $true)]
        [string]$CodigoArquivo,

        [string]$Empresa = "02",

        [string]$TipoItem = "GD5DesignPerto",

        [int]$Limite = 100
    )

    # 260.02.002-1.prt deve iniciar a procura em 260.02.002
    if ($CodigoArquivo -match '^(.*)-(\d+)$') {
        $codigoBase = $Matches[1]
    }
    else {
        $codigoBase = $CodigoArquivo
    }

    $getItem = $script:Functions.GetMethod("getItem")
    $criarItem = $script:Functions.GetMethod("criarItem")

    if ($null -eq $getItem) {
        throw "Metodo Functions.getItem nao encontrado."
    }

    if ($null -eq $criarItem) {
        throw "Metodo Functions.criarItem nao encontrado."
    }

    for ($contador = 0; $contador -le $Limite; $contador++) {

        if ($contador -eq 0) {
            $codigoCandidato = $codigoBase
        }
        else {
            $codigoCandidato = "$codigoBase-$contador"
        }

        Write-Host "Verificando: $codigoCandidato"

        $itemExistente = $getItem.Invoke(
            $null,
            @(
                $codigoCandidato,
                $Empresa
            )
        )

        if ($null -ne $itemExistente) {
            Write-Host "[AVISO] Ja existe: $codigoCandidato"
            continue
        }

        Write-Host "[INFO] Tentando criar: $codigoCandidato"

        $itemCriado = $criarItem.Invoke(
            $null,
            @(
                $codigoCandidato,
                $TipoItem,
                $Empresa
            )
        )

        if ($null -ne $itemCriado) {

            Write-Host "[OK] Item criado: $codigoCandidato"

            return [PSCustomObject]@{
                Codigo = $codigoCandidato
                Item   = $itemCriado
            }
        }
    }

    throw "Nao foi possivel criar um item apos $Limite tentativas."
}

function Import-PRT {

    param(
        $Rev,
        [string]$Codigo,
        [string]$Arquivo
    )

    if (!(Test-Path $Arquivo)) {
        return
    }

    $metodo =
    $script:Functions.GetMethod(
        "ImportarPrt"
    )

    $metodo.Invoke(
        $null,
        @(
            $Codigo,
            "",
            $Arquivo,
            $Rev,
            $true
        )
    )
}

function Import-JT {

    param(
        $Rev,
        [string]$Codigo,
        [string]$Arquivo
    )

    if (!(Test-Path $Arquivo)) {
        return
    }

    $metodo =
    $script:Functions.GetMethod(
        "ImportarJT"
    )

    $metodo.Invoke(
        $null,
        @(
            $Codigo,
            "",
            $Arquivo,
            $Rev,
            $true
        )
    )
}

function Import-PDF {

    param(
        $Rev,
        [string]$Codigo,
        [string]$Arquivo
    )

    if (!(Test-Path $Arquivo)) {
        return
    }

    $metodo =
    $script:Functions.GetMethod(
        "ImportarPDF"
    )

    $metodo.Invoke(
        $null,
        @(
            $Codigo,
            "",
            $Arquivo,
            $Rev,
            $true
        )
    )
}

function Import-DWG {

    param(
        $Rev,
        [string]$Codigo,
        [string]$Arquivo
    )

    if (!(Test-Path $Arquivo)) {
        return
    }

    $metodo =
    $script:Functions.GetMethod(
        "ImportarDWG"
    )

    $metodo.Invoke(
        $null,
        @(
            $Codigo,
            "",
            $Arquivo,
            $Rev,
            $true
        )
    )
}