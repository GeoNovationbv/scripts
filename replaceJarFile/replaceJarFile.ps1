$mapFishService = get-service -Name *mapfish
$jarFileNameToReplace = "commons-text-1.6.jar"
$newJarFilename = "commons-text-1.10.jar"

$queryString = "name='" + $mapFishService.Name + "'"

$mapfishInstanceExe = Get-CimInstance win32_service -filter $queryString
if (Test-path $mapfishInstanceExe.PathName.split()[0])
{
    #pad naar mapfishInstanceExe bestaat
    $mapfishInstanceExePath = Get-Item -Path $mapfishInstanceExe.PathName.split()[0]

    #deze regel verwijderen!
    $mapfishInstanceExePath = Get-Item -Path "D:\\Program Data\\apache-tomcat\\mapfish"
    
    $libPath = Join-Path -Path $mapfishInstanceExePath.FullName -ChildPath webapps\print\WEB-INF\lib
    $oldJarFile = Join-Path -Path $libPath -ChildPath $jarFileNameToReplace

    if (Test-path $oldJarFile) {
        Stop-Service $mapFishService.Name

        Rename-Item -Path $oldJarFile -newName "_commons-text-1.6.jar"
        $newJarFilename = Get-ChildItem -Path $PSScriptRoot -Filter $newJarFilename
        $renamedJarFile = Rename-Item -Path $newJarFilename[0].Name -newName $jarFileNameToReplace -PassThru

        Copy-item -Path $renamedJarFile -Destination $oldJarFile -Force

        Start-Service $mapFishService.Name
    }

}

