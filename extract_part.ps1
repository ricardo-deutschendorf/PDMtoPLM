# ============================================================
# PDM TO PLM
# Downloads SolidWorks files from PDM, converts them to NX
# and imports the generated files into Teamcenter.
# ============================================================

$ErrorActionPreference = "Stop"


# ============================================================
# CONFIGURATION
# ============================================================

$pdmLibraryPath =
"C:\Perto\Templates\CodAplic\Interop.EdmLib.dll"

$vaultName =
"Perto"

$vaultCredentialPath =
Join-Path `
    $PSScriptRoot `
    "vault_credentials.xml"

$downloadRootPath =
"C:\temp\importados"

$runJournalPath =
"C:\Siemens\NX2312\NXBIN\run_journal.exe"

$importSwLibraryPath =
"\\perto38-novo\NX_Custom\ImportSW2NX.dll"

$companyName =
"Perto"

$nxLogPath =
"C:\temp\wrapper_silent_log.txt"

$temporaryWrapperPath =
Join-Path `
    $env:TEMP `
    "PDMtoPLM_wrapper.vb"

$teamcenterFunctionsPath =
Join-Path `
    $PSScriptRoot `
    "teamcenter_functions.ps1"

if (-not (
        Test-Path -LiteralPath $teamcenterFunctionsPath
    )) {
    throw "Teamcenter functions file not found at '$teamcenterFunctionsPath'."
}

. $teamcenterFunctionsPath


# ============================================================
# CONSOLE OUTPUT
# ============================================================

function Write-Section {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor White
    Write-Host " $Title" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor White
}


function Write-Success {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Failure {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}


function Write-WarningMessage {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [WARNING] $Message" -ForegroundColor Yellow
}


function Write-Info {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  -> $Message" -ForegroundColor Gray
}


# ============================================================
# NX WRAPPER CREATION
# ============================================================

function New-NxImportWrapper {

    $wrapperContent = @'
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

    Private formCompleted As Boolean =
        False

    Private formTimer As System.Threading.Timer =
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

            WriteLog("START")
            WriteLog("folderLoad = " & folderLoad)
            WriteLog("company = " & company)

            If String.IsNullOrWhiteSpace(folderLoad) Then

                Throw New Exception(
                    "Input folder was not provided."
                )

            End If

            If Not Directory.Exists(folderLoad) Then

                Throw New DirectoryNotFoundException(
                    "Folder not found: " & folderLoad
                )

            End If

            Dim solidWorksFile As String =
                FindMainFile(folderLoad)

            If String.IsNullOrWhiteSpace(
                solidWorksFile
            ) Then

                Throw New FileNotFoundException(
                    "No SLDPRT or SLDASM file was found."
                )

            End If

            WriteLog(
                "Main file = " &
                solidWorksFile
            )

            Dim theSession As Session =
    Session.GetSession()

WriteLog("NX session obtained.")

Dim loadStatus As PartLoadStatus =
    Nothing

Dim openedPart As BasePart =
    theSession.Parts.OpenBaseDisplay(
        solidWorksFile,
        loadStatus
    )

If loadStatus IsNot Nothing Then
    loadStatus.Dispose()
End If

If openedPart Is Nothing Then

    Throw New Exception(
        "OpenBaseDisplay returned NULL."
    )

End If

WriteLog(
    "Opened part = " &
    openedPart.FullPath
)

If theSession.Parts.Display Is Nothing Then

    Throw New Exception(
        "Session.Parts.Display remains NULL."
    )

End If

WriteLog(
    "Active display = " &
    theSession.Parts.Display.FullPath
)

Try

    Dim structureLog As String =
        Path.Combine(
            folderLoad,
            "estrutura_montagem.txt"
        )
    If File.Exists(structureLog) Then
        File.Delete(structureLog)
    End If

    Dim workPart As Part =
        CType(
            theSession.Parts.Display,
            Part
        )

    If workPart.ComponentAssembly IsNot Nothing AndAlso
       workPart.ComponentAssembly.RootComponent IsNot Nothing Then

        File.AppendAllText(
            structureLog,
            "MONTAGEM: " &
            workPart.Leaf & vbCrLf
        )

        DumpComponents(
            workPart.ComponentAssembly.RootComponent,
            structureLog,
            0
        )

        WriteLog(
            "Estrutura exportada: " &
            structureLog
        )

    Else

        WriteLog(
            "Nenhuma estrutura de montagem encontrada."
        )

    End If

Catch ex As Exception

    WriteLog(
        "ERRO AO EXPORTAR ESTRUTURA:"
    )

    WriteLog(
        ex.ToString()
    )

End Try

            Dim libraryPath As String =
                "\\perto38-novo\NX_Custom\ImportSW2NX.dll"

            If Not File.Exists(libraryPath) Then

                Throw New FileNotFoundException(
                    "ImportSW2NX.dll was not found.",
                    libraryPath
                )

            End If

            Dim assembly As Assembly =
                Assembly.LoadFrom(libraryPath)

            WriteLog(
                "ImportSW2NX.dll loaded."
            )

            Dim programType As Type =
                assembly.GetType("Program")

            If programType Is Nothing Then

                Throw New Exception(
                    "Program class was not found."
                )

            End If

            Dim mainMethod As MethodInfo =
                programType.GetMethod(
                    "Main",
                    BindingFlags.Public Or
                    BindingFlags.Static
                )

            If mainMethod Is Nothing Then

                Throw New Exception(
                    "Program.Main was not found."
                )

            End If

            WriteLog(
                "Program.Main found."
            )

            formTimer =
                New System.Threading.Timer(
                    AddressOf FillForm,
                    Nothing,
                    500,
                    500
                )

            WriteLog(
                "Form monitor started."
            )

            WriteLog(
                "Calling Program.Main..."
            )

            Dim result As Object =
                mainMethod.Invoke(
                    Nothing,
                    New Object() {
                        New String() {}
                    }
                )

            WriteLog(
                "Program.Main completed."
            )

            If result Is Nothing Then

                WriteLog(
                    "Main result = NULL"
                )

            Else

                WriteLog(
                    "Main result = " &
                    result.ToString()
                )

            End If

            ValidateGeneratedFiles(folderLoad)

            ExportNxPartNames(
            theSession,
            folderLoad
            )


            WriteLog(
                "PROCESS COMPLETED."
            )

        Catch ex As TargetInvocationException

            WriteLog(
                "TARGET INVOCATION EXCEPTION:"
            )

            WriteLog(
                ex.ToString()
            )

            If ex.InnerException IsNot Nothing Then

                WriteLog(
                    "INNER EXCEPTION:"
                )

                WriteLog(
                    ex.InnerException.ToString()
                )

            End If

            Throw

        Catch ex As Exception

            WriteLog("ERROR:")
            WriteLog(ex.ToString())

            If ex.InnerException IsNot Nothing Then

                WriteLog(
                    "INNER EXCEPTION:"
                )

                WriteLog(
                    ex.InnerException.ToString()
                )

            End If

            Throw

        Finally

            If formTimer IsNot Nothing Then

                formTimer.Dispose()
                formTimer = Nothing

            End If

            WriteLog("END")

        End Try

    End Sub

    Private Sub FillForm(
        ByVal state As Object
    )

        If formCompleted Then
            Return
        End If

        Try

            For Each window As Form In Application.OpenForms

                If window.GetType().FullName =
                    "ImportSW2NX.Windows.FolderSelectForm" Then

                    formCompleted = True

                    WriteLog(
                        "Custom NX form found."
                    )

                    If window.InvokeRequired Then

                        window.Invoke(
                            New MethodInvoker(
                                Sub()
                                    FillAndSubmit(window)
                                End Sub
                            )
                        )

                    Else

                        FillAndSubmit(window)

                    End If

                    Exit For

                End If

            Next

        Catch ex As Exception

            WriteLog(
                "FORM MONITOR ERROR:"
            )

            WriteLog(
                ex.ToString()
            )

        End Try

    End Sub

    Private Sub FillAndSubmit(
        ByVal form As Form
    )

        Try

            WriteLog(
                "Filling form..."
            )

            Dim formType As Type =
                form.GetType()

            Dim folderLoadField As FieldInfo =
                formType.GetField(
                    "folderLoad",
                    BindingFlags.Public Or
                    BindingFlags.Instance
                )

            Dim companyField As FieldInfo =
                formType.GetField(
                    "company",
                    BindingFlags.Public Or
                    BindingFlags.Instance
                )

            If folderLoadField IsNot Nothing Then

                folderLoadField.SetValue(
                    form,
                    folderLoad
                )

            End If

            If companyField IsNot Nothing Then

                companyField.SetValue(
                    form,
                    company
                )

            End If

            Dim textBoxField As FieldInfo =
                formType.GetField(
                    "txt_folderLoad",
                    BindingFlags.NonPublic Or
                    BindingFlags.Instance
                )

            Dim comboBoxField As FieldInfo =
                formType.GetField(
                    "comboBox1",
                    BindingFlags.NonPublic Or
                    BindingFlags.Instance
                )

            Dim buttonField As FieldInfo =
                formType.GetField(
                    "button1",
                    BindingFlags.NonPublic Or
                    BindingFlags.Instance
                )

            If textBoxField Is Nothing Then

                Throw New Exception(
                    "txt_folderLoad field was not found."
                )

            End If

            If comboBoxField Is Nothing Then

                Throw New Exception(
                    "comboBox1 field was not found."
                )

            End If

            If buttonField Is Nothing Then

                Throw New Exception(
                    "button1 field was not found."
                )

            End If

            Dim folderTextBox As TextBox =
                CType(
                    textBoxField.GetValue(form),
                    TextBox
                )

            Dim companyComboBox As ComboBox =
                CType(
                    comboBoxField.GetValue(form),
                    ComboBox
                )

            Dim submitButton As Button =
                CType(
                    buttonField.GetValue(form),
                    Button
                )

            folderTextBox.Text = folderLoad

            Dim companyIndex As Integer =
                companyComboBox.FindStringExact(company)

            If companyIndex >= 0 Then
                companyComboBox.SelectedIndex = companyIndex
            Else
                companyComboBox.Text = company
            End If

            WriteLog(
                "TextBox = " &
                folderTextBox.Text
            )

            WriteLog(
                "ComboBox = " &
                companyComboBox.Text
            )

            WriteLog(
                "Executing OK button..."
            )

            submitButton.PerformClick()

            WriteLog(
                "PerformClick executed."
            )

        Catch ex As Exception

            WriteLog(
                "FORM FILL ERROR:"
            )

            WriteLog(
                ex.ToString()
            )

        End Try

    End Sub

    Private Function FindMainFile(
        ByVal folderPath As String
    ) As String

        Dim assemblyFiles() As String =
            Directory.GetFiles(
                folderPath,
                "*.SLDASM",
                SearchOption.TopDirectoryOnly
            )

        If assemblyFiles.Length > 0 Then
            Return assemblyFiles(0)
        End If

        Dim partFiles() As String =
            Directory.GetFiles(
                folderPath,
                "*.SLDPRT",
                SearchOption.TopDirectoryOnly
            )

        If partFiles.Length > 0 Then
            Return partFiles(0)
        End If

        Return Nothing

    End Function

    Private Sub ValidateGeneratedFiles(
        ByVal inputFolder As String
    )

        Dim migratedFolder As String =
            Path.Combine(
                inputFolder,
                "NXmigratedFiles"
            )

        If Not Directory.Exists(migratedFolder) Then

            WriteLog(
                "NXmigratedFiles was not created."
            )

            Return

        End If

        WriteLog(
            "NXmigratedFiles found."
        )

        Dim generatedFiles() As String =
            Directory.GetFiles(
                migratedFolder,
                "*",
                SearchOption.AllDirectories
            )

        If generatedFiles.Length = 0 Then

            WriteLog(
                "No files were generated."
            )

            Return

        End If

        For Each generatedFile As String In generatedFiles

            WriteLog(
                "GENERATED: " & generatedFile
            )

        Next

    End Sub

    Private Sub WriteLog(
        ByVal message As String
    )

        Try

            File.AppendAllText(
                logPath,
                DateTime.Now.ToString(
                    "yyyy-MM-dd HH:mm:ss.fff"
                ) &
                " | " &
                message &
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

    Private Sub DumpComponents(
    ByVal component As NXOpen.Assemblies.Component,
    ByVal logFile As String,
    ByVal level As Integer
)

    Try

        Dim prefix As String =
            New String(" "c, level * 2)

        For Each child As NXOpen.Assemblies.Component In
            component.GetChildren()

            File.AppendAllText(
                logFile,
                prefix &
                child.DisplayName &
                vbCrLf
            )

            DumpComponents(
                child,
                logFile,
                level + 1
            )

        Next

    Catch
    End Try

End Sub

Private Sub ExportNxPartNames(
    ByVal theSession As Session,
    ByVal inputFolder As String
)

    Dim migratedFolder As String =
        Path.Combine(
            inputFolder,
            "NXmigratedFiles"
        )

    Dim outputFile As String =
        Path.Combine(
            migratedFolder,
            "NomesNx.txt"
        )

    If Not Directory.Exists(migratedFolder) Then

        WriteLog(
            "NXmigratedFiles nao encontrada para exportar nomes."
        )

        Return

    End If

    If File.Exists(outputFile) Then
        File.Delete(outputFile)
    End If

    Dim attributesOutputFile As String =
    Path.Combine(
        migratedFolder,
        "AtributosNx.txt"
    )

If File.Exists(attributesOutputFile) Then
    File.Delete(attributesOutputFile)
End If

    Dim prtFiles() As String =
        Directory.GetFiles(
            migratedFolder,
            "*.prt",
            SearchOption.TopDirectoryOnly
        )

    For Each prtFile As String In prtFiles

        Dim fileCode As String =
            Path.GetFileNameWithoutExtension(
                prtFile
            )

        Try

            Dim loadStatus As PartLoadStatus =
                Nothing

            Dim nxPart As BasePart =
                theSession.Parts.OpenBaseDisplay(
                    prtFile,
                    loadStatus
                )

            If loadStatus IsNot Nothing Then
                loadStatus.Dispose()
            End If

            If nxPart Is Nothing Then

                WriteLog(
                    "Nao foi possivel abrir: " &
                    prtFile
                )

                Continue For

            End If

            Dim attributeValue As String = ""

            Dim attributes() As NXObject.AttributeInformation =
                nxPart.GetUserAttributes()

File.AppendAllText(
    attributesOutputFile,
    "====================================" & vbCrLf &
    "ARQUIVO: " & fileCode & vbCrLf
)

For Each attributeInfo As NXObject.AttributeInformation In attributes

    Dim attributeText As String = ""

    Try
        attributeText =
            attributeInfo.StringValue
    Catch
        attributeText =
            "<NAO STRING>"
    End Try

    File.AppendAllText(
        attributesOutputFile,
        attributeInfo.Title &
        "=" &
        attributeText &
        vbCrLf
    )

Next

            For Each attributeInfo As NXObject.AttributeInformation In attributes

                If attributeInfo.Title =
                    "INTEROP_FEATURE_PART_NAME" Then

                    attributeValue =
                        attributeInfo.StringValue

                    Exit For

                End If

            Next

            If Not String.IsNullOrWhiteSpace(
                attributeValue
            ) Then

                File.AppendAllText(
                    outputFile,
                    fileCode &
                    "|" &
                    attributeValue.Trim() &
                    vbCrLf
                )

                WriteLog(
                    "NOME NX: " &
                    fileCode &
                    " = " &
                    attributeValue
                )

            Else

                WriteLog(
                    "INTEROP_FEATURE_PART_NAME nao encontrado: " &
                    fileCode
                )

            End If

        Catch ex As Exception

            WriteLog(
                "ERRO AO LER NOME NX: " &
                fileCode &
                " - " &
                ex.Message
            )

        End Try

    Next

    WriteLog(
        "Arquivo criado: " &
        outputFile
    )

End Sub

End Module
'@

    [System.IO.File]::WriteAllText(
        $temporaryWrapperPath,
        $wrapperContent,
        [System.Text.Encoding]::UTF8
    )

    if (-not (
            Test-Path -LiteralPath $temporaryWrapperPath
        )) {
        throw "Temporary NX wrapper could not be created."
    }
}


# ============================================================
# ENVIRONMENT VALIDATION
# ============================================================

function Test-Environment {

    Write-Section `
        -Title "VALIDATING ENVIRONMENT"

    $requiredItems = @(
        @{
            Path = $pdmLibraryPath
            Name = "Interop.EdmLib.dll"
        },
        @{
            Path = $runJournalPath
            Name = "run_journal.exe"
        },
        @{
            Path = $importSwLibraryPath
            Name = "ImportSW2NX.dll"
        }
    )

    foreach ($requiredItem in $requiredItems) {

        if (-not (
                Test-Path -LiteralPath $requiredItem.Path
            )) {

            throw "$($requiredItem.Name) not found at '$($requiredItem.Path)'."
        }
    }

    if (-not (
            Test-Path -LiteralPath $vaultCredentialPath
        )) {

        Write-WarningMessage `
            -Message "Vault credential was not found."

        $credentialConfigurationScript =
        Join-Path `
            $PSScriptRoot `
            "configure_vaultCredentials.ps1"

        if (-not (
                Test-Path -LiteralPath $credentialConfigurationScript
            )) {

            throw "configure_vaultCredentials.ps1 not found."
        }

        $credentialProcess =
        Start-Process `
            -FilePath "powershell.exe" `
            -ArgumentList @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            "`"$credentialConfigurationScript`""
        ) `
            -Wait `
            -PassThru

        if ($credentialProcess.ExitCode -ne 0) {

            throw `
                "Vault credential configuration failed with code $($credentialProcess.ExitCode)."
        }

        if (-not (
                Test-Path -LiteralPath $vaultCredentialPath
            )) {

            throw "Vault credential file was not created."
        }
    }

    Add-Type `
        -Path $pdmLibraryPath

    if (-not (
            Test-Path -LiteralPath $downloadRootPath
        )) {

        New-Item `
            -ItemType Directory `
            -Path $downloadRootPath `
            -Force |
        Out-Null
    }

    Write-Success `
        -Message "Environment validated."
}


# ============================================================
# PDM VAULT CONNECTION
# ============================================================

function Connect-PdmVault {

    Write-Section `
        -Title "CONNECTING TO PDM VAULT"

    $credential =
    Import-Clixml `
        -LiteralPath $vaultCredentialPath

    if ($null -eq $credential) {
        throw "Vault credential file could not be loaded."
    }

    $securePassword =
    $credential.SenhaCriptografada |
    ConvertTo-SecureString

    $passwordPointer =
    [System.IntPtr]::Zero

    try {

        $passwordPointer =
        [Runtime.InteropServices.Marshal]::
        SecureStringToBSTR(
            $securePassword
        )

        $plainTextPassword =
        [Runtime.InteropServices.Marshal]::
        PtrToStringBSTR(
            $passwordPointer
        )

        $vault =
        New-Object EdmLib.EdmVault5Class

        $vault.Login(
            $credential.Usuario,
            $plainTextPassword,
            $vaultName
        )
    }
    finally {

        if (
            $passwordPointer -ne
            [System.IntPtr]::Zero
        ) {

            [Runtime.InteropServices.Marshal]::
            ZeroFreeBSTR(
                $passwordPointer
            )
        }

        Remove-Variable `
            plainTextPassword `
            -ErrorAction SilentlyContinue
    }

    if (-not $vault.IsLoggedIn) {

        throw `
            "Could not authenticate to vault '$vaultName'."
    }

    Write-Success `
        -Message "Connected to vault '$vaultName'."

    return $vault
}


# ============================================================
# PDM FILE SEARCH
# ============================================================

function Search-PdmFiles {

    param(
        [Parameter(Mandatory = $true)]
        $Vault,

        [Parameter(Mandatory = $true)]
        [string]$SearchText
    )

    $searchPattern =
    $SearchText.Replace(
        "*",
        "%"
    )

    if ($searchPattern -notmatch "%") {
        $searchPattern = "%$searchPattern%"
    }

    $search =
    $Vault.CreateSearch()

    $search.FileName =
    $searchPattern

    $search.FindHistoricStates =
    $false

    $searchResults =
    [System.Collections.Generic.List[object]]::new()

    if ($SearchText.Contains("*")) {
        Write-Host ""
        Write-Host "Pesquisando no Vault..." -ForegroundColor Yellow
    }

    $currentResult =
    $search.GetFirstResult()

    while ($null -ne $currentResult) {

        $searchResults.Add(
            $currentResult
        )

        $currentResult =
        $search.GetNextResult()
    }
    if ($SearchText.Contains("*")) {
        Write-Host "Pesquisa concluída." -ForegroundColor Green
    }

    return $searchResults.ToArray()
}


function Select-PdmPartCode {

    param(
        [Parameter(Mandatory = $true)]
        $Vault
    )

    Write-Section `
        -Title "PDM DOCUMENT SEARCH"

    Write-Host "Part code example: 260.02.002"
    Write-Host "Wildcard example: 260.*"
    Write-Host ""

    while ($true) {

        $partCode =
        (
            Read-Host "Enter the part code"
        ).Trim()

        if ($partCode.Length -eq 0) {

            Write-WarningMessage `
                -Message "Part code cannot be empty."

            continue
        }

        $searchResults =
        @(
            Search-PdmFiles `
                -Vault $Vault `
                -SearchText $partCode
        )

        if ($searchResults.Count -eq 0) {

            Write-WarningMessage `
                -Message "No results were found."

            continue
        }

        $foundCodes =
        @(
            foreach ($searchResult in $searchResults) {

                $fileNameWithoutExtension =
                [System.IO.Path]::
                GetFileNameWithoutExtension(
                    $searchResult.Name
                )

                if (
                    $fileNameWithoutExtension -match
                    '\d+\.\d+\.\d+'
                ) {
                    $Matches[0]
                }
            }
        ) |
        Sort-Object -Unique

        if (-not $partCode.Contains("*")) {

            if ($foundCodes -contains $partCode) {

                return [PSCustomObject]@{
                    PartCode      = $partCode
                    SearchResults = $searchResults
                }
            }

            Write-WarningMessage `
                -Message "Exact part code was not found."

            continue
        }

        if ($foundCodes.Count -eq 0) {

            Write-WarningMessage `
                -Message "Files were found, but no valid part codes were identified."

            continue
        }

        Write-Section `
            -Title "PART CODES FOUND"

        foreach ($foundCode in $foundCodes) {
            Write-Host "  $foundCode"
        }

        Write-Host ""
    }
}


# ============================================================
# LOCAL PART FOLDER
# ============================================================

function Get-PartDownloadPath {

    param(
        [Parameter(Mandatory = $true)]
        [string]$PartCode
    )

    $safeFolderName =
    $PartCode

    foreach (
        $invalidCharacter in
        [System.IO.Path]::GetInvalidFileNameChars()
    ) {

        $safeFolderName =
        $safeFolderName.Replace(
            $invalidCharacter,
            "_"
        )
    }

    $partDownloadPath =
    Join-Path `
        $downloadRootPath `
        $safeFolderName

    if (-not (
            Test-Path -LiteralPath $partDownloadPath
        )) {

        New-Item `
            -ItemType Directory `
            -Path $partDownloadPath `
            -Force |
        Out-Null

        Write-Info `
            -Message "Folder created: $partDownloadPath"
    }

    return $partDownloadPath
}


# ============================================================
# PDM FILE DOWNLOAD
# ============================================================

function Copy-PdmFiles {

    param(
        [Parameter(Mandatory = $true)]
        $Vault,

        [Parameter(Mandatory = $true)]
        [object[]]$SearchResults,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    Write-Section `
        -Title "DOWNLOADING PDM FILES"

    $copiedCount = 0
    $existingCount = 0
    $failureCount = 0

    foreach ($searchResult in $SearchResults) {

        try {

            $destinationFilePath =
            Join-Path `
                $DestinationPath `
                $searchResult.Name

            if (
                Test-Path -LiteralPath $destinationFilePath
            ) {

                Write-WarningMessage `
                    -Message "Already downloaded: $($searchResult.Name)"

                $existingCount++
                continue
            }

            $parentFolder =
            $null

            $pdmFile =
            $Vault.GetFileFromPath(
                $searchResult.Path,
                [ref]$parentFolder
            )

            if ($null -eq $pdmFile) {

                throw `
                    "Could not retrieve the file from the vault."
            }

            if ($null -eq $parentFolder) {

                throw `
                    "Could not retrieve the parent folder from the vault."
            }

            $fileVersion =
            0

            $folderId =
            $parentFolder.ID

            $pdmFile.GetFileCopy(
                0,
                [ref]$fileVersion,
                [ref]$folderId,
                0,
                ""
            )

            $localCachePath =
            $pdmFile.GetLocalPath(
                $parentFolder.ID
            )

            if (-not (
                    Test-Path -LiteralPath $localCachePath
                )) {

                throw `
                    "File was not found in the local PDM cache."
            }

            Copy-Item `
                -LiteralPath $localCachePath `
                -Destination $destinationFilePath

            Write-Success `
                -Message "Copied: $($searchResult.Name)"

            $copiedCount++
        }
        catch {

            Write-Failure `
                -Message "$($searchResult.Name) - $($_.Exception.Message)"

            $failureCount++
        }
    }

    Write-Host ""

    Write-Info `
        -Message "New files: $copiedCount"

    Write-Info `
        -Message "Existing files: $existingCount"

    Write-Info `
        -Message "Failures: $failureCount"

    if (
        $copiedCount -eq 0 -and
        $existingCount -eq 0
    ) {

        throw `
            "No files are available for NX conversion."
    }
}


# ============================================================
# SOLIDWORKS MAIN FILE
# ============================================================

function Get-MainSolidWorksFile {

    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    $mainFile =
    Get-ChildItem `
        -LiteralPath $FolderPath `
        -File `
        -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -ieq ".SLDASM"
    } |
    Select-Object -First 1

    if ($null -eq $mainFile) {

        $mainFile =
        Get-ChildItem `
            -LiteralPath $FolderPath `
            -File `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -ieq ".SLDPRT"
        } |
        Select-Object -First 1
    }

    if ($null -eq $mainFile) {

        throw `
            "No SLDPRT or SLDASM file was found."
    }

    return $mainFile
}


# ============================================================
# NX CONVERTED FILES
# ============================================================

function Get-NxConvertedFiles {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath
    )

    if (-not (
            Test-Path -LiteralPath $NxFolderPath
        )) {

        return [PSCustomObject]@{
            PrtFiles = @()
            JtFiles  = @()
        }
    }

    $convertedFiles =
    @(
        Get-ChildItem `
            -LiteralPath $NxFolderPath `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    return [PSCustomObject]@{
        PrtFiles = @(
            $convertedFiles |
            Where-Object {
                $_.Extension -ieq ".prt"
            }
        )

        JtFiles  = @(
            $convertedFiles |
            Where-Object {
                $_.Extension -ieq ".jt"
            }
        )
    }
}


# ============================================================
# NX CONVERSION
# ============================================================

function Invoke-NxConversion {

    param(
        [Parameter(Mandatory = $true)]
        [string]$InputFolderPath
    )

    $nxMigratedFolderPath =
    Join-Path `
        $InputFolderPath `
        "NXmigratedFiles"

    $existingConvertedFiles =
    Get-NxConvertedFiles `
        -NxFolderPath $nxMigratedFolderPath

    if (
        $existingConvertedFiles.PrtFiles.Count -gt 0
    ) {

        Write-Section `
            -Title "NX CONVERSION"

        Write-WarningMessage `
            -Message "NX conversion will not be repeated."

        foreach (
            $existingPrtFile in
            $existingConvertedFiles.PrtFiles
        ) {

            Write-Info `
                -Message "Existing PRT: $($existingPrtFile.Name)"
        }

        return [string]$nxMigratedFolderPath
    }

    if (
        Test-Path -LiteralPath $nxMigratedFolderPath
    ) {

        Write-WarningMessage `
            -Message "Incomplete NX conversion folder found."

        Write-WarningMessage `
            -Message "Removing only the incomplete output."

        Remove-Item `
            -LiteralPath $nxMigratedFolderPath `
            -Recurse `
            -Force
    }

    Write-Section `
        -Title "RUNNING NX CONVERSION"

    New-NxImportWrapper

    Write-Info `
        -Message "Running NX batch..."

    & $runJournalPath `
        $temporaryWrapperPath `
        "-args" `
        $InputFolderPath `
        $companyName |
    Out-Host

    $nxExitCode =
    $LASTEXITCODE

    if ($nxExitCode -ne 0) {

        throw `
            "NX returned error code $nxExitCode. Check '$nxLogPath'."
    }

    $generatedFiles =
    Get-NxConvertedFiles `
        -NxFolderPath $nxMigratedFolderPath

    if ($generatedFiles.PrtFiles.Count -eq 0) {

        throw `
            "NX conversion completed, but no PRT file was generated."
    }

    Write-Success `
        -Message "NX conversion completed."

    return [string]$nxMigratedFolderPath
}


# ============================================================
# CONVERSION RESULT
# ============================================================

function Show-ConversionResult {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath
    )

    $conversionResult =
    Get-NxConvertedFiles `
        -NxFolderPath $NxFolderPath

    Write-Section `
        -Title "CONVERSION RESULT"

    foreach (
        $prtFile in
        $conversionResult.PrtFiles
    ) {

        Write-Success `
            -Message "PRT: $($prtFile.Name)"
    }

    if ($conversionResult.JtFiles.Count -eq 0) {

        Write-WarningMessage `
            -Message "No JT file was found."
    }
    else {

        foreach (
            $jtFile in
            $conversionResult.JtFiles
        ) {

            Write-Success `
                -Message "JT: $($jtFile.Name)"
        }
    }

    return $conversionResult
}


# ============================================================
# TEAMCENTER IMPORT
# ============================================================

function Invoke-TeamcenterImport {

    param(
        [Parameter(Mandatory = $true)]
        [string]$NxFolderPath
    )

    Write-Section `
        -Title "TEAMCENTER IMPORT"

    $teamcenterImportScript =
    Join-Path `
        $PSScriptRoot `
        "import_toTeamcenter.ps1"

    if (-not (
            Test-Path -LiteralPath $teamcenterImportScript
        )) {

        throw `
            "import_toTeamcenter.ps1 not found at '$teamcenterImportScript'."
    }

    $powerShell64Path =
    Join-Path `
        $env:WINDIR `
        "Sysnative\WindowsPowerShell\v1.0\powershell.exe"

    if (-not (
            Test-Path -LiteralPath $powerShell64Path
        )) {

        $powerShell64Path =
        Join-Path `
            $env:WINDIR `
            "System32\WindowsPowerShell\v1.0\powershell.exe"
    }

    if (-not (
            Test-Path -LiteralPath $powerShell64Path
        )) {

        throw `
            "64-bit Windows PowerShell was not found."
    }

    & $powerShell64Path `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $teamcenterImportScript `
        -PastaNx $NxFolderPath

    $teamcenterExitCode =
    $LASTEXITCODE

    if ($teamcenterExitCode -ne 0) {

        throw `
            "Teamcenter import failed with code $teamcenterExitCode."
    }

    Write-Success `
        -Message "Teamcenter import completed."
}


# ============================================================
# MAIN EXECUTION
# ============================================================

try {

    Test-Environment

    $pdmVault =
    Connect-PdmVault

    $partSelection =
    Select-PdmPartCode `
        -Vault $pdmVault

    $selectedPartCode =
    $partSelection.PartCode

    $pdmSearchResults =
    @(
        $partSelection.SearchResults
    )

    $partDownloadPath =
    Get-PartDownloadPath `
        -PartCode $selectedPartCode

    Copy-PdmFiles `
        -Vault $pdmVault `
        -SearchResults $pdmSearchResults `
        -DestinationPath $partDownloadPath

    $mainSolidWorksFile =
    Get-MainSolidWorksFile `
        -FolderPath $partDownloadPath

    Write-Info `
        -Message "Main file: $($mainSolidWorksFile.Name)"

    $nxMigratedFolderPath =
    Invoke-NxConversion `
        -InputFolderPath $partDownloadPath

    $conversionResult =
    Show-ConversionResult `
        -NxFolderPath $nxMigratedFolderPath

    Write-Section `
        -Title "TESTES PRE-IMPORT"

    $posFile =
    Join-Path `
        $nxMigratedFolderPath `
        "Posicionamento.txt"

    $children =
    [System.Collections.Generic.HashSet[string]]::new()

    Get-Content $posFile |
    ForEach-Object {

        $parts = $_.Split('|')

        if ($parts.Count -lt 2) {
            return
        }

        $child = $parts[1]

        # remove _1 do NX
        $child =
        $child -replace '_\d+$', ''

        $null =
        $children.Add($child)
    }

    Write-Host ""
    Write-Host "MONTAGEM:"
    Write-Host "  $selectedPartCode"

    Write-Host ""
    Write-Host "VIEW ESPERADA:"
    Write-Host ""

    $children |
    Sort-Object |
    ForEach-Object {

        Write-Host "  $_"
    }
    if (
        $conversionResult.PrtFiles.Count -eq 0
    ) {

        throw `
            "No PRT file is available for Teamcenter import."
    }

    Invoke-TeamcenterImport `
        -NxFolderPath $nxMigratedFolderPath

    Write-Section `
        -Title "PROCESS COMPLETED"

    Write-Success `
        -Message "Processed part code: $selectedPartCode"

    Write-Info `
        -Message "NX output: $nxMigratedFolderPath"

    exit 0
}
catch {

    Write-Host ""

    Write-Failure `
        -Message $_.Exception.Message

    Write-Host ""
    Write-Host "[FULL ERROR]" -ForegroundColor DarkGray
    Write-Host $_.Exception.ToString() -ForegroundColor DarkGray
    Write-Host ""

    exit 1
}
finally {

    Remove-Variable `
        plainTextPassword `
        -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "Wrapper mantido para diagnostico:" -ForegroundColor Yellow
    Write-Host $temporaryWrapperPath
}