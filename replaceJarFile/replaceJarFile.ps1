$mapFishService = get-service -Name *mapfish
$jarFileNameToReplace = "commons-text-1.6.jar"
$newJarFilename = "commons-text-1.10.0.jar"

$queryString = "name='" + $mapFishService.Name + "'"

$mapfishInstanceExe = Get-CimInstance win32_service -filter $queryString

if (Test-path $mapfishInstanceExe.PathName.split()[0])
{
    #pad naar mapfishInstanceExe bestaat
    $mapfishInstanceExePath = Get-Item -Path $mapfishInstanceExe.PathName.split()[0]

    $libPath = Join-Path -Path $mapfishInstanceExePath.Directory.Parent.FullName -ChildPath webapps\print\WEB-INF\lib

    Write-Output "Pad waarop de jar file wordt vervangen: " $libPath
    
    $oldJarFile = Join-Path -Path $libPath -ChildPath $jarFileNameToReplace
    if (Test-path $oldJarFile) {
        #Stop MapFish service
        Write-Output "service: $($mapFishService.Name) wordt gestopt"
        Stop-Service $mapFishService.Name
        $mapFishService.WaitForStatus("Stopped", '00:00:30')
        Write-Output "service: $($mapFishService.Name) status: $($mapFishService.Status)"

        #rename old jar file
        $renamedOldJarFile = Rename-Item -Path $oldJarFile -newName "_commons-text-1.6.jar" -PassThru
        Write-Output "$($oldJarFile) hernoemt naar: $($renamedOldJarFile)"

        #rename new jar file
        $newJarFilename = Get-ChildItem -Name $newJarFilename
        $renamedJarFile = Rename-Item -Path $newJarFilename -newName $jarFileNameToReplace -PassThru

        #copy new jar file
        $newJarFileLocation = Copy-item -Path $renamedJarFile -Destination $oldJarFile -Force -PassThru
        Write-Output "$($newJarFileLocation) geplaatst"

        #start MapFish service
        Write-Output "service: $($mapFishService.Name) wordt gestart"
        Start-Service $mapFishService.Name
        $mapFishService.WaitForStatus("Running", '00:00:30')
        Write-Output "service: $($mapFishService.Name) status: $($mapFishService.Status)"
    }

}

