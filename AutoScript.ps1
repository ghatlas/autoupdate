$PkgArray = @()
$NameArray = @()
$AutoUPD = "C:\AutoUpdate\"
$AutoCache = "Cache\"
# Set URI for repo
$URI='https://github.com/ghatlas/autoupdate/raw/refs/heads/main/'
$URIDIR='bucket/'
$OsqueryVersion = "5.13.1"
$OsqueryName = "osquery-" + $OsqueryVersion + ".windows_x86_64"
$OsqueryBin = "osquery\osqueryi.exe"
$OsQueryURI="https://github.com/osquery/osquery/releases/download/$OsqueryVersion/osquery-$OsqueryVersion.windows_x86_64.zip"

if ( -not ( Test-Path -Path $AutoUPD ) ) {
	New-Item -Path $AutoUPD -ItemType Directory
	Write-Output "Folder $AutoUPD created successfully!"
}

if ( -not ( Test-Path -Path $AutoUPD$AutoCache ) ) {
	New-Item -Path $AutoUPD$AutoCache -ItemType Directory
	Write-Output "Folder $AutoUPD$AutoCache created successfully!"
}

if ( -not ( Test-Path -Path $AutoUPD$OsqueryBin ) ) {
	Invoke-WebRequest -Uri $OsQueryURI -OutFile $AutoUPD$AutoCache$OsqueryName".zip"
	Expand-Archive -Force $AutoUPD$AutoCache$OsqueryName".zip" $AutoUPD$AutoCache
	Move-Item -Path $AutoUPD$AutoCache$OsqueryName"\Program Files\osquery" -Destination $AutoUPD
}

Start-Process -FilePath "$AutoUPD$OsqueryBin" -ArgumentList '--json "SELECT install_date AS date, name AS name, version AS version FROM programs;"' -Wait -NoNewWindow -RedirectStandardOutput $AutoUPD\software_list.txt
$PkgArray=Get-Content $AutoUPD\software_list.txt | ConvertFrom-Json

Foreach ( $Pkg in $PkgArray ) {
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
		Invoke-WebRequest -Uri $URI$URIDIR$PkgName.json -OutFile $AutoUPD$AutoCache$PkgName.json -ErrorAction Stop
		Write-Host "Download:" $URI$URIDIR$PkgName.json
	}
	catch {
#		Write-Host "Error download $PkgName.json from $URI$URIDIR$PkgName.json"
	}
}

Get-ChildItem -Path $AutoUPD$AutoCache -Name -Include *.json |
	Foreach-Object {
		$PkgPath = "$AutoUPD$AutoCache$_"
		$PkgJSON = Get-Content $PkgPath -Raw | ConvertFrom-Json
		$PkgBaseName = [System.IO.Path]::GetFileNameWithoutExtension( "$PkgPath" )
		$PkgName = $PkgBaseName + "-" + $PkgJSON.version + "." + $PkgJSON.architecture.x64bit.type
		$PkgURI = $PkgJSON.architecture.x64bit.url
  		$PkgArgument = $PkgJSON.architecture.x64bit.argument
		Write-Host "Github repo:" $PkgBaseName " - " $PkgJSON.version
		Foreach ( $Pkg in $PkgArray ) {
			if ( $Pkg.Name -eq $PkgBaseName ) { Write-Host "Local install:" $Pkg.Name " - " $Pkg.Version }
			if (( $Pkg.Name -eq $PkgBaseName ) -and ( $Pkg.Version -lt $PkgJSON.version )) {
				Write-Host "New version (" $PkgJSON.version ") of package" $Pkg.Name "available"
				try {
					Invoke-WebRequest -Uri "$PkgURI" -OutFile "$AutoUPD$AutoCache$PkgName" -ErrorAction Stop
				}
				catch { Write-Host "Invalid URI $PkgURI for $PkgName" }
				try {
					if ( $PkgJSON.architecture.x64bit.type -eq "msi" ) {
						Start-Process "msiexec.exe" -ArgumentList "/I $AutoUPD$AutoCache$PkgName /q" -Wait -NoNewWindow
					} else {
						Start-Process "$AutoUPD$AutoCache$PkgName" -ArgumentList $PkgArgument -Wait -NoNewWindow
					}
				}
				catch {
					Write-Host "Error install or update" $AutoUPD$AutoCache$PkgName
				}
    				Remove-Item $AutoUPD$AutoCache + "*" -Force -Recurse
			}
		}
	}
