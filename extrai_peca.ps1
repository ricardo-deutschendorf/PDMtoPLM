# ============================================================
#  PDM PARA NX
#  Busca, download e conversao silenciosa SolidWorks para NX
# ============================================================

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURACOES
# ============================================================

$dllPdm = "C:\Perto\Templates\CodAplic\Interop.EdmLib.dll"

$vaultName = "Perto"

$caminhoCredencial = Join-Path `
    $PSScriptRoot `
    "vault_credencial.xml"

$pastaDestino = "C:\temp\importados"

$runJournalExe = `
    "C:\Siemens\NX2312\NXBIN\run_journal.exe"

$importSwDll = `
    "\\perto38-novo\NX_Custom\ImportSW2NX.dll"

$empresa = "Perto"

$logNx = "C:\temp\wrapper_silent_log.txt"

$wrapperTemporario = Join-Path `
    $env:TEMP `
    "PDMtoPLM_wrapper.vb"

. "$PSScriptRoot\functions.ps1"
# ============================================================
# FUNCOES VISUAIS
# ============================================================

function Escreve-Titulo {
    param([string]$Texto)

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor White
    Write-Host " $Texto" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor White
}

function Escreve-Sucesso {
    param([string]$Texto)

    Write-Host "  [OK] $Texto" -ForegroundColor Green
}

function Escreve-Erro {
    param([string]$Texto)

    Write-Host "  [ERRO] $Texto" -ForegroundColor Red
}

function Escreve-Aviso {
    param([string]$Texto)

    Write-Host "  [AVISO] $Texto" -ForegroundColor Yellow
}

function Escreve-Info {
    param([string]$Texto)

    Write-Host "  -> $Texto" -ForegroundColor Gray
}

# ============================================================
# FUNCAO PARA CRIAR O WRAPPER VB TEMPORARIO
# ============================================================

function Criar-WrapperNx {

    $conteudoWrapper = @'
Imports System
Imports System.IO
Imports System.Reflection
Imports System.Threading
Imports System.Windows.Forms
Imports NXOpen

Module WrapperImportSW2NX

    Private logPath As String =
        "C:\temp\wrapper_silent_log.txt"

    Private folderLoad As String = ""

    Private company As String =
        "Perto"

    Private preenchimentoConcluido As Boolean =
        False

    Private timerFormulario As System.Threading.Timer =
        Nothing

    Sub Main(ByVal args() As String)

        If args IsNot Nothing Then

            If args.Length >= 1 Then
                folderLoad = args(0)
            End If

            If args.Length >= 2 Then
                company = args(1)
            End If

        End If

        If File.Exists(logPath) Then
            File.Delete(logPath)
        End If

        Try

            Registrar("INICIO")
            Registrar("folderLoad = " & folderLoad)
            Registrar("company = " & company)

            If String.IsNullOrWhiteSpace(folderLoad) Then

                Throw New Exception(
                    "Pasta de entrada nao informada."
                )

            End If

            If Not Directory.Exists(folderLoad) Then

                Throw New DirectoryNotFoundException(
                    "Pasta nao encontrada: " & folderLoad
                )

            End If

            Dim arquivoSolidWorks As String =
                EncontrarArquivoPrincipal(folderLoad)

            If String.IsNullOrWhiteSpace(
                arquivoSolidWorks
            ) Then

                Throw New FileNotFoundException(
                    "Nenhum arquivo SLDPRT ou SLDASM foi encontrado."
                )

            End If

            Registrar(
                "Arquivo principal = " &
                arquivoSolidWorks
            )

            Dim theSession As Session =
                Session.GetSession()

            Registrar("Sessao NX obtida.")

            Dim loadStatus As PartLoadStatus =
                Nothing

            Dim parteAberta As BasePart =
                theSession.Parts.OpenBaseDisplay(
                    arquivoSolidWorks,
                    loadStatus
                )

            If loadStatus IsNot Nothing Then
                loadStatus.Dispose()
            End If

            If parteAberta Is Nothing Then

                Throw New Exception(
                    "OpenBaseDisplay retornou NULL."
                )

            End If

            Registrar(
                "Parte aberta = " &
                parteAberta.FullPath
            )

            If theSession.Parts.Display Is Nothing Then

                Throw New Exception(
                    "Session.Parts.Display continua NULL."
                )

            End If

            Registrar(
                "Display ativo = " &
                theSession.Parts.Display.FullPath
            )

            Dim caminhoDll As String =
                "\\perto38-novo\NX_Custom\ImportSW2NX.dll"

            If Not File.Exists(caminhoDll) Then

                Throw New FileNotFoundException(
                    "ImportSW2NX.dll nao encontrada.",
                    caminhoDll
                )

            End If

            Dim asm As Assembly =
                Assembly.LoadFrom(caminhoDll)

            Registrar(
                "ImportSW2NX.dll carregada."
            )

            Dim programType As Type =
                asm.GetType("Program")

            If programType Is Nothing Then

                Throw New Exception(
                    "Classe Program nao encontrada."
                )

            End If

            Dim metodoMain As MethodInfo =
                programType.GetMethod(
                    "Main",
                    BindingFlags.Public Or
                    BindingFlags.Static
                )

            If metodoMain Is Nothing Then

                Throw New Exception(
                    "Program.Main nao encontrado."
                )

            End If

            Registrar(
                "Program.Main encontrado."
            )

            timerFormulario =
                New System.Threading.Timer(
                    AddressOf PreencherFormulario,
                    Nothing,
                    500,
                    500
                )

            Registrar(
                "Monitor do formulario iniciado."
            )

            Registrar(
                "Chamando Program.Main..."
            )

            Dim retorno As Object =
                metodoMain.Invoke(
                    Nothing,
                    New Object() {
                        New String() {}
                    }
                )

            Registrar(
                "Program.Main finalizado."
            )

            If retorno Is Nothing Then

                Registrar(
                    "Retorno do Main = NULL"
                )

            Else

                Registrar(
                    "Retorno do Main = " &
                    retorno.ToString()
                )

            End If

            VerificarArquivosGerados(folderLoad)

            Registrar(
                "TESTE CONCLUIDO."
            )

        Catch ex As TargetInvocationException

            Registrar(
                "TARGET INVOCATION EXCEPTION:"
            )

            Registrar(
                ex.ToString()
            )

            If ex.InnerException IsNot Nothing Then

                Registrar(
                    "INNER EXCEPTION:"
                )

                Registrar(
                    ex.InnerException.ToString()
                )

            End If

            Throw

        Catch ex As Exception

            Registrar("ERRO:")
            Registrar(ex.ToString())

            If ex.InnerException IsNot Nothing Then

                Registrar(
                    "INNER EXCEPTION:"
                )

                Registrar(
                    ex.InnerException.ToString()
                )

            End If

            Throw

        Finally

            If timerFormulario IsNot Nothing Then

                timerFormulario.Dispose()
                timerFormulario = Nothing

            End If

            Registrar("FIM")

        End Try

    End Sub

    Private Sub PreencherFormulario(
        ByVal state As Object
    )

        If preenchimentoConcluido Then
            Return
        End If

        Try

            For Each janela As Form In Application.OpenForms

                If janela.GetType().FullName =
                    "ImportSW2NX.Windows.FolderSelectForm" Then

                    preenchimentoConcluido = True

                    Registrar(
                        "Formulario Custom NX localizado."
                    )

                    If janela.InvokeRequired Then

                        janela.Invoke(
                            New MethodInvoker(
                                Sub()
                                    PreencherEClicar(janela)
                                End Sub
                            )
                        )

                    Else

                        PreencherEClicar(janela)

                    End If

                    Exit For

                End If

            Next

        Catch ex As Exception

            Registrar(
                "ERRO NO MONITOR DO FORMULARIO:"
            )

            Registrar(
                ex.ToString()
            )

        End Try

    End Sub

    Private Sub PreencherEClicar(
        ByVal form As Form
    )

        Try

            Registrar(
                "Preenchendo formulario..."
            )

            Dim formType As Type =
                form.GetType()

            Dim campoFolderLoad As FieldInfo =
                formType.GetField(
                    "folderLoad",
                    BindingFlags.Public Or
                    BindingFlags.Instance
                )

            Dim campoCompany As FieldInfo =
                formType.GetField(
                    "company",
                    BindingFlags.Public Or
                    BindingFlags.Instance
                )

            If campoFolderLoad IsNot Nothing Then

                campoFolderLoad.SetValue(
                    form,
                    folderLoad
                )

            End If

            If campoCompany IsNot Nothing Then

                campoCompany.SetValue(
                    form,
                    company
                )

            End If

            Dim campoTxt As FieldInfo =
                formType.GetField(
                    "txt_folderLoad",
                    BindingFlags.NonPublic Or
                    BindingFlags.Instance
                )

            Dim campoCombo As FieldInfo =
                formType.GetField(
                    "comboBox1",
                    BindingFlags.NonPublic Or
                    BindingFlags.Instance
                )

            Dim campoBotao As FieldInfo =
                formType.GetField(
                    "button1",
                    BindingFlags.NonPublic Or
                    BindingFlags.Instance
                )

            If campoTxt Is Nothing Then

                Throw New Exception(
                    "Campo txt_folderLoad nao encontrado."
                )

            End If

            If campoCombo Is Nothing Then

                Throw New Exception(
                    "Campo comboBox1 nao encontrado."
                )

            End If

            If campoBotao Is Nothing Then

                Throw New Exception(
                    "Campo button1 nao encontrado."
                )

            End If

            Dim txt As TextBox =
                CType(
                    campoTxt.GetValue(form),
                    TextBox
                )

            Dim combo As ComboBox =
                CType(
                    campoCombo.GetValue(form),
                    ComboBox
                )

            Dim botao As Button =
                CType(
                    campoBotao.GetValue(form),
                    Button
                )

            txt.Text = folderLoad

            Dim indiceEmpresa As Integer =
                combo.FindStringExact(company)

            If indiceEmpresa >= 0 Then
                combo.SelectedIndex = indiceEmpresa
            Else
                combo.Text = company
            End If

            Registrar(
                "Textbox = " & txt.Text
            )

            Registrar(
                "ComboBox = " & combo.Text
            )

            Registrar(
                "Executando botao OK..."
            )

            botao.PerformClick()

            Registrar(
                "PerformClick executado."
            )

        Catch ex As Exception

            Registrar(
                "ERRO AO PREENCHER FORMULARIO:"
            )

            Registrar(
                ex.ToString()
            )

        End Try

    End Sub

    Private Function EncontrarArquivoPrincipal(
        ByVal pasta As String
    ) As String

        Dim montagens() As String =
            Directory.GetFiles(
                pasta,
                "*.SLDASM",
                SearchOption.TopDirectoryOnly
            )

        If montagens.Length > 0 Then
            Return montagens(0)
        End If

        Dim pecas() As String =
            Directory.GetFiles(
                pasta,
                "*.SLDPRT",
                SearchOption.TopDirectoryOnly
            )

        If pecas.Length > 0 Then
            Return pecas(0)
        End If

        Return Nothing

    End Function

    Private Sub VerificarArquivosGerados(
        ByVal pastaEntrada As String
    )

        Dim pastaMigrada As String =
            Path.Combine(
                pastaEntrada,
                "NXmigratedFiles"
            )

        If Not Directory.Exists(pastaMigrada) Then

            Registrar(
                "NXmigratedFiles nao foi criada."
            )

            Return

        End If

        Registrar(
            "NXmigratedFiles encontrada."
        )

        Dim arquivosGerados() As String =
            Directory.GetFiles(
                pastaMigrada,
                "*",
                SearchOption.AllDirectories
            )

        If arquivosGerados.Length = 0 Then

            Registrar(
                "Nenhum arquivo foi gerado."
            )

            Return

        End If

        For Each arquivo As String In arquivosGerados

            Registrar(
                "GERADO: " & arquivo
            )

        Next

    End Sub

    Private Sub Registrar(
        ByVal mensagem As String
    )

        Try

            File.AppendAllText(
                logPath,
                DateTime.Now.ToString(
                    "yyyy-MM-dd HH:mm:ss.fff"
                ) &
                " | " &
                mensagem &
                vbCrLf
            )

        Catch
        End Try

    End Sub

    Public Function GetUnloadOption(
        ByVal dummy As String
    ) As Integer

        Return Session.LibraryUnloadOption.Immediately

    End Function

End Module
'@

    [System.IO.File]::WriteAllText(
        $wrapperTemporario,
        $conteudoWrapper,
        [System.Text.Encoding]::UTF8
    )

    if (-not (Test-Path $wrapperTemporario)) {
        throw "Nao foi possivel criar o wrapper temporario."
    }
}

# ============================================================
# FUNCOES DO PROCESSO PRINCIPAL
# ============================================================

function Testar-Ambiente {

    Escreve-Titulo "VALIDANDO AMBIENTE"

    $itensObrigatorios = @(
        @{
            Caminho = $dllPdm
            Nome    = "Interop.EdmLib.dll"
        },
        @{
            Caminho = $runJournalExe
            Nome    = "run_journal.exe"
        },
        @{
            Caminho = $importSwDll
            Nome    = "ImportSW2NX.dll"
        }
    )

    foreach ($itemObrigatorio in $itensObrigatorios) {

        if (-not (
                Test-Path -LiteralPath $itemObrigatorio.Caminho
            )) {

            throw "$($itemObrigatorio.Nome) nao encontrado em '$($itemObrigatorio.Caminho)'."
        }
    }

    if (-not (
            Test-Path -LiteralPath $caminhoCredencial
        )) {

        Escreve-Aviso "Credencial do vault nao encontrada."

        $configuradorCredencial =
        Join-Path `
            $PSScriptRoot `
            "configura_credencial.ps1"

        if (-not (
                Test-Path -LiteralPath $configuradorCredencial
            )) {
            throw "configura_credencial.ps1 nao encontrado."
        }

        Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$configuradorCredencial`""
        ) `
            -Wait

        if (-not (
                Test-Path -LiteralPath $caminhoCredencial
            )) {
            throw "A credencial do vault nao foi criada."
        }
    }

    Add-Type -Path $dllPdm

    if (-not (
            Test-Path -LiteralPath $pastaDestino
        )) {

        New-Item `
            -ItemType Directory `
            -Path $pastaDestino `
            -Force |
        Out-Null
    }

    Escreve-Sucesso "Ambiente validado."
}


function Connect-VaultPdm {

    Escreve-Titulo "CONEXAO COM O VAULT"

    $credencial =
    Import-Clixml `
        -LiteralPath $caminhoCredencial

    if ($null -eq $credencial) {
        throw "Nao foi possivel carregar a credencial do vault."
    }

    $senhaSegura =
    $credencial.SenhaCriptografada |
    ConvertTo-SecureString

    $ptrSenha =
    [Runtime.InteropServices.Marshal]::
    SecureStringToBSTR($senhaSegura)

    try {

        $senhaPlana =
        [Runtime.InteropServices.Marshal]::
        PtrToStringBSTR($ptrSenha)

        $vault =
        New-Object EdmLib.EdmVault5Class

        $vault.Login(
            $credencial.Usuario,
            $senhaPlana,
            $vaultName
        )
    }
    finally {

        if ($ptrSenha -ne [IntPtr]::Zero) {

            [Runtime.InteropServices.Marshal]::
            ZeroFreeBSTR($ptrSenha)
        }

        Remove-Variable `
            senhaPlana `
            -ErrorAction SilentlyContinue
    }

    if (-not $vault.IsLoggedIn) {
        throw "Nao foi possivel logar no vault '$vaultName'."
    }

    Escreve-Sucesso "Conectado ao vault '$vaultName'."

    return $vault
}


function Search-ArquivosPdm {

    param(
        [Parameter(Mandatory = $true)]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]$Pesquisa
    )

    $codigoBusca =
    $Pesquisa.Replace(
        "*",
        "%"
    )

    if ($codigoBusca -notmatch "%") {
        $codigoBusca = "%$codigoBusca%"
    }

    $busca =
    $Vault.CreateSearch()

    $busca.FileName =
    $codigoBusca

    $busca.FindHistoricStates =
    $false

    $resultados =
    [System.Collections.Generic.List[object]]::new()

    $resultado =
    $busca.GetFirstResult()

    while ($null -ne $resultado) {

        $resultados.Add($resultado)

        $resultado =
        $busca.GetNextResult()
    }

    return $resultados.ToArray()
}


function Get-CodigoPdm {

    param(
        [Parameter(Mandatory = $true)]
        $Vault
    )

    Escreve-Titulo "BUSCA DE DOCUMENTO"

    Write-Host "Exemplo de codigo: 260.02.002"
    Write-Host "Exemplo com curinga: 260.*"
    Write-Host ""

    while ($true) {

        $codigoDigitado = (Read-Host "Digite o codigo da peca").Trim()

        if ([string]::IsNullOrEmpty($codigoDigitado)) {

            Escreve-Aviso "O codigo nao pode ficar vazio."
            continue
        }


        $listaResultados =
        @(
            Search-ArquivosPdm `
                -Vault $Vault `
                -Pesquisa $codigoDigitado
        )

        if ($listaResultados.Count -eq 0) {

            Escreve-Aviso "Nenhum resultado encontrado."
            continue
        }

        $codigosEncontrados =
        @(
            foreach ($item in $listaResultados) {

                $nomeSemExtensao =
                [System.IO.Path]::
                GetFileNameWithoutExtension(
                    $item.Name
                )

                if (
                    $nomeSemExtensao -match
                    '\d+\.\d+\.\d+'
                ) {
                    $Matches[0]
                }
            }
        ) |
        Sort-Object -Unique

        if (-not $codigoDigitado.Contains("*")) {

            if (
                $codigosEncontrados -contains
                $codigoDigitado
            ) {

                return [PSCustomObject]@{
                    Codigo     = $codigoDigitado
                    Resultados = $listaResultados
                }
            }

            Escreve-Aviso "Codigo exato nao encontrado."
            continue
        }

        if ($codigosEncontrados.Count -eq 0) {

            Escreve-Aviso `
                "Foram encontrados arquivos, mas nenhum codigo valido foi identificado."

            continue
        }

        Escreve-Titulo "CODIGOS ENCONTRADOS"

        foreach ($codigo in $codigosEncontrados) {
            Write-Host "  $codigo"
        }

        Write-Host ""
    }
}


function Get-PastaDestinoCodigo {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Codigo
    )

    $nomePastaSeguro =
    $Codigo

    foreach (
        $caractereInvalido in
        [System.IO.Path]::GetInvalidFileNameChars()
    ) {

        $nomePastaSeguro =
        $nomePastaSeguro.Replace(
            $caractereInvalido,
            "_"
        )
    }

    $pastaCodigo =
    Join-Path `
        $pastaDestino `
        $nomePastaSeguro

    if (-not (
            Test-Path -LiteralPath $pastaCodigo
        )) {

        New-Item `
            -ItemType Directory `
            -Path $pastaCodigo `
            -Force |
        Out-Null

        Escreve-Info "Pasta criada: $pastaCodigo"
    }

    return $pastaCodigo
}


function Copy-ArquivosPdm {

    param(
        [Parameter(Mandatory = $true)]
        $Vault,

        [Parameter(Mandatory = $true)]
        [object[]]$Resultados,

        [Parameter(Mandatory = $true)]
        [string]$PastaDestinoCodigo
    )

    Escreve-Titulo "DOWNLOAD DOS ARQUIVOS"

    $copiados =
    0

    $existentes =
    0

    $falhas =
    0

    foreach ($resultadoPdm in $Resultados) {

        try {

            $arquivoDestino =
            Join-Path `
                $PastaDestinoCodigo `
                $resultadoPdm.Name

            if (
                Test-Path -LiteralPath $arquivoDestino
            ) {

                Escreve-Aviso `
                    "Ja baixado: $($resultadoPdm.Name)"

                $existentes++
                continue
            }

            $pastaPai =
            $null

            $arquivoPdm =
            $Vault.GetFileFromPath(
                $resultadoPdm.Path,
                [ref]$pastaPai
            )

            if ($null -eq $arquivoPdm) {

                throw `
                    "Nao foi possivel obter o arquivo no vault."
            }

            if ($null -eq $pastaPai) {

                throw `
                    "A pasta do arquivo nao foi localizada no vault."
            }

            $versao =
            0

            $folderId =
            $pastaPai.ID

            $arquivoPdm.GetFileCopy(
                0,
                [ref]$versao,
                [ref]$folderId,
                0,
                ""
            )

            $localPath =
            $arquivoPdm.GetLocalPath(
                $pastaPai.ID
            )

            if (-not (
                    Test-Path -LiteralPath $localPath
                )) {

                throw `
                    "Arquivo nao encontrado no cache local."
            }

            Copy-Item `
                -LiteralPath $localPath `
                -Destination $arquivoDestino

            Escreve-Sucesso `
                "Copiado: $($resultadoPdm.Name)"

            $copiados++
        }
        catch {

            Escreve-Erro `
                "$($resultadoPdm.Name) - $($_.Exception.Message)"

            $falhas++
        }
    }

    Write-Host ""
    Escreve-Info "Novos: $copiados"
    Escreve-Info "Ja existentes: $existentes"
    Escreve-Info "Falhas: $falhas"

    if (
        $copiados -eq 0 -and
        $existentes -eq 0
    ) {

        throw "Nenhum arquivo ficou disponivel para conversao."
    }
}


function Get-ArquivoSolidWorksPrincipal {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Pasta
    )

    $arquivoPrincipal =
    Get-ChildItem `
        -LiteralPath $Pasta `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -ieq ".SLDASM"
    } |
    Select-Object -First 1

    if ($null -eq $arquivoPrincipal) {

        $arquivoPrincipal =
        Get-ChildItem `
            -LiteralPath $Pasta `
            -File `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -ieq ".SLDPRT"
        } |
        Select-Object -First 1
    }

    if ($null -eq $arquivoPrincipal) {

        throw `
            "Nenhum arquivo SLDPRT ou SLDASM foi encontrado."
    }

    return $arquivoPrincipal
}


function Get-ArquivosConvertidos {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PastaNx
    )

    if (-not (
            Test-Path -LiteralPath $PastaNx
        )) {

        return [PSCustomObject]@{
            Prt = @()
            Jt  = @()
        }
    }

    $arquivos =
    @(
        Get-ChildItem `
            -LiteralPath $PastaNx `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    return [PSCustomObject]@{
        Prt = @(
            $arquivos |
            Where-Object {
                $_.Extension -ieq ".prt"
            }
        )

        Jt  = @(
            $arquivos |
            Where-Object {
                $_.Extension -ieq ".jt"
            }
        )
    }
}


function Invoke-ConversaoNx {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PastaEntrada
    )

    $pastaNx =
    Join-Path `
        $PastaEntrada `
        "NXmigratedFiles"

    $arquivosExistentes =
    Get-ArquivosConvertidos `
        -PastaNx $pastaNx

    if ($arquivosExistentes.Prt.Count -gt 0) {

        Escreve-Titulo "CONVERSAO NX"

        Escreve-Aviso `
            "A conversao nao sera repetida."

        foreach ($prt in $arquivosExistentes.Prt) {

            Escreve-Info `
                "PRT existente: $($prt.Name)"
        }

        return $pastaNx
    }

    if (
        Test-Path -LiteralPath $pastaNx
    ) {

        Escreve-Aviso `
            "Pasta de conversao incompleta encontrada."

        Escreve-Aviso `
            "Removendo somente a saida incompleta."

        Remove-Item `
            -LiteralPath $pastaNx `
            -Recurse `
            -Force
    }

    Escreve-Titulo "CONVERSAO SILENCIOSA NO NX"

    Criar-WrapperNx

    Escreve-Info "Executando NX batch..."

    & $runJournalExe `
        $wrapperTemporario `
        "-args" `
        $PastaEntrada `
        $empresa

    $codigoSaidaNx =
    $LASTEXITCODE

    if ($codigoSaidaNx -ne 0) {

        throw `
            "NX retornou codigo de erro $codigoSaidaNx. Verifique '$logNx'."
    }

    $arquivosGerados =
    Get-ArquivosConvertidos `
        -PastaNx $pastaNx

    if ($arquivosGerados.Prt.Count -eq 0) {

        throw `
            "A conversao terminou, mas nenhum arquivo PRT foi gerado."
    }

    Escreve-Sucesso "Conversao NX concluida."

    return $pastaNx
}


function Show-ResultadoConversao {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PastaNx
    )

    $resultado =
    Get-ArquivosConvertidos `
        -PastaNx $PastaNx

    Escreve-Titulo "RESULTADO"

    foreach ($arquivoPrt in $resultado.Prt) {

        Escreve-Sucesso `
            "PRT: $($arquivoPrt.Name)"
    }

    if ($resultado.Jt.Count -eq 0) {

        Escreve-Aviso `
            "Nenhum arquivo JT encontrado."
    }
    else {

        foreach ($arquivoJt in $resultado.Jt) {

            Escreve-Sucesso `
                "JT: $($arquivoJt.Name)"
        }
    }

    return $resultado
}


function Invoke-ImportacaoTeamcenter {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PastaNx
    )

    Escreve-Titulo "IMPORTACAO TEAMCENTER"

    $scriptTc =
    Join-Path `
        $PSScriptRoot `
        "importar_teamcenter.ps1"

    if (-not (
            Test-Path -LiteralPath $scriptTc
        )) {

        throw `
            "importar_teamcenter.ps1 nao encontrado em '$scriptTc'."
    }

    $ps64 =
    Join-Path `
        $env:WINDIR `
        "Sysnative\WindowsPowerShell\v1.0\powershell.exe"

    if (-not (
            Test-Path -LiteralPath $ps64
        )) {

        $ps64 =
        Join-Path `
            $env:WINDIR `
            "System32\WindowsPowerShell\v1.0\powershell.exe"
    }

    if (-not (
            Test-Path -LiteralPath $ps64
        )) {

        throw "PowerShell 64 bits nao encontrado."
    }

    & $ps64 `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $scriptTc `
        -PastaNx $PastaNx

    if ($LASTEXITCODE -ne 0) {

        throw `
            "A importacao Teamcenter falhou com codigo $LASTEXITCODE."
    }

    Escreve-Sucesso "Importacao Teamcenter concluida."
}


# ============================================================
# EXECUCAO PRINCIPAL
# ============================================================

try {

    Testar-Ambiente

    $vault =
    Connect-VaultPdm

    $selecao =
    Get-CodigoPdm `
        -Vault $vault

    $codigoDigitado =
    $selecao.Codigo

    $listaResultados =
    @(
        $selecao.Resultados
    )

    $pastaDestinoFinal =
    Get-PastaDestinoCodigo `
        -Codigo $codigoDigitado

    Copy-ArquivosPdm `
        -Vault $vault `
        -Resultados $listaResultados `
        -PastaDestinoCodigo $pastaDestinoFinal

    $arquivoPrincipal =
    Get-ArquivoSolidWorksPrincipal `
        -Pasta $pastaDestinoFinal

    Escreve-Info `
        "Arquivo principal: $($arquivoPrincipal.Name)"

    $pastaNxMigrated =
    Invoke-ConversaoNx `
        -PastaEntrada $pastaDestinoFinal

    $resultadoConversao =
    Show-ResultadoConversao `
        -PastaNx $pastaNxMigrated

    if ($resultadoConversao.Prt.Count -eq 0) {

        throw `
            "Nenhum PRT esta disponivel para importar no Teamcenter."
    }

    Invoke-ImportacaoTeamcenter `
        -PastaNx $pastaNxMigrated

    Escreve-Titulo "PROCESSO CONCLUIDO"

    Escreve-Sucesso `
        "Codigo processado: $codigoDigitado"

    Escreve-Info `
        "Saida NX: $pastaNxMigrated"

    exit 0
}
catch {

    Write-Host ""

    Escreve-Erro `
        $_.Exception.Message

    Write-Host ""
    Write-Host "[ERRO COMPLETO]" -ForegroundColor DarkGray
    Write-Host $_.Exception.ToString() -ForegroundColor DarkGray
    Write-Host ""

    exit 1
}
finally {

    Remove-Variable `
        senhaPlana `
        -ErrorAction SilentlyContinue

    if (
        Test-Path -LiteralPath $wrapperTemporario
    ) {

        Remove-Item `
            -LiteralPath $wrapperTemporario `
            -Force `
            -ErrorAction SilentlyContinue
    }
}