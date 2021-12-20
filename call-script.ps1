### default variables
$date=Get-Date -Format yy-MM-dd
$HHmm=get-date -Format HHmm

Read-host "Make sure to alter server, share, logpath and script location variables."

### These variables need to be altered per environment
$prefix = Read-host "Enter used prefix for all servers"
$server=""
$share=""
$logpath = "\\$server\$share\Reports\log4j\$prefix-scan-$date"
$python = "\\$server\Scripts\Security\log4j-finder-main\log4j-finder.py"
#$ignoreDrives = @("A", "B" ) # A and B not relevant, D is temp drive of Azure VMs
#$keyword = "*log4j-*.jar"
#$server = Read-Host "Enter server to store logfile"
#$logpath = Read-Host "Enter share to store logfile"
$logfile = "$logpath\log4jBulk_$prefix.log"

$computerNames = @(get-adcomputer -Filter { OperatingSystem -Like '*Windows Server*' } -Properties * |  Where-Object { ($_.Name -like "$prefix*" )} | Select-Object name )

If(!(test-path $logpath))
{
      New-Item -ItemType Directory -Force -Path $logpath
}

Start-Transcript -Path $logfile -NoClobber

foreach ($computer in $computerNames.Name) {
    Start-Transcript -Path "$logpath\log4jscan_$computer.log"
    $computer # Show computername
    if ((Test-Connection -computername $computer -Quiet) -eq $true) {
        $drives =(Invoke-Command -ComputerName $computer -ScriptBlock {Get-PSDrive -PSProvider FileSystem})
#        $drives.name
        foreach ($drive in $drives) {
 #           if ($drive.Name -notin $using:ignoreDrives) {
                python $python "\\$computer\$drive$\"
#           }
        }
    }
    else{
     Write-host $computer is Offline
    }
    Stop-Transcript
}

Stop-Transcript

<#
This is a quick script, don't expect it to be too neat.
It should work for it's intended purpose, readability may be a bit harsh.
#>