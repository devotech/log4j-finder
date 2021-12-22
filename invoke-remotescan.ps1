<#
This script will copy the Fox-It log4j scan tool to the servers specified in -Servers and run it.
Each drive on each server will be scanned as a separate job, so all scans will run in parallel. 
#>

Param
(
    # Comma seperated string of servernames. 
    # Example: 'server1,server2,server3'. Do not forget the quotes, else powershell will interpret it as an array.
    $Servers,
    $Log4jFinderExeFullPath, # Path to log4j-finder.exe
    [switch]$Verbose
)

if ($Verbose)
{
    # Enable verbose logging
    $VerbosePreference = "Continue"    
}

### You can change these parameters to your own preference:

# Wait 60 seconds between showing the job summary
$waitTimeBetweenChecks = 60 # seconds
# Drive on the server on which the destination folder will be created
$destinationDrive = 'c:'
# Folder that will be created on the server on which the scan is running to store the fox-it scanner and log file
$destinationFolder = 'log4j'


### Preparation

# Check if Log4jFinderExeFullPath is a valid path or stop the script
$log4jFinderExeName = ''
if (Test-Path -Path $log4jFinderExeFullPath)
{    
    # Extract the .exe filename from the full path
    $log4jFinderExeName = (Get-Item $log4jFinderExeFullPath).Name    
}
else
{
    Write-Error "-Log4jFinderExeFullPath: Must point to a valid file, preferably the fox-it log4j-finder.exe"
    #Exit
}

# Check if servers parameter is not empty or stop the script
if ($Servers.Length -eq 0)
{
    Write-Error "-Servers must be a comma seperated string of servernames, example 'server1,server2,server3'"
    #Exit
}

# Full path and file to the log4j scanner .exe on the destination server
$scannerFullPath = Join-Path -Path $destinationDrive -ChildPath "$destinationFolder/$log4jFinderExeName"

# Call script that will be run on each server
# Note the $using:variables, these variables are passed from this script to the runScanner script at runtime
$runScanner = {
    # The script that calls this scriptblock will have copied the scanner to this location, 
    # so we can safely assume that it exists
    $scannerFullPath = $using:scannerFullPath
    
    # Folder to scan. Assume it has a trailing backslash which the scanner needs to scan recursively
    $scanTarget = $using:scanTarget

    # Log file to store all vulnerabilities that are found
    $transcriptFile = $using:transcriptFile
    
    # Run the scanner .exe and log all output
    Start-Transcript -Path $transcriptFile
    & $scannerFullPath $scanTarget | Out-Host
    Stop-Transcript
}

# Create list of servers and trim all whitespace
$serverNames = $servers.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
$serverNames = ($serverNames).Trim()

<#
    Improvement: Test-Connection to each server and remove offline servers from the array.
    For now assume that all servers on the list are active.
#>

### Copy the log4j finder to the destination servers

foreach ($serverName in $serverNames)
{
    # Destination drive as admin share
    $adminShare = ($destinationDrive.Split(':', 2))[0] + '$'

    # Destination path in UNC format
    $destinationUNCPath = "\\$serverName\$adminShare\$destinationFolder"
    Write-Verbose "Destination path where log4j finder will be copied to: $destinationUNCPath"

    try 
    {
        # Test if the destination path exists        
        Write-Verbose "Testing if destination path exists"
        if (!(Test-Path -Path $destinationUNCPath))
        {
            # Create the destination folder, -Force will create all subfolders as well
            Write-Verbose "Creating destination path"
            New-Item -Path $destinationUNCPath -ItemType Directory -Force
        }
    
        # Copy the log4j finder to the destination UNC path. Powershell overwrites by default
        Write-Verbose "Copy $Log4jFinderExeFullPath to $destinationUNCPath"
        Copy-Item -Path $Log4jFinderExeFullPath -Destination $destinationUNCPath
    }
    catch
    {
        Write-Error "Error testing path or copying file, aborting script. Make sure the server is running and that the file can be copied to it"
        #Exit
    }
}

### Run the scans

# Store job objects in this array
$jobs = @()

# Run the scriptblock $scanScript as a job on each drive on each server in parallel
# Make sure that $scannerFullPath, $scanTarget and $transcriptFile are all set correctly and that the server is running
foreach ($serverName in $serverNames)
{
    # Run the scan on each drive as a job
    $drives = invoke-command -ComputerName $serverName -scriptblock { Get-PSDrive -PSProvider FileSystem }
    if ($drives.Count -eq 0)
    {
        Write-Error "No drives found on $serverName, make sure the server is running. Stopping script"
        #Exit
    }

    foreach ($drive in $drives)
    {
        # Set scanTarget parameter
        $scanTarget = $drive.Root
        $driveName = $drive.Name

        # Name the job
        $jobName = "Log4j-$serverName-$driveName"

        # transcriptFile must be in local format, not UNC format
        $currentDate = Get-Date -Format yyyyMMdd-hhmmss
        $transcriptFileName = "$serverName-$driveName-fox-it-finder-$currentDate.log"

        # Set transcriptFile parameter
        $transcriptFile = Join-Path -Path $destinationDrive -ChildPath "$destinationFolder/$transcriptFileName"
        
        Write-Verbose "Starting scan job on $serverName on drive $driveName, transcript file is $transcriptFile"

        # Run the scanner on $serverName 
        $newJob = Invoke-Command -ComputerName $serverName -ScriptBlock $runScanner -AsJob -JobName $jobName

        # Add job to the list of jobs
        $jobs += $newJob
    }
}

### Show the status of each job
Write-Output "Do not close this window. Showing updates every $waitTimeBetweenChecks seconds"
Write-Output "If the script crashes or is interrupted, use Get-Job to show the status of each job"
Write-Output "To cancel all jobs, use Get-Job | Remove-Job (in this window only!)"

# Check if all jobs are done and show status of each job
$anyJobBusy = $true
while ($anyJobBusy)
{
    # Wait some time between checks
    # Check all jobs to see if they are still running
    # Show a summary of the jobs (id, name, server, starttime, endtime, command)
    # If all jobs are done, exit the loop

    Start-Sleep -Seconds $waitTimeBetweenChecks
    $anyJobBusy = $false
    $jobCounter = 0
#    $jobStatusses = @()
    foreach ($job in $jobs)
    {
        if ($job.State -ne 'Completed')
        {
            # if one job is still running, the script is not done yet
            $anyJobBusy = $true
            $jobCounter++
        }
        # If no jobs are running, $anyJobBusy will still be $false and the loop wil exit
    }
    # Show status of all jobs
    Get-Date
    $jobs | Select-Object Id, Name, State, Location, PSBeginTime, PSEndTime | Format-Table
}

# Cleanup
Get-Job | Remove-Job
