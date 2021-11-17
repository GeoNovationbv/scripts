[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

#geef het kaartviewer URL
$kaartviewerURL=""

#statistieken van vorige dag
Invoke-WebRequest -Uri $kaartviewerURL/admin/rest/auth/log/convert

#alle statistieken
Invoke-WebRequest -Uri $kaartviewerURL/admin/rest/auth/log/convert/all