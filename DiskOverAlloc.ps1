<#
.SYNOPSIS
Verifie la presence de surallocation d'espace disque

.DESCRIPTION
Verifie la presence de surallocation d'espace disque

.INPUTS
Aucune input pour le moment

.OUTPUTS
[Collections.Generic.List[OverAllocationInfo]] Retourne un tableau de données sous le format :

PS > .\DiskOveAlloc.ps1

DriveLetter DriveTotalSpace DriveUsedSpace IsOverAllocated
----------- --------------- -------------- ---------------
C:              42303746048   164179705856            True

A noter que DriveTotalSpace et DriveUsedSpace sont en Byte. 

.EXAMPLE
PS> DiskOverAlloc.ps1

DriveLetter DriveTotalSpace DriveUsedSpace IsOverAllocated
----------- --------------- -------------- ---------------
C:              42303746048   164179705856            True

.LINK
Online version: http://gitlab.infocheops.local/microsoft

#>

Param 
( 
    [parameter(Mandatory = $FALSE)]
    [int]$MaxThreshold = 1,
    [int]$returnStateOK = 0,
    [int]$returnStateWarning = 1,
    [int]$returnStateCritical = 2,
    [int]$returnStateUnknown = 3,
    $WarningThreshold = 0.5
)

Begin {
    $ListVMName = (Get-VM).Name

    class OverAllocationInfo {
        [System.String]$DriveLetter
        [System.UInt64]$DriveTotalSpace
        [System.UInt64]$DriveUsedSpace
        [bool]$IsOverAllocated
        [bool]$WarningOverAllocated
    }
    
    $ListOverAllocationInfo = New-Object System.Collections.ArrayList

    $Version = "V1.0"
    
}

Process {

    # Get drives info (Mount Letter, Total Space, Used Space)
    $ListLogicalDisk = Get-WmiObject -Namespace Root/CimV2 -Class Win32_LogicalDisk

    foreach ($LogicalDisk in $ListLogicalDisk) {
        $OverAllocationInfoo = New-Object -TypeName OverAllocationInfo -Property @{
            DriveLetter     = $LogicalDisk.DeviceID
            DriveTotalSpace = $LogicalDisk.Size
            DriveUsedSpace  = $LogicalDisk.Size - $LogicalDisk.FreeSpace
            IsOverAllocated = $FALSE
            WarningOverAllocated = $FALSE
        }
        $ListOverAllocationInfo.Add($OverAllocationInfoo) | Out-Null
    }

    # Loop on all VM 
    foreach ($VMName in $ListVMName) {
        # Collect VHD info of all VM on the HYPERV host
        $ListVHDInfo = Get-VM -VMname $VMName | Select-Object -Property VMid | Get-VHD
        foreach ($VHDInfo in $ListVHDInfo) {

            # Get the logical disk where is stored the VHD and collect it size
            # Then add it to the used space of the specific drive
            # and put the flag to 1 if this value is above the DriveTotalSpace
            for ($i = 0; $i -lt $ListOverAllocationInfo.Count; $i++) {
                if ($VHDInfo.Path -match $ListOverAllocationInfo[$i].DriveLetter) {
                    $ListOverAllocationInfo[$i].DriveUsedSpace += $VHDInfo.Size
                    if ($ListOverAllocationInfo[$i].DriveUsedSpace -gt $ListOverAllocationInfo[$i].DriveTotalSpace) {
                        $ListOverAllocationInfo[$i].IsOverAllocated = $TRUE
                    } elseif ($ListOverAllocationInfo[$i].DriveUsedSpace -gt ($ListOverAllocationInfo[$i].DriveTotalSpace*$WarningThreshold)) {
                        $ListOverAllocationInfo[$i].WarningOverAllocated = $TRUE
                    }
                    break
                }
            }
        }
    }


}

End {
    $CriticalDrives = $ListOverAllocationInfo | Where-Object -FilterScript { $_.IsOverAllocated -eq $TRUE }
    $WarningDrives = $ListOverAllocationInfo | Where-Object -FilterScript { $_.WarningOverAllocated -eq $TRUE -and  $_.IsOverAllocated -ne $TRUE }

    if ($CriticalDrives -and $WarningDrives ) {
        Write-Output "[$Version] Critical overallocation space disk on $($CriticalDrives.DriveLetter)"
        Write-Output "Warning overallocation space disk on $($WarningDrives.DriveLetter)"
        exit $returnStateCritical
    } elseif ($CriticalDrives) {
        Write-Output "[$Version] Critical overallocation space disk on $($CriticalDrives.DriveLetter)"
    } elseif ($WarningDrives) {
        Write-Output "Warning overallocation space disk on $($WarningDrives.DriveLetter)"
        exit $returnStateWarning
    } elseif (!$WarningDrives -and !$CriticalDrives) {
        Write-Output "Ok"
        exit $returnStateOK
    }
}
