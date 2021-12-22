$prefix="entyer prefix here"
$TargetLocation = "\\$SERVERgoesHERE\Logs\Reports\$subfoldergoeshere\"


If(!(test-path $TargetLocation)){
    New-Item -ItemType Directory -Force -Path $TargetLocation
}
#Function Get-DomainLogs{
    $computerNames = @(get-adcomputer -Filter { OperatingSystem -Like '*Windows Server*' } -Properties * | Where-Object{$_.name -like "$prefix*"} | Select-Object name )
    foreach ($computer in $computerNames.Name) {
        if ((Test-Connection -computername $computer -Quiet) -eq $true) {
                Copy-Item -Path "\\$computer\C$\log4j\*" -Destination $TargetLocation -recurse -Exclude *.exe -Verbose
        }
        else{
            Write-Host $computer is Offline # Show computername + Offline
        }
    }
#}

<#
$servers='hostname1,hostname2,hostname3'
$serverNames = $servers.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
$serverNames = ($serverNames).Trim()
#$servernames

                # If using a list, uncomment this block.
foreach ($serverName in $serverNames){
    Copy-Item -Path "\\$serverName\C$\log4j\*.log" -Recurse -Destination $TargetLocation
}

#>