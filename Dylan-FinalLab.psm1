function Test-CloudFlare {
    <#
    .SYNOPSIS
    Execute a connection test on a remote computer.
    .DESCRIPTION
    The user is prompted to supply a computer name or IP address to create a remote session.
    The remote session is then used to perform a connection test to 'one.one.one.one'.
    .PARAMETER ComputerName
    A string, or list of strings, used to identify the computer to create a remote session with.
    This is a REQUIRED parameter.
    .Example
    Test-CloudFlare -ComputerName '192.168.0.1'

    DEFAULT USAGE
    This is the basic usage. -ComputerName is the only required variable.
    The results will be returned in a PSObject.
    .EXAMPLE
    Test-CloudFlare -ComputerName '192.168.0.1','192.168.0.7','192.168.0.25'

    TESTING MULTIPLE COMPUTERS
    You can test multiple computers in one command by supplying a list of computers.
    
    .NOTES
    Author: Dylan Martin
    Last Edit: 2021-12-08
    Version 1.1 - Updated comment-based help
    #>
    param(
        # used to select computer for remote session
        [Parameter(
            ValueFromPipeline=$True,
            Mandatory=$true
        )]
        [Alias('CN', 'Name')]
        [string[]]$ComputerName
    )
    
    begin {}  # Empty
    process {
        ForEach ($remote_com in $ComputerName) {
            Try {
                # create and enter remote session
                $session_params = @{
                    'ComputerName' = $remote_com
                    'ErrorAction' = 'Stop'
                }
                Write-Verbose "Establishing remote connection to $remote_com"
                $session = New-PSSession @session_params
                Enter-PSSession $session
            }
            Catch {
                # remote session failed to open
                Write-Host "Remote connection to $remote_com failed." -ForegroundColor 'red'
                # break current iteration of the loop since remote session could not be made
                Continue
            }

            # Perform ping test and extract key data points
            Write-Verbose "Pinging Cloudflare DNS from $remote_com"
            $TestCF = Test-NetConnection 'one.one.one.one' -InformationLevel Detailed

            # Create object with key data as properties
            Write-Verbose "Preparing results from $remote_com"
            $Results = [PSCustomObject]@{
                'ComputerName' = "$remote_com"
                'PingSuccess' = $TestCF.PingSucceeded
                'NameResolve' = $TestCF.NameResolutionSucceeded
                'ResolvedAddresses' = @(
                    # grab all IP addresses and join into a single string
                    foreach ($address in $TestCF.ResolvedAddresses) {
                        $address.IPAddressToString
                    }
                ) -join ';'
            }

            # exit and close the remote session
            Write-Verbose "Closing remote connection to $remote_com "
            Exit-PSSession
            Remove-PSSession $session

            $Results  # return value
        }
    }
    end {}  # Empty

}

function Get-PipeResults {
    <#
    .SYNOPSIS
    Retrieve objects from pipeline and format for output.
    .DESCRIPTION
    Get-PipeResults can accept multiple objects from the pipeline and output them to the
    terminal, to a .txt file, or a .csv file.
    .PARAMETER PipeInput
    One or multiple PSObjects. Intended to accept pipeline output.
    .PARAMETER Path
    A path string that specifies the working directory for the script.
    The default is the current users home directory.
    .PARAMETER FileName
    A string to be used as the name of any file created by the script.
    .PARAMETER Output
    Used to select the format of the output. The acceptable strings are:
        - Host ([DEFAULT]Writes to the console screen.)
        - CSV (Writes output to a .csv file)
        - Text (Writes output to a .txt file)
    .Example
    Get-Process -Name *shell | Get-PipeResults

    DEFAULT USAGE
    This is the basic usage. By default, -Output will be 'Host' which causes the results
    to be printed on the screen.
    .EXAMPLE
    Get-Process -Name *shell | Get-PipeResults -Output 'Text'

    CREATING A .txt FILE
    Setting -Output to 'Text' will write the output to a .txt file and then
    open it in Notepad.
    .EXAMPLE
    Get-Process -Name *shell | Get-PipeResults -Output 'CSV'

    CREATING A .CSV FILE
    Setting -Output to 'CSV' will create a .csv file. You can then view it with the
    application of your choice.
    .EXAMPLE
    Get-Process -Name *shell | Get-PipeResults -Output 'Text' -Path "$env:USERPROFILE\Desktop"

    CHOOSING THE LOCATION OF THE OUTPUT FILE
    Using the -Path parameter allows you to specify the location of the output file.
    This works with -Output being either 'Text' or 'CSV'.
    When -Path is ommitted, it defaults to the users home directory.
    .NOTES
    Author: Dylan Martin
    Last Edit: 2021-12-08
    Version 1.1 - Updated comment-based help
    #>
    param (
        [Parameter(
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True
        )]
        [PSObject[]]$PipeInput,

        # path string used to set working directory. Defaults to user directory.
        $Path = $env:USERPROFILE,

        # controls the name of the files generated
        $FileName = "PipeResults",
    
        # controls how the output is created. Default prints to screen.
        [ValidateSet ('Host', 'CSV', 'Text')]
        [string]$Output = 'Host'
    )
    begin {}  # Empty
    process {
        # Create function output based on chosen mode
        Switch  -wildcard ($Output) {
            'Host' {
                # Write the output to the screen
                Write-Verbose "Outputting results to screen"
                $PipeInput  # return Object
            }
        
            'CSV' {
                # Create file path
                $file_path = "$Path\$FileName.csv"
                Write-Verbose "Writing to .csv file at $file_path"
                # Create .csv file
                $PipeInput | Export-Csv $file_path -Append
            }
        
            'Text' {
                # Create file path
                $file_path = "$Path\$FileName.txt"
                
                # create the log file with a header
                Write-Verbose "Writing to log file at $file_path."

                $PipeInput | Format-List | Out-File $file_path -Append             
            }
        } 
    }
    end {
        if ($Output -eq "Text") {
            # open the file for viewing
            Write-Verbose "Opening results"
            notepad.exe $file_path
        }
    }    
}
