<#
  sqlps dependency
  If module sqlps does not exist, install from:
    Microsoft SQL Server 2016 Feature Pack (https://www.microsoft.com/en-us/download/details.aspx?id=52676)
    - SQLSysClrTypes.msi
    - SharedManagementObjects.msi
    - PowershellTools.msi
  OR through admin PowerShell CLI by running commands
  Install-Module -Name "SqlServer"
  Verrify the installation by
  Get-InstalledModule -Name "SqlServer"
#>

[string]$defaultServername="(localdb)\SQLSERVER2016"
$dbNames = @("DB_NAME1", "DB_NAME2", "DB_NAME3", "DB_NAME4");


Push-Location
Import-Module "sqlps" -DisableNameChecking
Pop-Location

$dbNamesToProcess = New-Object System.Collections.Generic.List[System.Object]

function Get-BakPath {
	Param ([string]$dbname)
	return "$((Get-Item -Path ".\").FullName)\$($dbname).bak"
}

function GET-Pause {
	write-host 'Press any key to exit...';
	$key = $host.UI.RawUI.ReadKey("NoEcho, IncludeKeyUp");
}

# This function determines whether a database exists in the system.
function IsDBInstalled([string]$sqlServer, [string]$DBName) {
	$exists = $FALSE
	try {
		# Get reference to database instance
		$server = new-object Microsoft.SqlServer.Management.Smo.Server $sqlServer

		foreach($db in $server.databases) {  
			if ($db.name -eq $DBName) {
				$exists = $TRUE
			}
		}
	}
	catch {
		Write-Error "Failed to connect to $sqlServer"
	}

	return $exists
}

function UpAllDatabases([string]$servername) {
	Foreach ($dbname in $dbNames) {	
		if (!(Test-Path $(Get-BakPath($dbname)) -PathType Leaf)) {
			Write-Host "[.BAK not found] $($dbname).bak not found.  " -ForegroundColor Yellow
			continue;
		}
		
		if (IsDBInstalled $servername $dbname) {
			Write-Host "[db already up] $($dbname) already up, will not be restored.  " -ForegroundColor Yellow
			continue;
		}
		
		Write-Host "[OK] $($dbname) will be restored.  " -ForegroundColor Green
		$dbNamesToProcess.Add($dbname);
	}

	[int]$i = 0;
	try {
		$server = New-Object Microsoft.SqlServer.Management.Smo.Server $servername
	}
	catch {
		$exception = $_.Exception.InnerException
		Write-Host $exception -ForegroundColor Red
		#exit 1
		GET-Pause
	}
	
	Foreach ($dbname in $dbNamesToProcess) {
		try {
			$filename = $(Get-BakPath($dbname))
			$restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
			$device = New-Object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $filename, "FILE"
			$restore.Devices.Add($device)
			$i++;
			Write-Progress -Id 1 -Activity "Restoring Databases to $servername" -Status "Restoring: $i/$($dbNamesToProcess.Count)" -PercentComplete ($i / $dbNamesToProcess.Count * 100)
		}
		catch {
			$exception = $_.Exception.InnerException
			Write-Host $exception -ForegroundColor Red
			#exit 1
			GET-Pause
		}
		
		try {
			$filelist = $restore.ReadFileList($server)
		}
		catch {
			$exception = $_.Exception
			Write-Host "$exception. `n`nDoes the SQL Server service account have acccess to the backup location?" -ForegroundColor Red
			#exit 1
			GET-Pause
		}

		$filestructure = @{}; $datastructure = @{}; $logstructure = @{}
		$logfiles = $filelist | Where-Object {$_.Type -eq "L"}
		$datafiles = $filelist | Where-Object {$_.Type -ne "L"}

		# Data Files (if db has filestreams, make sure server has them enabled)
		$defaultdata = $server.DefaultFile
		$defaultlog = $server.DefaultLog
		if ($defaultdata.Length -eq 0) {
			$defaultdata = $server.Information.MasterDBPath
		}

		if ($defaultlog.Length -eq 0) {
			$defaultlog = $server.Information.MasterDBLogPath
		}

		foreach ($file in $datafiles) {
			$newfilename = Split-Path $($file.PhysicalName) -leaf

			$datastructure.physical = "$defaultdata$newfilename"
			$datastructure.logical = $file.LogicalName
			$filestructure.add($file.LogicalName,$datastructure)
		}

		# Log Files
		foreach ($file in $logfiles) {
			$newfilename = Split-Path $($file.PhysicalName) -leaf

			$logstructure.physical = "$defaultlog$newfilename"
			$logstructure.logical = $file.LogicalName
			$filestructure.add($file.LogicalName,$logstructure)
		}

		# Make sure big restores don't timeout
		$server.ConnectionContext.StatementTimeout = 0

		foreach	($file in $filestructure.values) {
			$movefile = New-Object "Microsoft.SqlServer.Management.Smo.RelocateFile"
			$movefile.LogicalFileName = $file.logical
			$movefile.PhysicalFileName = $file.physical
			$null = $restore.RelocateFiles.Add($movefile)
		}

		Write-Host "Restoring $dbname to $servername"

		# kill all connections
		$server.KillAllProcesses($dbname)

		try {
			$percent = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] {
				Write-Progress -id 2 -activity "Restoring $dbname" -percentcomplete $_.Percent -status ([System.String]::Format("Progress: {0} %", $_.Percent))
			}
			$restore.add_PercentComplete($percent)
			$restore.PercentCompleteNotification = 1
			$restore.add_Complete($complete)
			$restore.ReplaceDatabase = $true
			$restore.Database = $dbname
			$restore.Action = "Database"
			$restore.NoRecovery = $false

			# take most recent backup set if there are more than one
			$restore.FileNumber = $restore.ReadBackupHeader($server).Rows.Count

			Write-Progress -id 2 -activity "Restoring $dbname" -percentcomplete 0 -status ([System.String]::Format("Progress: {0} %", 0))
			$restore.sqlrestore($servername)
			Write-Progress -id 2 -activity "Restoring $dbname" -status "Complete" -Completed
			Write-Progress -id 1 -activity "Restoring Databases to $servername" -status "Complete" -Completed
			Write-Host "Restore complete!" -ForegroundColor Green
		}
		catch {
			$exception = $_.Exception.InnerException
			Write-Host $exception -ForegroundColor Red
			#exit 1
			GET-Pause
		}
	}	
}

function DownAllDatabases([string]$servername) {
	Foreach ($dbname in $dbNames) {	
		if (!(IsDBInstalled $servername $dbname)) {
			Write-Host "[db not found] $($dbname) not found, will not be dropped.  " -ForegroundColor Yellow
			continue;
		}
		
		Write-Host "[OK] $($dbname) will be dropped.  " -ForegroundColor Green
		$dbNamesToProcess.Add($dbname);
	}

	[int]$i = 0;
	try {
		$server = New-Object Microsoft.SqlServer.Management.Smo.Server $servername
	}
	catch {
		$exception = $_.Exception.InnerException
		Write-Host $exception -ForegroundColor Red
		#exit 1
		GET-Pause
	}
	
	Foreach ($dbname in $dbNamesToProcess) {
		$i++;
		Write-Progress -Id 1 -Activity "Dropping Databases on $servername" -Status "Dropping: $i/$($dbNamesToProcess.Count)" -PercentComplete ($i / $dbNamesToProcess.Count * 100) -CurrentOperation "Dropping $dbname"

		try {
			$db = $server.databases[$dbname]
			if ($db) {
				Write-Host "Dropping $dbname on $servername"
				# kill all connections
				$server.KillAllprocesses($dbname)
				$db.Drop()
			}
		}
		catch {
			$exception = $_.Exception
			Write-Host "$exception. `n`nDoes the SQL Server service account have acccess to the backup location?" -ForegroundColor Red
			#exit 1
			GET-Pause
		}
	}
	Write-Progress -id 1 -activity "Dropping Databases on $servername" -status "Complete" -Completed
	Write-Host "Droping complete!" -ForegroundColor Green
}


if (!($servername = Read-Host "Enter your local sql server instance [$defaultServername]")) { 
	$servername = $defaultServername 
}

do{
    $processType = Read-Host "Bring databases up or down? [up/down]"
}
while(!($processType -ieq "up" -or $processType -ieq "down"))

if($processType -ieq "up") {
	UpAllDatabases($servername)
}

if($processType -ieq "down") {
	DownAllDatabases($servername)
}

GET-Pause
