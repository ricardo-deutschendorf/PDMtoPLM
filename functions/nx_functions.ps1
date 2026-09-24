# === NX conversion functions ===

# Section: Generate the NX import wrapper
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
