$AutoUPD = "C:\AutoUpdate\"
$AutoScript = "AutoScript.ps1"
$URI="https://github.com/ghatlas/autoupdate/raw/refs/heads/main/"
try { Invoke-WebRequest -Uri $URI$AutoScript -OutFile $AutoUPD$AutoScript -ErrorAction Stop }
catch { Write-Host "Invalid URI $URI$AutoScript for $AutoUPD$AutoScript" }
