Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue |
Where-Object {
    $_.Name -match "dsofile"
} |
Select-Object FullName