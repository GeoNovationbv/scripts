[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

#geef het metadata refresh URL
$simplesaml_metadatarefresh = ""

#Metadata refresh
Invoke-WebRequest -Uri $simplesaml_metadatarefresh