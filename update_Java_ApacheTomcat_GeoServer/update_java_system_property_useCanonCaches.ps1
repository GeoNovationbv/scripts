Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

$currentDirectory = Get-Location

#updateConfigFiles files waar de configuraties in staan
$updateConfigFiles = Get-ChildItem -Path $currentDirectory -Name -Include ApacheTomcat*.txt
$installLocationFile = Get-ChildItem -Path $currentDirectory -Name "Install_location.txt"

if (-not ((Test-Path -Path $updateConfigFiles) -and (Test-Path -Path $installLocationFile)) )
{
    Write-Output "Configuratie bestanden niet gevonden"
    Exit
}

$installLocationFileContent = Get-Content -Path $installLocationFile | Out-String
$installLocationFileConfig = ConvertFrom-StringData -StringData $installLocationFileContent

$extractedApacheTomcatDirs = Get-ChildItem -Path $installLocationFileConfig["appDir"] -Directory 
$extractedApacheTomcatDir = $extractedApacheTomcatDirs[0]

#sets CATALINA_HOME folder
$CATALINA_HOME = join-path -Path $installLocationFileConfig["appDir"] -ChildPath $extractedApacheTomcatDir 
$env:CATALINA_HOME = $CATALINA_HOME

#Lees de installatie bestanden uit
Foreach ($updateConfigFile in $updateConfigFiles)
{
    $configContent = Get-Content -Path $updateConfigFile | Out-String
    $config = ConvertFrom-StringData -StringData $configContent 

    $env:CATALINA_BASE = $config["catalina_base"]

    # stop the current Apache Tomcat service
    $apacheTomcatServiceNameFilter = "tomcat*"+$config["serviceName"]
    $apacheTomcatService = Get-Service -Include $apacheTomcatServiceNameFilter
    $apacheTomcatServiceName = $apacheTomcatService.Name

    if(-Not ($apacheTomcatService -eq $null) ) {
        if ($apacheTomcatService.Status -eq "Running") 
        {
            stop-service -name $apacheTomcatService.Name -Verbose:$false
            $apacheTomcatService.WaitForStatus('Stopped','00:00:45')
        }
    }

    $CATALINA_HOME_bin = Join-Path -Path $CATALINA_HOME -ChildPath "bin"
    Set-Location $CATALINA_HOME_bin

    $dUpdatUseCanonCaches = "-Dsun.io.useCanonCaches=false"

    Start-Process .\tomcat9.exe -ArgumentList //US/$apacheTomcatServiceName,++JvmOptions=$dUpdatUseCanonCaches -Wait

    Start-Service $apacheTomcatServiceName
    $apacheTomcatService.WaitForStatus('Running')

    Set-Location -Path $currentDirectory
    
}


