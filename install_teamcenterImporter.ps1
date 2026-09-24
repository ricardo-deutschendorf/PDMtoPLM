# ============================================================
# CALL EXISTING TEAMCENTER IMPORTER INSTALLER
# ============================================================

$ErrorActionPreference = "Stop"

$installerScript =
Join-Path `
    $PSScriptRoot `
    "import_PLM.ps1"

if (-not (
        Test-Path `
            -LiteralPath $installerScript `
            -PathType Leaf
    )) {

    throw "import_PLM.ps1 nao encontrado: $installerScript"
}

& powershell.exe `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File $installerScript

$installerExitCode =
$LASTEXITCODE

if ($installerExitCode -ne 0) {

    throw (
        "Falha ao preparar o Importar GD. " +
        "Codigo: $installerExitCode"
    )
}