Set-ExecutionPolicy RemoteSigned -Scope LocalMachine

#script for update Java JRE
$currentDirectory = Get-Location
$openJDKInstallPath = Join-Path -Path $currentDirectory -ChildPath "OpenJDK"
Set-Location -Path $openJDKInstallPath

$oldestfileDate = Get-Date

#bepaal welke msi oud en nieuw is
foreach ($OpenJDKMsiFileName in Get-ChildItem -Path $openJDKInstallPath -Name -Include OpenJDK11U-jre_x64_windows_hotspot_*.msi) 
{
    $OpenJDKMsiFile = Get-Item($OpenJDKMsiFileName)

    if ($OpenJDKMsiFile.LastWriteTime -lt $oldestfileDate) {
        $oldestfileDate = $OpenJDKMsiFile.LastWriteTime
        $oldOpenJDKMsiFile = $OpenJDKMsiFile.Name
    }
    else 
    {
        $newOpenJDKMsiFile = $OpenJDKMsiFile.Name
    }
}

#stop Apache Tomcat service
foreach ($apacheTomcatService in Get-Service -Include "tomcat*")
{
    if ($apacheTomcatService.Status -eq "Running") 
    {
        stop-service -name $apacheTomcatService.Name
        $apacheTomcatService.WaitForStatus('Stopped','00:00:45')
    }
}

#uninstall old Java version
msiexec /X $oldOpenJDKMsiFile /quiet

Start-Sleep -Seconds 30

#install new Java version
msiexec /i $newOpenJDKMsiFile INSTALLLEVEL=1 ADDLOCAL=FeatureJavaHome,FeatureOracleJavaSoft /quiet

Start-Sleep -Seconds 30

#start Apache Tomcat service
foreach ($apacheTomcatService in Get-Service -Include "tomcat*")
{
    if ($apacheTomcatService.Status -eq "Stoped") 
    {
        start-service -name $apacheTomcatService.Name
        $apacheTomcatService.WaitForStatus('Running','00:00:45')
    }
}

#verwijder het oude MSI bestand
remove-item $oldOpenJDKMsiFile -force

Set-Location $currentDirectory