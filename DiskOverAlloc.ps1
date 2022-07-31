<#
.SYNOPSIS
Virtual disks can be configured in dynamic mode. If so, there may be 
more allocated space than actual available space on the volume. 
This script check the max size of all vhd on those volumes and 
calculates if there is a real overallocation. 

.DESCRIPTION
Check whether dynamics VHDX represents an overallocation on volumes. 

.INPUTS
maxthreshold        - Critical Threshold on volumes (1 means 100%)
warningthreshold    - Warning threshold on volumes (0.9 means 90%)
$returnStateOK      - Exit status code 
$returnStateWarning - Exit status code 
returnStateCritical - Exit status code 
returnStateUnknown  - Exit status code 

.OUTPUTS
PS > .\DiskOveAlloc.ps1

[V1.0] Both critical and warning overallocation on volume detected
Critical : C:\ClusterStorage\Volume1\
Warning : E:\

.EXAMPLE
PS> DiskOverAlloc.ps1

[V1.0] Both critical and warning overallocation on volume detected
Critical : C:\ClusterStorage\Volume1\
Warning : E:\

.LINK
None

#>

Param 
( 
    [parameter(Mandatory = $FALSE)]
    [int]$maxthreshold = 1,
    [int]$warningthreshold = 0.5,
    [int]$returnStateOK = 0,
    [int]$returnStateWarning = 1,
    [int]$returnStateCritical = 2,
    [int]$returnStateUnknown = 3
)

Begin {
    class overAllocationInfo {
        [System.String]$DriveLetter
        [String]$NameRegex
        [string]$Label
        [System.UInt64]$DriveTotalSpace
        [System.UInt64]$DriveUsedSpace
        [bool]$IsOverAllocated
        [bool]$WarningOverAllocated
    }

    $version = "V1.0"

    $warningmsg = "Warning : "
    $criticalmsg = "Critical : "
    
    $listoverallocationinfo = New-Object System.Collections.ArrayList

    # Test whether the cluster exists
    $msclusterexists = Get-WmiObject -Namespace "root\MSCluster" -ClassName "MSCluster_Resource" -List -ErrorAction SilentlyContinue
    if ($null -eq $msclusterexists) {
        $vmlist = (Get-VM).Name | Select-Object -Property Name, VMName, ComputerName
    } else {
        $clustername = (Get-Cluster).Name
        $vmlist = Get-VM -ComputerName (Get-ClusterNode -Cluster $clustername)  | Select-Object -Property Name, VMName, ComputerName
    }
}

Process {
    # Get volumes info
    $ListLogicalDisk = Get-WmiObject -Namespace Root/CimV2 -Class Win32_Volume

    foreach ($LogicalDisk in $ListLogicalDisk) {
        if ($LogicalDisk.Name -notlike '\\?\*') {
            $tmpoverallocationinfo = New-Object -TypeName overAllocationInfo -Property @{
                DriveLetter          = $LogicalDisk.Name
                NameRegex            = $LogicalDisk.Name + '*'
                Label                = $LogicalDisk.Label
                DriveTotalSpace      = $LogicalDisk.Capacity
                DriveUsedSpace       = $LogicalDisk.Capacity - $LogicalDisk.FreeSpace
                IsOverAllocated      = $FALSE
                WarningOverAllocated = $FALSE
            }
            $listoverallocationinfo.Add($tmpoverallocationinfo) | Out-null
        } 
    }
    # $listoverallocationinfo | Sort-Object NameRegex.length | ft

    # Loop on all VM 
    foreach ($vm in $vmlist) {
        # Collect VHD info of all VM on the HYPERV host
        $listvhdinfo = Get-VM -VMname $vm.VMName -ComputerName $vm.ComputerName | Select-Object -Property VMid | Get-VHD
        foreach ($vhdinfo in $listvhdinfo) {

            # Get the logical disk where is stored the VHD and collect it size
            # Then add it to the used space of the specific drive
            # and put the flag to 1 if this value is above the DriveTotalSpace
            for ($i = 0; $i -lt $listoverallocationinfo.Count; $i++) {
                if ($vhdinfo.Path -like $listoverallocationinfo[$i].NameRegex) {
                    for ($y = $i + 1; $y -lt $listoverallocationinfo.Count; $y++) { 
                        if ($vhdinfo.Path -like $listoverallocationinfo[$y].NameRegex) {
                            $listoverallocationinfo[$y].DriveUsedSpace += $vhdinfo.Size
                            if ($listoverallocationinfo[$y].DriveUsedSpace -gt $listoverallocationinfo[$y].DriveTotalSpace) {
                                $listoverallocationinfo[$y].IsOverAllocated = $TRUE
                            }
                            if ($listoverallocationinfo[$y].DriveUsedSpace -gt ($listoverallocationinfo[$y].DriveTotalSpace * $warningthreshold)) {
                                $listoverallocationinfo[$y].WarningOverAllocated = $TRUE
                            }
                            $break = $TRUE
                        }
                    }

                    if ($break) {
                        $break = $FALSE
                        break
                    }

                    $listoverallocationinfo[$i].DriveUsedSpace += $vhdinfo.Size
                    if ($listoverallocationinfo[$i].DriveUsedSpace -gt $listoverallocationinfo[$i].DriveTotalSpace) {
                        $listoverallocationinfo[$i].IsOverAllocated = $TRUE
                    }

                    if ($listoverallocationinfo[$i].DriveUsedSpace -gt ($listoverallocationinfo[$i].DriveTotalSpace * $warningthreshold)) {
                        $listoverallocationinfo[$i].WarningOverAllocated = $TRUE
                    }

                    $break = $TRUE
                } 
                if ($break) {
                    $break = $FALSE
                    break
                }

            }
        }
    }
}

End {
    $criticaldrives = $listoverallocationinfo | Where-Object -FilterScript { $_.IsOverAllocated -eq $TRUE }
    $warningdrives = $listoverallocationinfo | Where-Object -FilterScript { $_.WarningOverAllocated -eq $TRUE -and $_.IsOverAllocated -ne $TRUE }

    if ($criticaldrives -and $warningdrives ) {
        Write-Output "[$version] Both critical and warning overallocation on volume detected"
        foreach ($WarningDrive in $warningdrives) {
            $myoutput = $criticalmsg + $criticaldrives.DriveLetter
            write-output $myoutput
        }
        foreach ($WarningDrive in $warningdrives) {
            $myoutput = $warningmsg + $warningdrives.DriveLetter
            write-output $myoutput
        }
        exit $returnStateCritical
    }
    elseif ($criticaldrives) {
        Write-Output "[$version] Critical overallocation on volume detected"
        foreach ($CriticalDrive in $criticaldrives) {
            $myoutput = $criticalmsg + $criticaldrives.DriveLetter
            write-output $myoutput
        }
        exit $returnStateCritical
    }
    elseif ($warningdrives) {
        Write-Output "[$version] Warning overallocation on volume detected"
        foreach ($WarningDrive in $warningdrives) {
            $myoutput = $warningmsg + $warningdrives.DriveLetter
            write-output $myoutput
        }
        exit $returnStateCritical
    }
    elseif (!$warningdrives -and !$criticaldrives) {
        Write-Output "[$version] Ok"
        exit $returnStateOK
    }
}
