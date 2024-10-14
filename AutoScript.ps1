$PkgArray = @()
$NameArray = @()
# Set URI for repo
$URI='https://github.com/ghatlas/autoupdate/raw/refs/heads/main/'
$URIDIR='bucket/'
$AutoUPD = "C:\AutoUpdate\"
$AutoCache = "Cache\"
$AutoScript = "AutoScript.ps1"
$SoftwareList = "software_list.txt"
$OsqueryVersion = "5.13.1"
$OsqueryName = "osquery-" + $OsqueryVersion + ".windows_x86_64"
$OsqueryBin = "osquery\osqueryi.exe"

Start-Process -FilePath "$AutoUPD$OsqueryBin" -ArgumentList '--json "SELECT install_date AS date, name AS name, version AS version FROM programs;"' -Wait -NoNewWindow -RedirectStandardOutput $AutoUPD$SoftwareList
$PkgArray=Get-Content $AutoUPD$SoftwareList | ConvertFrom-Json

Foreach ( $Pkg in $PkgArray ) {
	if ( $Pkg.Name -ne "" ) {
		# Save origin name of package
		$PkgOrigin = $Pkg.Name

		if ( $Pkg.Name.Contains(" ") ) {
			$Pkg.Name = $Pkg.Name -replace "(\(.*\)|version|версия|x\d{2}|ru|en-us|,|v\d{1,}\.\d{1,}\.\d{1,})", ""
			$Pkg.Name = $Pkg.Name -replace "(\s{2,})", " "
			$NameArray = $Pkg.Name.Split( " " )
			$Pkg.Name = ""
			for ( $sName=0; $sName -lt $NameArray.Length; $sName++ ) {
				if ( -not ( $Pkg.Version.Contains( $NameArray[$sName] ))) {
					$Pkg.Name += $NameArray[$sName]
				}
			}

			$Pkg.Name = $Pkg.Name.Trim()
			$Pkg.Name = $Pkg.Name -replace "(-)", ""
		}

		$PkgName = $Pkg.Name
		try {
			Invoke-WebRequest -Uri $URI$URIDIR$PkgName".json" -OutFile $AutoUPD$AutoCache$PkgName".json" -ErrorAction Stop
			Write-Host "Download:" $URI$URIDIR$PkgName".json"

			$json_file = Get-Content $AutoUPD$AutoCache$PkgName".json" | ConvertFrom-Json
			$json_file | Add-Member -MemberType NoteProperty -Name "origin_name" -Value $PkgOrigin
			$json_file | ConvertTo-Json | Set-Content -Path $AutoUPD$AutoCache$PkgName".json"
		} catch {}
#		Write-Host $PkgOrigin" ******************** "$PkgName
	}
}

Get-ChildItem -Path $AutoUPD$AutoCache -Name -Include *.json | Foreach-Object {
	$PkgPath = "$AutoUPD$AutoCache$_"
	$PkgJSON = Get-Content $PkgPath -Raw | ConvertFrom-Json
	$PkgBaseName = [System.IO.Path]::GetFileNameWithoutExtension( "$PkgPath" )
	$PkgName = $PkgBaseName + "-" + $PkgJSON.version + "." + $PkgJSON.architecture.x64bit.type
	$PkgURI = $PkgJSON.architecture.x64bit.url
	$PkgArguments = $PkgJSON.architecture.x64bit.argument
	$PkgOriginName = $PkgJSON.origin_name
	Write-Host "Github repo:" $PkgBaseName " - " $PkgJSON.version
	Foreach ($Pkg in $PkgArray) {
		if (( $Pkg.Name -eq $PkgBaseName ) -and ( $PkgJSON.area -eq "black" )) {
			Write-Host "$PkgOriginName --- will be remove"
			Uninstall-Package -Name "$PkgOriginName" -Force
		}
		elseif (( $Pkg.Name -eq $PkgBaseName ) -and ( $Pkg.Version -lt $PkgJSON.version )) {
			Write-Host "New version (" $PkgJSON.version ") of package" $Pkg.Name "available"
			try {
				Invoke-WebRequest -Uri "$PkgURI" -OutFile "$AutoUPD$AutoCache$PkgName" -ErrorAction Stop
			}
			catch { Write-Host "Invalid URI $PkgURI for $PkgName" }
			try {
				if ( $PkgJSON.architecture.x64bit.type -eq "msi" ) {
					Start-Process "msiexec.exe" -ArgumentList "/I $AutoUPD$AutoCache$PkgName /q" -Wait -NoNewWindow
				} else {
					Start-Process "$AutoUPD$AutoCache$PkgName" -ArgumentList "$PkgArguments" -Wait -NoNewWindow
				}
			}
			catch {
				Write-Host "Error install or update" $AutoUPD$AutoCache$PkgName
			}
		}
	}
}

Remove-Item $AutoUPD$AutoCache"*" -Force -Recurse
