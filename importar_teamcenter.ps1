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

        $codigoArquivo = $arquivoPrt.BaseName

        $destino = New-NextItemTC `
            -CodigoArquivo $codigoArquivo `
            -Empresa "02" `
            -TipoItem "GD5DesignPerto"

        $codigoTc = $destino.Codigo
        $item = $destino.Item

        $rev = Get-Revision -Item $item

        if ($null -eq $rev) {
            throw "Revisao nao encontrada para '$codigoTc'."
        }

        $resultado = Import-PRT `
            -Rev $rev `
            -Codigo $codigoTc `
            -Arquivo $arquivoPrt.FullName

        Write-Host "[PRT] $codigoTc = $resultado"

        if (
            $null -ne $item -and
            -not [string]::IsNullOrWhiteSpace($destino.Nome)
        ) {
   
        }

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