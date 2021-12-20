### default variables
$date=Get-Date -Format yy-MM-dd
Read-host "Make sure to alter server, share, logpath and script location variables."
### These variables need to be altered per environment
$prefix = Read-host "Enter used prefix for all servers"
$server=""
$share=""
$logpath = "\\$server\$share\Reports\log4j\$prefix-scan-$date"
$python = "\\$server\Scripts\Security\log4j-finder-main\log4j-finder.py"
#   $ignoreDrives = @("A", "B" ) # A and B not relevant, D is temp drive of Azure VMs
#   $keyword = "*log4j-*.jar"
#   $server = Read-Host "Enter server to store logfile"
#   $logpath = Read-Host "Enter share to store logfile"
#   $logfile = "$logpath\log4jBulk_$prefix.log"
$logfile = "$logpath\log4jBulk_$date.log"
$logfilecsv = "$logpath\log4jBulk_$date.csv"
$vulnerablecsv = "$logpath\Vulnerable_$date.csv"

$computerNames = @(get-adcomputer -Filter { OperatingSystem -Like '*Windows Server*' } -Properties * |  Where-Object { ($_.Name -like "$prefix*" )} | Select-Object name )

If(!(test-path $logpath))
{
      New-Item -ItemType Directory -Force -Path $logpath
}

Start-Transcript -Path $logfile -NoClobber

foreach ($computer in $computerNames.Name) {
    $computer # Show computername
    if ((Test-Connection -computername $computer -Quiet) -eq $true) {
        $drives =(Invoke-Command -ComputerName $computer -ScriptBlock {Get-PSDrive -PSProvider FileSystem})
#        $drives.name
        foreach ($drive in $drives) {
 #           if ($drive.Name -notin $using:ignoreDrives) {
                $scan = & 'C:\Program Files\Python310\Python.exe' $python "\\$computer\$drive$\"
                $scan
                If($scan -like "*Found*vulnerable files*"){
                [string]$result = $scan | Select-String -pattern "Found . vulnerable files"
                $result = $result.TrimStart()
                }
                Else{
                $result = "Not vulnerable"
                }
                New-object -TypeName PSCustomObject -Property @{
                Server = $Computer
                Drive = $drive
                Result = $result
                } | Export-csv -path $LogfileCSV -Append               
                $vulnerable = $null
                $vulnerable = $scan | select-string "VULNERABLE: .*" | Select-Object line
                If($null -ne $vulnerable){
                $vulnerable | export-csv $vulnerablecsv -append
                }
#           }
        }
    }
    else{
     Write-host $computer is Offline
    }
}

Stop-Transcript

<#
This is a quick script, don't expect it to be too neat.
It should work for it's intended purpose, readability may be a bit harsh.
$coworker added CSV filtering
#>
