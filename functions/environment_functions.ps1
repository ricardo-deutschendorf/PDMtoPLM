function Import-ProjectEnvironment {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $environmentFilePath =
    Join-Path $ProjectRoot ".env"

    if (-not (
            Test-Path -LiteralPath $environmentFilePath -PathType Leaf
        )) {

        throw "Environment file not found at '$environmentFilePath'."
    }

    foreach ($line in Get-Content -LiteralPath $environmentFilePath) {

        if (
            [string]::IsNullOrWhiteSpace($line) -or
            $line.TrimStart().StartsWith("#")
        ) {

            continue
        }

        if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {

            throw "Invalid entry in '$environmentFilePath'."
        }

        $name = $Matches[1]
        $value = $Matches[2].Trim()

        if (
            $value.Length -ge 2 -and
            (
                ($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))
            )
        ) {

            $value = $value.Substring(1, $value.Length - 2)
        }

        [Environment]::SetEnvironmentVariable(
            $name,
            $value,
            [EnvironmentVariableTarget]::Process
        )
    }
}

function Set-ProjectEnvironmentValue {

    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $environmentFilePath =
    Join-Path $ProjectRoot ".env"

    if (-not (
            Test-Path -LiteralPath $environmentFilePath -PathType Leaf
        )) {

        throw "Environment file not found at '$environmentFilePath'."
    }

    $lines = @(Get-Content -LiteralPath $environmentFilePath)
    $escapedName = [regex]::Escape($Name)
    $settingPattern = "^\s*$escapedName="
    $settingFound = $false

    for ($index = 0; $index -lt $lines.Count; $index++) {

        if ($lines[$index] -match $settingPattern) {

            $lines[$index] = "$Name=$Value"
            $settingFound = $true
        }
    }

    if (-not $settingFound) {

        $lines += "$Name=$Value"
    }

    Set-Content -LiteralPath $environmentFilePath -Value $lines -Encoding UTF8

    [Environment]::SetEnvironmentVariable(
        $Name,
        $Value,
        [EnvironmentVariableTarget]::Process
    )
}
