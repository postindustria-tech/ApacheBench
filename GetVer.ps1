$resp = Invoke-WebRequest -URI https://www.apachelounge.com/download/VS16/ -UserAgent "CMake"
If ($resp.Content -match "httpd-2.4.\d+-win64-VS16.zip")
{
  $ver = $Matches[0] -replace "^.*httpd-2.4.(\d+).*", '$1'
}
Else
{
  $ver = "51"
}
echo "$ver"