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
# EXECUCAO PRINCIPAL
# ============================================================

try {

    Escreve-Titulo "VALIDANDO AMBIENTE"

    if (-not (Test-Path $dllPdm)) {
        throw "Interop.EdmLib.dll nao encontrada em '$dllPdm'."
    }

    if (-not (Test-Path $caminhoCredencial)) {

        Start-Process powershell.exe `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$PSScriptRoot\configura_credencial.ps1`"" `
            -Wait

    }

    if (-not (Test-Path $runJournalExe)) {
        throw "run_journal.exe nao encontrado em '$runJournalExe'."
    }

    if (-not (Test-Path $importSwDll)) {
        throw "ImportSW2NX.dll nao encontrada em '$importSwDll'."
    }

    Add-Type -Path $dllPdm

    Escreve-Sucesso "Ambiente validado."

    # ========================================================
    # CONEXAO COM O VAULT
    # ========================================================

    Escreve-Titulo "CONEXAO COM O VAULT"

    $credencial = Import-Clixml `
        -Path $caminhoCredencial

    $senhaSegura =
    $credencial.SenhaCriptografada |
    ConvertTo-SecureString

    $ptrSenha = `
        [Runtime.InteropServices.Marshal]::
    SecureStringToBSTR($senhaSegura)

    try {

        $senhaPlana = `
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

    }

    if (-not $vault.IsLoggedIn) {
        throw "Nao foi possivel logar no vault '$vaultName'."
    }

    Escreve-Sucesso "Conectado ao vault '$vaultName'."

    if (-not (Test-Path $pastaDestino)) {

        New-Item `
            -ItemType Directory `
            -Path $pastaDestino `
            -Force |
        Out-Null

    }

    # ========================================================
    # BUSCA
    # ========================================================


    Escreve-Titulo "BUSCA DE DOCUMENTO"

    Write-Host "Exemplo de codigo de peca: 260.02.002"
    Write-Host "Exemplo de pesquisa nao exata: 260.*"
    Write-Host "(pode demorar alguns segundos)"
    Write-Host ""

    $codigoDigitado = $null
    $listaResultados = @()

    $codigoDigitado =
    Read-Host "Digite o codigo da peca"

    while ($true) {

        $codigoBusca =
        $codigoDigitado.Replace("*", "%")

        if ($codigoBusca -notmatch "%") {
            $codigoBusca = "%$codigoBusca%"
        }

        $busca = $vault.CreateSearch()
        $busca.FileName = $codigoBusca
        $busca.FindHistoricStates = $false

        $listaResultados = @()

        $resultado = $busca.GetFirstResult()

        while ($null -ne $resultado) {

            $listaResultados += $resultado
            $resultado = $busca.GetNextResult()

        }

        if ($listaResultados.Count -eq 0) {

            Escreve-Aviso "Nenhum resultado encontrado."

            $codigoDigitado =
            Read-Host "Digite outra pesquisa"

            continue
        }

        #
        # código exato
        #

        #
        # código exato
        #

        if (-not $codigoDigitado.Contains("*")) {

            $codigosExatos = @()

            foreach ($item in $listaResultados) {

                $nome =
                [System.IO.Path]::GetFileNameWithoutExtension(
                    $item.Name
                )

                if ($nome -match '\d+\.\d+\.\d+') {

                    $codigosExatos += $Matches[0]

                }

            }

            $codigosExatos =
            $codigosExatos |
            Select-Object -Unique

            if ($codigosExatos -contains $codigoDigitado) {

                break

            }

            Escreve-Aviso `
                "Codigo nao encontrado."

            $codigoDigitado =
            Read-Host "Digite outro codigo"

            continue

        }

        Escreve-Titulo "CODIGOS ENCONTRADOS"

        $codigosEncontrados = @()

        foreach ($item in $listaResultados) {

            $nome =
            [System.IO.Path]::GetFileNameWithoutExtension(
                $item.Name
            )

            if ($nome -match '\d+\.\d+\.\d+') {

                $codigo = $Matches[0]

                if ($codigosEncontrados -notcontains $codigo) {

                    $codigosEncontrados += $codigo

                }

            }
        }

        $codigosEncontrados |
        Sort-Object |
        ForEach-Object {
            Write-Host "  $_"
        }

        Write-Host ""

        $codigoDigitado =
        Read-Host `
            "Digite o codigo da peca"

    }


    # ========================================================
    # PASTA DO CODIGO
    # ========================================================

    $nomePastaSeguro = $codigoDigitado

    foreach (
        $caractereInvalido in
        [System.IO.Path]::
        GetInvalidFileNameChars()
    ) {

        $nomePastaSeguro =
        $nomePastaSeguro.Replace(
            $caractereInvalido,
            "_"
        )

    }

    $pastaDestinoFinal = Join-Path `
        $pastaDestino `
        $nomePastaSeguro

    if (-not (Test-Path $pastaDestinoFinal)) {

        New-Item `
            -ItemType Directory `
            -Path $pastaDestinoFinal `
            -Force |
        Out-Null

        Escreve-Info `
            "Pasta criada: $pastaDestinoFinal"

    }

    # ========================================================
    # DOWNLOAD
    # ========================================================

    Escreve-Titulo "DOWNLOAD DOS ARQUIVOS"

    $copiados = 0
    $existentes = 0
    $falhas = 0

    foreach ($item in $listaResultados) {

        try {

            $pastaPai = $null

            $arquivo =
            $vault.GetFileFromPath(
                $item.Path,
                [ref]$pastaPai
            )

            if ($null -eq $arquivo) {

                Escreve-Erro `
                    "Nao foi possivel obter '$($item.Name)'."

                $falhas++
                continue

            }

            $arquivoDestino = Join-Path `
                $pastaDestinoFinal `
                $item.Name

            if (Test-Path $arquivoDestino) {

                Escreve-Aviso `
                    "Ja baixado: $($item.Name)"

                $existentes++
                continue

            }

            $versao = 0
            $folder = $pastaPai.ID

            $arquivo.GetFileCopy(
                0,
                [ref]$versao,
                [ref]$folder,
                0,
                ""
            )

            $localPath =
            $arquivo.GetLocalPath(
                $pastaPai.ID
            )

            if (-not (Test-Path $localPath)) {

                Escreve-Erro `
                    "Arquivo nao encontrado no cache: $($item.Name)"

                $falhas++
                continue

            }

            Copy-Item `
                -LiteralPath $localPath `
                -Destination $arquivoDestino

            Escreve-Sucesso `
                "Copiado: $($item.Name)"

            $copiados++

        }
        catch {
            Escreve-Erro "$($item.Name) - $($_.Exception.Message)"
            $falhas++
        }

    }

    Write-Host ""
    Escreve-Info "Novos: $copiados"
    Escreve-Info "Ja existentes: $existentes"
    Escreve-Info "Falhas: $falhas"

    # ========================================================
    # LOCALIZA ARQUIVO PRINCIPAL
    # ========================================================

    $arquivoPrincipal =
    Get-ChildItem `
        -LiteralPath $pastaDestinoFinal `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -ieq ".SLDASM"
    } |
    Select-Object -First 1

    if ($null -eq $arquivoPrincipal) {

        $arquivoPrincipal =
        Get-ChildItem `
            -LiteralPath $pastaDestinoFinal `
            -File `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -ieq ".SLDPRT"
        } |
        Select-Object -First 1

    }

    if ($null -eq $arquivoPrincipal) {
        throw "Nenhum arquivo SLDPRT ou SLDASM foi encontrado para conversao."
    }

    Escreve-Info `
        "Arquivo principal: $($arquivoPrincipal.Name)"

    # ========================================================
    # REMOVE SAIDAS ANTIGAS
    # ========================================================

    $pastaNxMigrated = Join-Path `
        $pastaDestinoFinal `
        "NXmigratedFiles"

    if (Test-Path $pastaNxMigrated) {

        Escreve-Aviso `
            "Removendo conversao anterior."

        Remove-Item `
            -LiteralPath $pastaNxMigrated `
            -Recurse `
            -Force

    }

    # ========================================================
    # CRIA E EXECUTA WRAPPER NX
    # ========================================================

    Escreve-Titulo "CONVERSAO SILENCIOSA NO NX"

    Criar-WrapperNx

    Escreve-Info `
        "Executando NX batch..."

    & $runJournalExe `
        $wrapperTemporario `
        "-args" `
        $pastaDestinoFinal `
        $empresa

    $codigoSaidaNx = $LASTEXITCODE

    if ($codigoSaidaNx -ne 0) {

        throw `
            "NX retornou codigo de erro $codigoSaidaNx. Verifique '$logNx'."

    }

    # ========================================================
    # VALIDA RESULTADOS
    # ========================================================

    if (-not (Test-Path $pastaNxMigrated)) {

        throw `
            "A pasta NXmigratedFiles nao foi criada. Verifique '$logNx'."

    }

    $arquivosPrt =
    Get-ChildItem `
        -LiteralPath $pastaNxMigrated `
        -Filter "*.prt" `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue

    $arquivosJt =
    Get-ChildItem `
        -LiteralPath $pastaNxMigrated `
        -Filter "*.jt" `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue

    Escreve-Titulo "RESULTADO"

    if ($arquivosPrt.Count -eq 0) {

        Escreve-Erro `
            "Nenhum arquivo PRT foi gerado."

    }
    else {

        foreach ($arquivoPrt in $arquivosPrt) {

            Escreve-Sucesso `
                "PRT: $($arquivoPrt.Name)"

        }

    }

    if ($arquivosJt.Count -eq 0) {

        Escreve-Erro `
            "Nenhum arquivo JT foi gerado."

    }
    else {

        foreach ($arquivoJt in $arquivosJt) {

            Escreve-Sucesso `
                "JT: $($arquivoJt.Name)"

        }

    }

    if (
        $arquivosPrt.Count -eq 0 -or
        $arquivosJt.Count -eq 0
    ) {

        throw `
            "Conversao incompleta. Verifique '$logNx'."

    }

    Write-Host ""
    Escreve-Sucesso `
        "Processo concluido automaticamente."

    Escreve-Info `
        "Saida: $pastaNxMigrated"

}


catch {

    Write-Host ""
    Escreve-Erro $_.Exception.Message
    Write-Host ""

    exit 1

}
finally {

    Remove-Variable `
        senhaPlana `
        -ErrorAction SilentlyContinue

    if (Test-Path $wrapperTemporario) {

        Remove-Item `
            -LiteralPath $wrapperTemporario `
            -Force `
            -ErrorAction SilentlyContinue

    }

}

Write-Host ""
exit 0