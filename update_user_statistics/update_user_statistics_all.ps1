[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

#geef het kaartviewer URL
$kaartviewerURL=""

#alle statistieken
Invoke-WebRequest -Uri $kaartviewerURL/admin/rest/auth/log/convert/all