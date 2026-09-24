# ============================================================
# TEAMCENTER ITEM TARGET SELECTION
# Define se sera criado um item ou utilizado um item existente.
# Nenhuma alteracao e feita no Teamcenter nesta etapa.
# ============================================================

function Select-TeamcenterItemTarget {

    Write-Section `
        -Title "TEAMCENTER ITEM DESTINATION"

    Write-Host ""
    Write-Host "O item ja existe no Teamcenter?"
    Write-Host ""
    Write-Host "  1 - Sim, adicionar o 3D a um item existente"
    Write-Host "  2 - Nao, criar um novo item"
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
                    -Message "Destino Teamcenter: $existingItemCode"

                return [PSCustomObject]@{
                    Mode              = "Existing"
                    ItemAlreadyExists = $true
                    ExistingItemCode  = $existingItemCode
                }
            }

            "2" {

                Write-Host ""
                Write-Info `
                    -Message "Um novo item sera criado no Teamcenter."

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