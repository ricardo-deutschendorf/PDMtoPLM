# === Vault credential configuration ===

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "functions\environment_functions.ps1")
Import-ProjectEnvironment -ProjectRoot $PSScriptRoot

$pdmLibraryPath = $env:PDM_LIBRARY_PATH
$vaultName = $env:VAULT_NAME

# Section: Print a console section heading
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

# Section: Print a success message
function Write-Success {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [OK] $Message" -ForegroundColor Green
}

# Section: Print a failure message
function Write-Failure {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

function Write-Information {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "  -> $Message" -ForegroundColor Gray
}
# Section: Validate vault credentials
function Test-VaultCredential {

    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Password
    )

    $passwordPointer =
    [System.IntPtr]::Zero

    $plainTextPassword =
    $null

    try {

        $passwordPointer =
        [Runtime.InteropServices.Marshal]::
        SecureStringToBSTR(
            $Password
        )

        $plainTextPassword =
        [Runtime.InteropServices.Marshal]::
        PtrToStringBSTR(
            $passwordPointer
        )

        $vault =
        New-Object EdmLib.EdmVault5Class

        $vault.Login(
            $Username,
            $plainTextPassword,
            $vaultName
        )

        return $vault.IsLoggedIn
    }
    catch {

        Write-Failure  -Message $_.Exception.Message

        return $false
    }
    finally {

        $plainTextPassword =
        $null

        if (
            $passwordPointer -ne
            [System.IntPtr]::Zero
        ) {

            [Runtime.InteropServices.Marshal]::
            ZeroFreeBSTR(
                $passwordPointer
            )
        }

        Remove-Variable  plainTextPassword  -ErrorAction SilentlyContinue
    }
}

try {

    Write-Section  -Title "VAULT CREDENTIAL CONFIGURATION"

    if (-not (
            Test-Path  -LiteralPath $pdmLibraryPath
        )) {

        throw  "PDM library not found at '$pdmLibraryPath'."
    }

    Add-Type  -Path $pdmLibraryPath

    Write-Success  -Message "PDM library loaded."

    while ($true) {

        Write-Host ""

        $username =
        (
            Read-Host "Vault username"
        ).Trim()

        if ($username.Length -eq 0)
        {

            Write-Failure  -Message "Username cannot be empty."

            continue
        }

        $password =
        Read-Host  "Vault password"  -AsSecureString

        if ($password.Length -eq 0) {

            Write-Failure  -Message "Password cannot be empty."

            continue
        }

        Write-Host ""

        Write-Information  -Message "Validating access to vault '$vaultName'..."

        $isCredentialValid =
        Test-VaultCredential  -Username $username  -Password $password

        if (-not $isCredentialValid) {

            Write-Host ""

            Write-Failure  -Message "Invalid username or password."

            Write-Information  -Message "The credential was not saved."

            continue
        }

        Write-Success  -Message "Vault access validated."

        $encryptedPassword =
        ConvertFrom-SecureString -SecureString $password

        Set-ProjectEnvironmentValue `
            -ProjectRoot $PSScriptRoot `
            -Name "VAULT_USERNAME" `
            -Value $username

        Set-ProjectEnvironmentValue `
            -ProjectRoot $PSScriptRoot `
            -Name "VAULT_PASSWORD_ENCRYPTED" `
            -Value $encryptedPassword

        Write-Host ""

        Write-Success  -Message "Credential saved successfully."

        Write-Information  -Message "File: $(Join-Path $PSScriptRoot '.env')"

        break
    }

    Write-Host ""
    exit 0
}
catch {

    Write-Host ""
    Write-Host "[ERRO]"
    Write-Host $_.Exception.Message

    Write-Host ""
    Write-Host "[LINHA]"
    Write-Host $_.InvocationInfo.PositionMessage

    Write-Host ""
    Write-Host "[COMANDO]"
    Write-Host $_.InvocationInfo.Line

    exit 1
}
finally {

    Remove-Variable  password  -ErrorAction SilentlyContinue

    Remove-Variable  plainTextPassword  -ErrorAction SilentlyContinue
}