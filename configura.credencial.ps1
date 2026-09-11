# Rode este script UMA VEZ, manualmente, logado com o mesmo usuario do Windows
# que vai executar o batch depois (ex: o usuario de servico ou sua propria conta).
# A senha fica criptografada e so pode ser lida por essa mesma conta, nesta mesma maquina.

$vaultUser = Read-Host "Digite o usuario do vault EPDM"
$vaultPass = Read-Host "Digite a senha do vault EPDM" -AsSecureString

$credencial = [PSCustomObject]@{
    Usuario = $vaultUser
    SenhaCriptografada = $vaultPass | ConvertFrom-SecureString
}

$caminhoArquivo = "$PSScriptRoot\vault_credencial.xml"
$credencial | Export-Clixml -Path $caminhoArquivo

Write-Host "Credencial salva com sucesso em: $caminhoArquivo"
Write-Host "Este arquivo so pode ser descriptografado pelo usuario/maquina atual."