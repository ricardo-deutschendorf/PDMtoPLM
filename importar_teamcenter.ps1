param(
    [Parameter(Mandatory = $true)]
    [string]$PastaNx
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\functions.ps1"

try {

    Connect-TC

    $arquivosPrt = @(
        Get-ChildItem `
            -LiteralPath $PastaNx `
            -Filter "*.prt" `
            -File `
            -Recurse
    )

    foreach ($arquivoPrt in $arquivosPrt) {

        $codigoBase = $arquivoPrt.BaseName
        $codigoTc = "$codigoBase-1"

        Write-Host "Consultando: $codigoTc"

        Write-Host "Buscando ou criando: $codigoTc"

        $item = Get-OrCreateItem `
            -Codigo $codigoTc `
            -Empresa "02" `
            -TipoItem "GD5DesignPerto"

        Write-Host "[OK] Item disponivel: $codigoTc"

        $rev = Get-Revision -Item $item

        $resultado = Import-PRT `
            -Rev $rev `
            -Codigo $codigoTc `
            -Arquivo $arquivoPrt.FullName

        Write-Host "[PRT] $codigoTc = $resultado"
    }

    exit 0
}
catch {
    Write-Host "[ERRO COMPLETO]"
    Write-Host $_.Exception.ToString()
    exit 1
}