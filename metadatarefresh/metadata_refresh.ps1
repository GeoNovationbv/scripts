[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

#geef het metadata refresh URL
$simplesaml_metadatarefresh = "https://testgeo.gegevenshuis.nl/simplesaml/module.php/cron/run/daily/5euJxIl5jZ7GYOhaMLJg3SpkbHb2d1fy"

#Metadata refresh
Invoke-WebRequest -Uri $simplesaml_metadatarefresh