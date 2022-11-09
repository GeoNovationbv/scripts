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
    
    $oldJarFile = Join-Path -Path $libPath -ChildPath $jarFileNameToReplace
    if (Test-path $oldJarFile) {
        Stop-Service $mapFishService.Name

        Rename-Item -Path $oldJarFile -newName "_commons-text-1.6.jar"
        
        $newJarFilename = Get-ChildItem -Name $newJarFilename
        Write-Output $newJarFilename

        $renamedJarFile = Rename-Item -Path $newJarFilename -newName $jarFileNameToReplace -PassThru

        Copy-item -Path $renamedJarFile -Destination $oldJarFile -Force

        Start-Service $mapFishService.Name
    }

}

