Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

$currentDirectory = Get-Location

$env:JAVA_HOME = [System.Environment]::GetEnvironmentVariable("JAVA_HOME","Machine") 
$env:JRE_HOME = $env:JAVA_HOME
$env:JAVA_HOME = ""

#updateConfigFiles files waar de configuraties in staan
$updateConfigFiles = Get-ChildItem -Path $currentDirectory -Name -Include ApacheTomcat*.txt
$installLocationFile = Get-ChildItem -Path $currentDirectory -Name "Install_location.txt"

if (-not ((Test-Path -Path $updateConfigFiles) -and (Test-Path -Path $installLocationFile)) )
{
    Write-Output "Configuratie bestanden niet gevonden"
    Exit
}

$apacheTomcatInstallationFileDir = Join-Path -Path $currentDirectory -ChildPath "ApacheTomcat" 

if (-not (Test-Path -path $apacheTomcatInstallationFileDir) )
{
    Write-Output $currentDirectory 
    Exit
}

#find Apache Tomcat file and get the version
$apacheTomcatInstallationFiles = Get-ChildItem -Path $apacheTomcatInstallationFileDir -Include apache-tomcat-9.0.*-windows-x64.zip -Recurse
     
#Get Apache Tomcat version from filename
$apacheTomcatVersion = $apacheTomcatInstallationFiles[0].Basename.split('-')[2]

#extract Apache Tomcat files and copy to correct directories 
Expand-Archive $apacheTomcatInstallationFiles[0].FullName -DestinationPath $apacheTomcatInstallationFileDir -Force
$extractedApacheTomcatDir = Get-ChildItem -Path $apacheTomcatInstallationFileDir -Directory

$extractedApacheTomcatDirPath = Join-Path -Path $apacheTomcatInstallationFileDir -ChildPath $extractedApacheTomcatDir

$installLocationFileContent = Get-Content -Path $installLocationFile | Out-String
$installLocationFileConfig = ConvertFrom-StringData -StringData $installLocationFileContent

#apacheTomcatDir subfolder of etractedApacheTomcatDir
$apacheTomcatDir = Get-ChildItem -Path $extractedApacheTomcatDirPath -Directory

#sets CATALINA_HOME folder
$CATALINA_HOME = join-path -Path $installLocationFileConfig["appDir"] -ChildPath $extractedApacheTomcatDir
$env:CATALINA_HOME = $CATALINA_HOME
$reinstallServices = $false

if (-not (Test-Path -Path $CATALINA_HOME) ) {
    #create the new CATALINA_HOME folder
    New-Item $CATALINA_HOME -ItemType "directory"
    
    #copies Apache Tomcat bin en lib folder 
    foreach ($apacheTomcatBinLibDir in Get-ChildItem -Path $extractedApacheTomcatDirPath -Directory )
    {
        if ($apacheTomcatBinLibDir.BaseName -eq "bin" -Or $apacheTomcatBinLibDir.BaseName -eq "lib") {
            
            Copy-Item -path $apacheTomcatBinLibDir.FullName -destination $CATALINA_HOME -Recurse -Force
        }
    }

    #copies Apache Tomcat root files 
    foreach ($apacheTomcatFile in Get-ChildItem -Path $extractedApacheTomcatDirPath -File) {
        Copy-Item $apacheTomcatFile.FullName $CATALINA_HOME -Force 
    }

    $reinstallServices = $true
}

#Lees de installatie bestanden uit
Foreach ($updateConfigFile in $updateConfigFiles)
{
    $configContent = Get-Content -Path $updateConfigFile | Out-String
    $config = ConvertFrom-StringData -StringData $configContent 

    $env:CATALINA_BASE = $config["catalina_base"]

    # stop the current Apache Tomcat service
    $oldApacheTomcatServiceNameFilter = "tomcat*"+$config["serviceName"]
    $oldApacheTomcatService = Get-Service -Include $oldApacheTomcatServiceNameFilter
    $oldApacheTomcatServiceName = $oldApacheTomcatService.Name

    if(-Not ($oldApacheTomcatService -eq $null) ) {
        $ApachRunAsOtherUserMessage = ""

        if ($oldApacheTomcatService.Status -eq "Running") 
        {
            stop-service -name $oldApacheTomcatService.Name -Verbose:$false
            $oldApacheTomcatService.WaitForStatus('Stopped','00:00:45')
        }

        #controleer het account wat de Apache Tomcat service uitvoert.
        $oldApcheTomcatServiceRunAs = ( Get-CimInstance Win32_Service -Filter "Name='$oldApacheTomcatServiceName'") | Out-String Select-Object StartName
    }
    else {
        if (-not $reinstallServices) {
            #apache tomcat folder exists but service is not installed install the service
            $reinstallServices = $true
        }
    }

    if (-not (Test-Path -Path $config["catalina_base"]) ) {
        New-Item $config["catalina_base"] -ItemType "directory"

        foreach ($subDirsInApacheTomcat in Get-ChildItem -Path $extractedApacheTomcatDirPath -Directory ) 
        {
            if ($subDirsInApacheTomcat.Name -eq "conf") {
                #lees instelling old Apache Tomcat conf dir en kopieer deze als deze bestaat. Anders kopieer de conf dir uit de apache tomcat installatie.
                if ( (-not $config["oldApacheTomcatConfDir"] -eq "") -and (Test-Path -Path $config["oldApacheTomcatConfDir"]) )
                {
                    Copy-Item -path $config["oldApacheTomcatConfDir"] -destination $config["catalina_base"] -Recurse -Force
                }
                else {
                    Copy-Item -path $subDirsInApacheTomcat.FullName -destination $config["catalina_base"] -Recurse -Force
                }
            }
            else {
                if (-not ($subDirsInApacheTomcat.Name -eq "bin" -Or $subDirsInApacheTomcat.Name -eq "lib") ){
                    $apacheTomcatOtherDir = join-path -Path $config["catalina_base"] -ChildPath $subDirsInApacheTomcat.Name
                    New-Item $apacheTomcatOtherDir -ItemType "directory"
                }
            }
        }
    }
    else { 
        # CATALINA_BASE folder exsists

        #Empty the logs folder
        $apacheTomcatLogsDir = Join-Path -Path $config["catalina_base"] -ChildPath "logs"
        Remove-Item $apacheTomcatLogsDir\* -Recurse -Force

        #Remove Application from webapps dir
        $apacheTomcatWebAppsDir = Join-Path -Path $config["catalina_base"] -ChildPath "webapps"
        $apacheTomcatWebAppsDirAppDir = Join-Path -Path $apacheTomcatWebAppsDir -ChildPath $config["ApplicationName"]
        if (Test-Path -Path $apacheTomcatWebAppsDirAppDir ) 
        {
            Remove-Item -Path $apacheTomcatWebAppsDirAppDir -Recurse -Force
        }
    }

    #copy war file to webapps dir
    $warFile = Get-ChildItem -Path "wars" -Include $config["warFile"] -Recurse
    $pathToExtractWarZip = Join-Path -Path $currentDirectory -ChildPath "wars"
    Set-Location -Path $pathToExtractWarZip

    if ( ($warFile.Extension -eq ".zip")  )
    {
        if (-not(Test-Path -Path $warFile.BaseName) ) 
        {
            Expand-Archive -Path $warFile.FullName
        }
        # set the correct warFile
        $warFile = Get-ChildItem $warFile.BaseName -Include *.war -Recurse
    }

    #copies the war file to the webapps folder
    $apacheTomcatWebAppsDir = Join-Path -Path $config["catalina_base"] -ChildPath "webapps"
    Copy-Item -Path $warFile.FullName -Destination $apacheTomcatWebAppsDir

    #renames the war file
    Set-Location $apacheTomcatWebAppsDir
    $newWarFilename =  $config["ApplicationName"]+".war"

    Rename-Item -path $warFile.Name -NewName $newWarFilename -Force

    $CATALINA_HOME_bin = Join-Path -Path $CATALINA_HOME -ChildPath "bin"
    Set-Location $CATALINA_HOME_bin
        
    #set the new service name
    $apacheTomcatServiceName = "tomcat" + $apacheTomcatVersion + "-" + $config["serviceName"]

    if ($reinstallServices) {
        #install Apache Tomcat service
        if ( $oldApacheTomcatService -ne $null -and $oldApcheTomcatServiceRunAs -eq $null ) {
            $oldApacheTomcatServiceRemoved = "Oude Apache Tomcat service met naam: " + $oldApacheTomcatServiceName + " wordt verwijderd."
            Start-Process .\service.bat -ArgumentList remove, $oldApacheTomcatService.Name -Wait
        }
        #install Apache Tomcat service
        Start-Process .\service.bat -ArgumentList install,$apacheTomcatServiceName -Wait
    }
    
    if ($config["MapFishLoggingConfig"] -ne $null) {
        $logBackLoggingLocation = $config["MapFishLoggingConfig"]
        if (-not (Test-Path -Path $logBackLoggingLocation) ) {
            New-Item -ItemType File $logBackLoggingLocation -Force
            $currentDirectoryinstallatie_templates = Join-Path -Path $currentDirectory -ChildPath "installatie_templates"
            Copy-Item $currentDirectoryinstallatie_templates"\mapfish\logback.xml" $logBackLoggingLocation -Force
        }
        $jvmOptionLoggingConfig = ";-Dlogback.configurationFile=$logBackLoggingLocation"
        $config["JvmOptions"] = $config["JvmOptions"]+$jvmOptionLoggingConfig
    }

    #update the services with the settings
    $JvmMs = $config["JvmMs"]
    $JvmMx = $config["JvmMx"]
    $jvmOptions = $config["JvmOptions"]
    Start-Process .\tomcat9.exe -ArgumentList //US/$apacheTomcatServiceName,--Startup=auto,--Jvm=auto,--LogLevel=error,--JvmMs=$JvmMs,--JvmMx=$JvmMx,++JvmOptions=$jvmOptions -Wait

    $apacheTomcatService = Get-Service -Name $apacheTomcatServiceName

    Start-Service $apacheTomcatServiceName
    $apacheTomcatService.WaitForStatus('Running')
    
    #Sleep for 10 seconds so the war can be extracted
    Start-Sleep -Seconds 10

    Stop-Service $apacheTomcatServiceName
    $apacheTomcatService.WaitForStatus('Stopped')

    #remove war file
    Set-Location -Path $apacheTomcatWebAppsDir
    Remove-Item $newWarFilename

    $apacheTomcatInstalledWebAppsDir = Join-Path $apacheTomcatWebAppsDir -ChildPath $config["ApplicationName"] 
    Write-Output $apacheTomcatInstalledWebAppsDir
    $empty_geoserver_data_dir = Get-ChildItem -Path $apacheTomcatInstalledWebAppsDir -Filter data 
    Write-Output $empty_geoserver_data_dir

    if ($config["Geoserver_extensions"]) 
    {
        $geoserverExtensionsInstallDir = Join-Path -Path $currentDirectory -ChildPath "geoserver_extensions"
        Set-Location $geoserverExtensionsInstallDir
      
        foreach ($geoserverExtension in $config["Geoserver_extensions"].split(';') ) 
        {
            $geoserverExtensionFile = Get-ChildItem -Path $geoserverExtensionsInstallDir -Include *$geoserverExtension*.zip -Recurse
            Expand-Archive $geoserverExtensionFile -Force

            $geoserverExtensionExtractedDir = Join-Path -Path $geoserverExtensionsInstallDir -ChildPath $geoserverExtensionFile.BaseName
            $geoserverWEBINFlib = $config["ApplicationName"] + "\WEB-INF\lib"
            $geoserverWEBINFlibDir = Join-Path $apacheTomcatWebAppsDir -ChildPath $geoserverWEBINFlib

            Copy-Item -Path $geoserverExtensionExtractedDir\*.jar -Destination $geoserverWEBINFlibDir -Force
        }
    }

    #we moeten iets gaan doen met de geoserver data dir
    
    if ($config["GeoserverDataDir"] ) 
    {
        if (-Not (Test-Path $config["GeoserverDataDir"]) ){
            New-Item -Path $config["GeoserverDataDir"] -ItemType "directory"

            #moves the empty_geoserver_data_dir to the new location
            Get-ChildItem -Path $empty_geoserver_data_dir.FullName -Recurse | Copy-Item -Destination $config["NewGeoserverDataDir"] -Force
        }
        else {
            #backup geoserver_data_dir
            $currentDate = Get-Date -Format "yyyy-MM-dd"
            $GeoServerDataDirBackupFolder = $config["GeoserverDataDir"] + "_backup_" + $currentDate 

            $geoserDataDir = $config["GeoserverDataDir"]+"\*"
            Copy-Item -Path $geoserDataDir -Exclude ('geoserver*.log', 'data') -Destination $GeoServerDataDirBackupFolder -Force -Recurse
        }

        Remove-Item -path $empty_geoserver_data_dir.FullName -Recurse

        $newGeoserverDataDir =  $config["GeoserverDataDir"]

        Set-Location $CATALINA_HOME_bin
        
        $dgeoserver_data_dir = "-DGEOSERVER_DATA_DIR=""$newGeoserverDataDir"""

        Start-Process .\tomcat9.exe -ArgumentList //US/$apacheTomcatServiceName,++JvmOptions=$dgeoserver_data_dir -Wait
    }
    
    if ( $oldApcheTomcatServiceRunAs.StartsWith("NT Authority\Local") ) {
        Start-Service $apacheTomcatServiceName
    }
    else {
        Write-Output $apacheTomcatServiceName " nog niet gestart moet worden uitgevoerd door windows account: " + $oldApcheTomcatServiceRunAs
    }

    Set-Location -Path $currentDirectory
    
}


