$arquivoCredencial =
    Join-Path `
    $PSScriptRoot `
    "vault_credencial.xml"

Write-Host ""
Write-Host "Configuracao de Credenciais do Vault"
Write-Host ""

$usuario =
    Read-Host "Usuario do Vault"

$senha =
    Read-Host `
    "Senha do Vault" `
    -AsSecureString

$objeto = [PSCustomObject]@{

    Usuario = $usuario

    SenhaCriptografada =
        ConvertFrom-SecureString $senha

}

$objeto |
Export-Clixml `
    -Path $arquivoCredencial

Write-Host ""
Write-Host "Credencial salva em:"
Write-Host $arquivoCredencial
Write-Host ""

pause