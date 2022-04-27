<#
.Synopsis
    Check the state of service in the input and return the name of those
    which are not in running state
.DESCRIPTION
    Long description
.EXAMPLE
    PS SVC_VMCOMPUTE.ps1 -SvcList "vmcompute","vmms"
    COMMENTAIRES : Service vmcompute running
    Service vmms is currently Stopped
.INPUTS
   [String[]]$SvcList
.OUTPUTS
   [String] 
.NOTES
   Should Return an object with all non-running service and their state. 

#>

Param
(
    [parameter(Mandatory = $True, ValueFromPipeline = $True)]
    [String[]]
    $SvcList
)


Begin {
    # $SVC_VMCOMPUTE = Get-WmiObject -query "SELECT * FROM Win32_Service WHERE Name = '$SvcName'"
    [int]$ReturnState = 3
    [string]$DesiredState = "Running"
}

Process {
    foreach ($SvcName in $SvcList) {
        $SvcInfo = Get-WmiObject -query "SELECT * FROM Win32_Service WHERE Name = '$SvcName'"
        if ($SvcInfo.State -like $DesiredState) {
            Write-Verbose "Service $($SvcInfo.Name) $DesiredState"
            
            # Keep state 1
            if ($ReturnState -ne 1) {
                $ReturnState = 0
            }
        } else {
            Write-Output "Service $($SvcInfo.Name) is currently $($SvcInfo.State)"
            $ReturnState = 1
        }
    }

}

End {
    Exit $ReturnState
}

