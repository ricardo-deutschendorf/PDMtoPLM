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

function Get-OrCreateItem {

    param(
        [string]$Codigo,
        [string]$Empresa,
        [string]$TipoItem
    )

    # BUSCAR ITEM

    $getItem =
    $script:Functions.GetMethod(
        "getItem"
    )

    $item =
    $getItem.Invoke(
        $null,
        @(
            $Codigo,
            $Empresa
        )
    )

    if ($null -ne $item) {
        Write-Host "[OK] Item existente: $Codigo"
        return $item
    }

    # CRIAR ITEM

    Write-Host "[AVISO] Criando item: $Codigo"

    $criarItem =
    $script:Functions.GetMethod(
        "criarItem"
    )

    $item =
    $criarItem.Invoke(
        $null,
        @(
            $Codigo,
            $TipoItem,
            $Empresa
        )
    )

    if ($null -eq $item) {
        throw "Nao foi possivel criar o item '$Codigo'."
    }

    Write-Host "[OK] Item criado: $Codigo"

    return $item
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