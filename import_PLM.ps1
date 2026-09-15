# ============================================================
# COPIAR IMPORTADOR GD
# ============================================================

if (-not (Get-PSDrive -Name Q -ErrorAction SilentlyContinue)) {
    Write-Host "mapeando diretorio de rede"
    net use Q: \\perto38-novo\NX_Custom
} else {
    Write-Host "diretorio de rede ja mapeado"
}

try {

    $origem =
        "Q:\ImportByPDM\Brazil\ImportarGD_V11"

    $destino =
        "C:\Temp\ImportarGD"

    Write-Host ""
    Write-Host "Origem:" -ForegroundColor Cyan
    Write-Host $origem

    Write-Host ""
    Write-Host "Destino:" -ForegroundColor Cyan
    Write-Host $destino

    Write-Host ""
    Write-Host "Existe origem? $(Test-Path $origem)"

    if (-not (Test-Path $origem)) {

        throw "Origem nao encontrada."

    }

    if (-not (Test-Path "C:\Temp")) {

        New-Item `
            -ItemType Directory `
            -Path "C:\Temp" `
            -Force |
        Out-Null

    }

    if (Test-Path $destino) {

        Remove-Item `
            $destino `
            -Recurse `
            -Force

    }

    New-Item `
        -ItemType Directory `
        -Path $destino `
        -Force |
    Out-Null

    Write-Host ""
    Write-Host "Copiando arquivos..." `
        -ForegroundColor Yellow

    Copy-Item `
        "$origem\*" `
        -Destination $destino `
        -Recurse `
        -Force

    Write-Host ""
    Write-Host "Removendo bloqueios..." `
        -ForegroundColor Yellow

    Get-ChildItem `
        $destino `
        -Recurse |
    Unblock-File

    Write-Host ""
    Write-Host "Arquivos copiados:" `
        -ForegroundColor Green

    Get-ChildItem `
        $destino |
    Select-Object Name

    Write-Host ""
    Write-Host "Executavel:" `
        -ForegroundColor Green

    Write-Host `
        "$destino\Importar GD.exe"

    Write-Host ""

}
catch {

    Write-Host ""
    Write-Host "ERRO:" `
        -ForegroundColor Red

    Write-Host `
        $_.Exception.Message `
        -ForegroundColor Red

}

Write-Host ""
Read-Host "Pressione Enter para sair"