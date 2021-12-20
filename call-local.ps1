### default variables
$date=Get-Date -Format yy-MM-dd

### These variables need to be altered per environment
$logpath = ".\Reports\log4j\$prefix-scan-$date"
$python = ".\log4j-finder.py"
#$ignoreDrives = @("A", "B" ) # A and B not relevant, D is temp drive of Azure VMs
#$keyword = "*log4j-*.jar"
#$server = Read-Host "Enter server to store logfile"
#$logpath = Read-Host "Enter share to store logfile"
#$logfile = "$logpath\log4jBulk_$prefix.log"

If(!(test-path $logpath))
{
      New-Item -ItemType Directory -Force -Path $logpath
}

Start-Transcript -Path "$logpath\log4jscan_$env:COMPUTERNAME.log"
    $env:COMPUTERNAME # Show computername
    $drives =(Get-PSDrive -PSProvider FileSystem)
    $drives.name
        foreach ($drive in $drives) {
            python $python $drive.root
        }
Stop-Transcript

<#
This is a quick script, don't expect it to be too neat.
It should work for it's intended purpose, readability may be a bit harsh.
#>