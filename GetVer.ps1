$resp = Invoke-WebRequest -URI https://www.apachelounge.com/download/VS17/ -UserAgent "CMake"
If ($resp.Content -match "httpd-2\.4\.(\d+)(-\d+)?-win64-VS17\.zip")
{
  $ver = $Matches[0] -replace "^.*httpd-2.4.(\d+(-\d+)?).*", '$1'
}
Else
{
  $ver = "51"
}
echo "$ver"