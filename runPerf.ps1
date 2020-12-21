param ($h, $s, $c, $p, $n)


$calOut = "calibrate.out"
$proOut = "process.out"
$scriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$ab="$ScriptRoot/ab"
$allowedOverheadMs=200

if ($h -eq $null -or
    $s -eq $null -or
    $c -eq $null -or
    $p -eq $null -or
    $n -eq $null) {
    Write-Host "Some arguments were missing."
    Write-Host ""
    Write-Host "Expected:"
    Write-Host "    -h : root host to call e.g. localhost:3000"
    Write-Host "    -n : number of passes i.e. the number of calls to the endpoint"
	Write-Host "    -s : command to start the web service e.g. `"php -S localhost:3000`""
    Write-Host "    -c : endpoint path to use for calibration on the host e.g. test/calibrate"
    Write-Host "    -p : endpoint path to use for the process pass on the host e.g. test/process"
	Write-Host ""
	Write-Host "For example:"
	Write-Host "    runPerf.ps1 -host localhost:3000 -passes 1000 -service-start `"php -S localhost:3000`" ..."
    exit
}

Write-Host "Host                     = $h"
Write-Host "Passes                   = $n"
Write-Host "Service Start            = $s"
Write-Host "Calibration Endpoint     = $c"
Write-Host "Process Endpoint         = $p"

Write-Host "Starting the service"

Invoke-Expression "cmd /c start powershell -Command { `$host.UI.RawUI.WindowTitle = `"Listening Web Service`"; $s; }"

# Function to get status code from service endpoint
Function Get-StatusCode {
    try{
        (Invoke-WebRequest -Uri "http://$h/$c" -UseBasicParsing -DisableKeepAlive).StatusCode
    }
    catch [Net.WebException]
    {
        [int]$_.Exception.Response.StatusCode
    }
}

# Wait for the service to start
Write-Host "Waitig up to 15 seconds for host $h"
$Tries = 0
$HTTP_Status = Get-StatusCode
While ($HTTP_Status -ne 200 -And $Tries -le 3) {
    Start-Sleep -Seconds 5
    $Tries = $Tries +1
    $HTTP_Status = Get-StatusCode
}

# Run the benchmarks
Write-Host "Running calibration"
Invoke-Expression "$ab -A uas.csv -q -n $n $h/$c >$calOut"
Write-Host "Running processing"
Invoke-Expression "$ab -A uas.csv -q -n $n $h/$p >$proOut"

# Stop the service
get-process | where-object {$_.MainWindowTitle -eq "Listening Web Service"} | stop-process

# Check no requests failed in calibration
$failedCal = Get-Content $calOut | Select-String -Pattern "Failed requests"
$failedCal = $failedCal -replace '\D+(\d+)','$1'
if ($failedCal -ne 0) {
    Write-Warning "There were $failedCal failed calibration requests"
}

# Check no requests failed in processing
$failedPro = Get-Content $proOut | Select-String -Pattern "Failed requests"
$failedPro = $failedPro -replace '\D+(\d+)','$1'
if ($failedPro -ne 0) {
    Write-Warning "There were $failedPro failed process requests"
}

# Check no requests were non-200 (e.g. 404) in calibration
$non200Cal = Get-Content $calOut | Select-String -Pattern "Non-2xx responses"
$non200Cal = $non200Cal -replace 'Non-2xx responses\D+(\d+)','$1'
if ($non200Cal -ne 0) {
    Write-Warning "There were $non200Cal non-200 calibration requests"
}

# Check no requests were non-200 (e.g. 404) in processing
$non200Pro = Get-Content $proOut | Select-String -Pattern "Non-2xx responses"
$non200Pro = $non200Pro -replace 'Non-2xx responses\D+(\d+)','$1'
if ($non200Pro -ne 0) {
    Write-Warning "There were $non200Pro non-200 process requests"
}

# Get the time for calibration
$calTime = Get-Content $calOut | Select-String -Pattern "Time taken for tests"
$calTime = $calTime -replace 'Time taken for tests: *([0-9]*\.[0-9]*) seconds','$1'
$calTime = $calTime / $n
Write-Host "Calibration time: $calTime s ($calTime s per request)"

# Get the time for processing
$proTime = Get-Content $proOut | Select-String -Pattern "Time taken for tests"
$proTime = $proTime -replace 'Time taken for tests: *([0-9]*\.[0-9]*) seconds','$1'
$proTime = $proTime / $n
Write-Host "Processing time: $proTime s ($proTime s per request)"

# Calculate the processing overhead
$diff = $proTime -  $calTime
$overheadS = $diff / $n
$overheadMs = $overheadS * 1000
Write-Host "Processing overhead is $overheadMs ms per request"

if ($overheadMs -gt $allowedOverheadMs) {
    Write-Warning "Overhead was over $allowedOverheadMs"
}