Add-Type -AssemblyName System.Windows.Forms

$asm = [Reflection.Assembly]::LoadFrom(
    "\\perto38-novo\NX_Custom\ImportSW2NX.dll"
)

# FORM
$formType = $asm.GetType(
    "ImportSW2NX.Windows.FolderSelectForm"
)

$form = [System.Activator]::CreateInstance($formType)

$form.folderLoad = "C:\temp\importados\260.02.002"
$form.company = "Perto"

$txt = $form.Controls |
    Where-Object { $_.Name -eq "txt_folderLoad" }

$combo = $form.Controls |
    Where-Object { $_.Name -eq "comboBox1" }

$btn = $form.Controls |
    Where-Object { $_.Name -eq "button1" }

$txt.Text = $form.folderLoad
$combo.Text = $form.company

$formType.GetMethod(
    "button1_Click",
    [Reflection.BindingFlags]::NonPublic -bor
    [Reflection.BindingFlags]::Instance
).Invoke(
    $form,
    @($btn,[System.EventArgs]::Empty)
)

Write-Host ""
Write-Host "folderSave:"
Write-Host $form.folderSave

# PROGRAM
$programType = $asm.GetType("Program")

$gerarXML = $programType.GetMethod("gerarXML")

$program = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject($programType)

try
{
    $gerarXML.Invoke(
        $program,
        @($form.folderLoad)
    )

    Write-Host ""
    Write-Host "GERARXML EXECUTOU"
}
catch
{
    Write-Host ""
    Write-Host "ERRO:"
    Write-Host $_.Exception.Message

    if ($_.Exception.InnerException)
    {
        Write-Host ""
        Write-Host "INNER:"
        Write-Host $_.Exception.InnerException.Message
    }
}

Read-Host "ENTER"