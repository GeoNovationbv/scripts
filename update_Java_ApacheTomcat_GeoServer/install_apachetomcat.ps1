Set-ExecutionPolicy RemoteSigned

$currentDirectory = "D:\Ontwikkelingen kaartviewer\scripts\update_Java_ApacheTomcat_GeoServer"
Set-Location -Path $currentDirectory

#applicatinoDir locatie waar Apache Tomcat data komt te staan (catalina_base)
$applicationDir = "D:\Program Data\apache-tomcat"
#appDir locatie waar Apache Tomcat applicatie data staat (catalina_home)
$appDir = "D:\Tomcat"

#updateConfigFiles files waar de configuraties in staan
$updateConfigFiles = Get-ChildItem -Path $currentDirectory -Name -Include ApacheTomcat*.txt

$apacheTomcatInstallationFileDir = Join-Path -Path $currentDirectory -ChildPath "ApacheTomcat" 

#find Apache Tomcat file and get the version
$apacheTomcatInstallationFiles = Get-ChildItem -Path $apacheTomcatInstallationFileDir -Include apache-tomcat-9.0.*-windows-x64.zip -Recurse
     
#Get Apache Tomcat version from filename
$apacheTomcatVersion = $apacheTomcatInstallationFiles[0].Basename.split('-')[2]

#extract Apache Tomcat files and copy to correct directories
Expand-Archive -Path $apacheTomcatInstallationFiles[0].FullName 
    
$extractedApacheTomcatDir = join-path -path $currentDirectory -ChildPath $apacheTomcatInstallationFiles[0].Basename

if (Test-Path -path $extractedApacheTomcatDir) 
{
    #apacheTomcatDir subfolder of etractedApacheTomcatDir
    $apacheTomcatDir = Get-ChildItem -Path $extractedApacheTomcatDir -Directory
    
    #sets CATALINA_HOME folder
    $CATALINA_HOME = join-path -Path $appDir -ChildPath $apacheTomcatDir.BaseName
    $env:CATALINA_HOME = $CATALINA_HOME

    #create the new CATALINA_HOME folder
    New-Item $CATALINA_HOME -ItemType "directory"

    foreach ($apacheTomcatBinLibDir in Get-ChildItem -Path $apacheTomcatDir.FullName -Directory )
    {
        if ($apacheTomcatBinLibDir.BaseName -eq "bin" -Or $apacheTomcatBinLibDir.BaseName -eq "lib") {
           Move-Item -path $apacheTomcatBinLibDir.FullName -destination $CATALINA_HOME -Force
        }
    }

    #copies Apache Tomcat files 
    foreach ($apacheTomcatFile in Get-ChildItem -Path $apacheTomcatDir.FullName -File) {
        Move-Item $apacheTomcatFile.FullName $CATALINA_HOME -Force 
    }

    #verplaats mappen conf, logs , temp , webapps , work naar de app directries
    Foreach ($updateConfigFile in $updateConfigFiles)
    {
        Set-Location -Path $currentDirectory

        $configContent = Get-Content -Path $updateConfigFile | Out-String
        $config = ConvertFrom-StringData -StringData $configContent 

        $CATALINA_BASE = join-path -Path $applicationDir -ChildPath $config["serviceName"]
        $env:CATALINA_BASE = $CATALINA_BASE

        # stop the current Apache Tomcat service
        $oldApacheTomcatServiceNameFilter = "tomcat*"+$config["serviceName"]
        $oldApacheTomcatService = Get-Service -Include $oldApacheTomcatServiceNameFilter

        if ($oldApacheTomcatService.Status -eq "Running") 
        {
            #stop-service -name $oldApacheTomcatService.Name
            $oldApacheTomcatService.WaitForStatus('Stopped','00:00:45')
        }

        if (-not (Test-Path -Path $CATALINA_BASE) ) {
            New-Item $CATALINA_BASE -ItemType "directory"

            $CATALINA_BASE_acl = Get-Acl -Path $CATALINA_BASE

            $identity = "NT AUTHORITY\LocalService"
            $fileSystemRights = "Modify"
            $type = "Allow"

            $fileSystemAccessRuleArgumentList = $identity, $fileSystemRights, $type
            $fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList
            
            $CATALINA_BASE_acl.SetAccessRule($fileSystemAccessRule)
            Set-Acl -Path $CATALINA_BASE -AclObject $CATALINA_BASE_acl


            foreach ($subDirsInApacheTomcat in Get-ChildItem -Path $apacheTomcatDir.FullName -Directory ) 
            {
                if ($subDirsInApacheTomcat.name -eq "conf") {
                    #lees instelling old Apache Tomcat conf dir en kopieer deze als deze bestaat. Anders kopieer de conf dir uit de apache tomcat installatie.
                    if ( (-not $config["oldApacheTomcatConfDir"] -eq "") -and (Test-Path -Path $config["oldApacheTomcatConfDir"]) )
                    {
                        Copy-Item -path $config["oldApacheTomcatConfDir"] -destination $CATALINA_BASE -Recurse -Force
                    }
                    else {
                        Copy-Item -path $subDirsInApacheTomcat.FullName -destination $CATALINA_BASE -Recurse -Force
                    }
                }
                else {
                   $apacheTomcatOtherDir = join-path -Path $CATALINA_BASE -ChildPath $subDirsInApacheTomcat.name
                   New-Item $apacheTomcatOtherDir -ItemType "directory"
                }
            }
        }
        else { 
            # CATALINA_BASE folder exsists
            # backup current war file directory
            $apacheTomcatWebAppsDir = Join-Path -Path $CATALINA_BASE -ChildPath "webapps"
            $apacheTomcatWebAppsDirAppDir = Join-Path -Path $apacheTomcatWebAppsDir -ChildPath $config["ApplicationName"]
            if (Test-Path -Path $apacheTomcatWebAppsDirAppDir ) 
            {
                $backupOldapacheTomcatWebAppsDirAppDir =  -join($config["ApplicationName"],"_old")

                Rename-Item -Path $apacheTomcatWebAppsDirAppDir -NewName $backupOldapacheTomcatWebAppsDirAppDir
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
        $apacheTomcatWebAppsDir = Join-Path -Path $CATALINA_BASE -ChildPath "webapps"
        Copy-Item -Path $warFile.FullName -Destination $apacheTomcatWebAppsDir

        #renames the war file
        Set-Location $apacheTomcatWebAppsDir
        $newWarFilename =  $config["ApplicationName"]+".war"
        Rename-Item -path $warFile.Name -NewName $newWarFilename -Force

        #install Apache Tomcat service
        $CATALINA_HOME_bin = Join-Path -Path $CATALINA_HOME -ChildPath "bin"
        Set-Location $CATALINA_HOME_bin
      
        $env:JRE_HOME = $env:JAVA_HOME
        $env:JAVA_HOME = ""
        $apacheTomcatServiceName = "tomcat" + $apacheTomcatVersion + "-" + $config["serviceName"]

        #install Apache Tomcat service
        Start-Process .\service.bat -ArgumentList install,$apacheTomcatServiceName -Wait
        
        #update the services with the settings
        $JvmMs = $config["JvmMs"]
        $JvmMx = $config["JvmMx"]
        $jvmOptions = $config["JvmOptions"]
        Start-Process .\tomcat9.exe -ArgumentList //US/$apacheTomcatServiceName,--Startup=auto,--Jvm=auto--LogLevel=error,--JvmMs=$JvmMs,--JvmMx=$JvmMx,++JvmOptions=$jvmOptions -Wait
        
        $apacheTomcatService = Get-Service -Name $apacheTomcatServiceName
        Start-Service $apacheTomcatServiceName
        $apacheTomcatService.WaitForStatus('Running','00:00:15')
        Stop-Service $apacheTomcatServiceName
        $apacheTomcatService.WaitForStatus('Stopped','00:00:45')

        #remove war file
        Set-Location -Path $apacheTomcatWebAppsDir
        Remove-Item $newWarFilename

        if ($geoserver_empty_data_dir = Get-ChildItem -Path $config["ApplicationName"] -Filter "data" -Directory) 
        {
            remove-item -path $geoserver_empty_data_dir.FullName -Recurse
        }

        #geoserver extension files uitpakken
        $geoserverExtensionsInstallDir = Join-Path -Path $currentDirectory -ChildPath "geoserver_extensions"
        Set-Location $geoserverExtensionsInstallDir
        $geoserver_extensions = $config["Geoserver_extensions"]
         
        if ($config["Geoserver_extensions"]) 
        {
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

        #uninstall the old Apache Tomcat service
        #Set-Location $CATALINA_HOME_bin
        #Start-Process .\service.bat -ArgumentList remove, $oldApacheTomcatService.Name -Wait
    }


    
    #Remove-Item -Path $extractedApacheTomcatDir -Recurse -Force
}
