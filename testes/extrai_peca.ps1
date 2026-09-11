# ============================================================
#  BUSCA E DOWNLOAD DE DOCUMENTOS NO VAULT "PERTO" (SolidWorks EPDM)
# ============================================================

Add-Type -Path "C:\Perto\Templates\CodAplic\Interop.EdmLib.dll"

$vaultName = "Perto"
$caminhoCredencial = "$PSScriptRoot\vault_credencial.xml"
$pastaDestino = "C:\temp\importados"

function Escreve-Titulo($texto) {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor White
    Write-Host " $texto" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor White
}

function Escreve-Sucesso($texto) {
    Write-Host "  [OK] $texto" -ForegroundColor Green
}

function Escreve-Erro($texto) {
    Write-Host "  [ERRO] $texto" -ForegroundColor Red
}

function Escreve-Aviso($texto) {
    Write-Host "  [AVISO] $texto" -ForegroundColor Yellow
}

function Escreve-Info($texto) {
    Write-Host "  -> $texto" -ForegroundColor Gray
}

try {

    Escreve-Titulo "CONEXAO COM O VAULT"

    if (-not (Test-Path $caminhoCredencial)) {
        throw "Arquivo de credencial nao encontrado. Rode configura_credencial.ps1 primeiro."
    }

    $credencial = Import-Clixml -Path $caminhoCredencial

    $senhaSegura = $credencial.SenhaCriptografada | ConvertTo-SecureString

    $senhaPlana = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senhaSegura)
    )

    $vault = New-Object EdmLib.EdmVault5Class

    $vault.Login(
        $credencial.Usuario,
        $senhaPlana,
        $vaultName
    )

    if (-not $vault.IsLoggedIn) {
        throw "Nao foi possivel logar no vault '$vaultName'."
    }

    Escreve-Sucesso "Conectado ao vault '$vaultName'."

    if (-not (Test-Path $pastaDestino)) {

        New-Item `
            -ItemType Directory `
            -Path $pastaDestino `
            -Force | Out-Null

        Escreve-Info "Pasta de destino criada: $pastaDestino"
    }
    else {
        Escreve-Info "Pasta de destino ja existe: $pastaDestino"
    }

    Escreve-Titulo "BUSCA DE DOCUMENTO"

    Write-Host "  Use * como coringa. Exemplos:" -ForegroundColor Gray
    Write-Host "    260.02.002   -> busca exata" -ForegroundColor Gray
    Write-Host "    260.*        -> busca tudo que comeca com 260." -ForegroundColor Gray
    Write-Host ""

    $codigoDigitado = Read-Host "  Digite o codigo do documento"

    if ([string]::IsNullOrWhiteSpace($codigoDigitado)) {
        throw "Nenhum codigo informado."
    }

    $codigoConvertido = $codigoDigitado.Replace("*", "%")

    if ($codigoConvertido -notmatch "%") {
        $codigoConvertido = "%$codigoConvertido%"
    }

    $busca = $vault.CreateSearch()
    $busca.FileName = $codigoConvertido
    $busca.FindHistoricStates = $false

    $listaResultados = @()

    $resultado = $busca.GetFirstResult()

    while ($null -ne $resultado) {
        $listaResultados += $resultado
        $resultado = $busca.GetNextResult()
    }

    Escreve-Titulo "RESULTADOS PARA '$codigoDigitado'"

    if ($listaResultados.Count -eq 0) {
        Escreve-Aviso "Nenhum resultado encontrado."
        pause
        exit 0
    }

    $pastaDestinoFinal = Join-Path $pastaDestino $codigoDigitado

    if (-not (Test-Path $pastaDestinoFinal)) {
        New-Item `
            -ItemType Directory `
            -Path $pastaDestinoFinal `
            -Force | Out-Null

        Escreve-Info "Pasta criada: $pastaDestinoFinal"
    }

    $listaResultados |
    ForEach-Object {
        [PSCustomObject]@{
            Nome    = $_.Name
            Caminho = $_.Path
        }
    } |
    Format-Table -AutoSize -Wrap |
    Out-String |
    Write-Host

    Escreve-Sucesso "Total de itens encontrados: $($listaResultados.Count)"

    Escreve-Titulo "SALVANDO ARQUIVOS EM $pastaDestinoFinal"

    $sucessos = 0
    $falhas = 0

    foreach ($item in $listaResultados) {

        try {

            $pastaPai = $null

            $arquivo = $vault.GetFileFromPath(
                $item.Path,
                [ref]$pastaPai
            )

            if ($null -eq $arquivo) {
                Escreve-Erro "Nao foi possivel obter '$($item.Name)'"
                $falhas++
                continue
            }

            $versao = 0
            $folder = $pastaPai.ID

            # Baixa para o cache local do vault
            $arquivo.GetFileCopy(
                0,
                [ref]$versao,
                [ref]$folder,
                0,
                ""
            )

            $localPath = $arquivo.GetLocalPath($pastaPai.ID)

            if (-not (Test-Path $localPath)) {
                Escreve-Erro "Arquivo nao foi baixado: $($item.Name)"
                $falhas++
                continue
            }

            $arquivoDestino = Join-Path $pastaDestinoFinal $item.Name

            if (Test-Path $arquivoDestino) {
                Escreve-Aviso "Ja existe: $($item.Name)"
                continue
            }

            Copy-Item `
                -Path $localPath `
                -Destination $arquivoDestino

            Escreve-Sucesso "Copiado: $($item.Name)"

        }
        catch {
            Escreve-Erro "$($item.Name) - $($_.Exception.Message)"
            $falhas++
        }
    }

    Write-Host ""
    Escreve-Sucesso "Arquivos copiados: $sucessos"

    if ($falhas -gt 0) {
        Escreve-Aviso "Falhas: $falhas"
    }

}
catch {
    Escreve-Erro $_.Exception.Message
    exit 1
}
finally {
    Remove-Variable senhaPlana -ErrorAction SilentlyContinue
}

Write-Host ""