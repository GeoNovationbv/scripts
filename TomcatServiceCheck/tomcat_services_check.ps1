#get all tomcat services
$tomcatServices = Get-Service tomcat*

foreach ($tomcatService in $tomcatServices)
{
   
    if ($tomcatService.Status -ne "Running") 
    {
        Start-Service $tomcatServices.Name
        $tomcatService.WaitForStatus("Running")
    }
}
