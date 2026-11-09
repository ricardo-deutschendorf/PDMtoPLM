# ============================================================
# TEAMCENTER ITEM TARGET SELECTION
# Define o destino para pecas individuais e montagens.
# Nenhuma alteracao e feita no Teamcenter nesta etapa.
# ============================================================

function Select-TeamcenterItemTarget {

    Write-Section `
        -Title "TEAMCENTER ITEM DESTINATION"

    Write-Host ""
    Write-Host "Como definir o destino no Teamcenter?"
    Write-Host ""
    Write-Host "  1 - Informar um item existente como destino"
    Write-Host "  2 - Reutilizar cada codigo existente ou criar somente se faltar"
    Write-Host ""
    Write-Host "Para montagens, o item informado sera o pai; os filhos usam seus proprios codigos."
    Write-Host ""

    while ($true) {

        $option =
        (
            Read-Host "Digite 1 ou 2"
        ).Trim()

        switch ($option) {

            "1" {

                while ($true) {

                    $existingItemCode =
                    (
                        Read-Host "Digite o codigo existente no Teamcenter"
                    ).Trim()

                    if (
                        [System.String]::IsNullOrWhiteSpace(
                            $existingItemCode
                        )
                    ) {

                        Write-WarningMessage `
                            -Message "O codigo Teamcenter nao pode ficar vazio."

                        continue
                    }

                    break
                }

                Write-Host ""
                Write-Info `
                    -Message "Item informado como destino: $existingItemCode"

                return [PSCustomObject]@{
                    Mode              = "Existing"
                    ItemAlreadyExists = $true
                    ExistingItemCode  = $existingItemCode
                }
            }

            "2" {

                Write-Host ""
                Write-Info `
                    -Message "Cada codigo existente sera reutilizado; somente codigos ausentes serao criados."

                return [PSCustomObject]@{
                    Mode              = "Create"
                    ItemAlreadyExists = $false
                    ExistingItemCode  = $null
                }
            }

            default {

                Write-WarningMessage `
                    -Message "Opcao invalida. Digite somente 1 ou 2."
            }
        }
    }
}