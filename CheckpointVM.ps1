<#
.SYNOPSIS
Verifie la presence d'ancien snapshot

.DESCRIPTION
Verifie la presence d'ancien snapshot

.PARAMETER LimiteDate
Specifie le nombre de jour maximum  toléré pour la durée de vie d'un snapshot 

.INPUTS
LimiteDate

.OUTPUTS
[Collections.Generic.List[CheckpointInfo]] Retourne un tableau de données sous le format :

PS > .\CheckpointVM.ps1

SnapName CreationTime        AttachedVM
-------- ------------        ----------
snap1    26/04/2022 19:14:24 srv-test02
snap2    05/05/2022 17:39:22 srv-test02
snap3    05/05/2022 17:39:23 srv-test02

.EXAMPLE
PS C:\Users\toto\dev\some-powershell> .\CheckpointVM.ps1 -LimitDate 15

SnapName CreationTime        AttachedVM
-------- ------------        ----------
snap1    26/04/2022 19:14:24 srv-test02

.LINK
Online version: http://gitlab.infocheops.local/microsoft

#>

Param 
( 
    [parameter(Mandatory = $false)]
    [int]$LimitDate = 5
)
Begin {
    $VMList = (Get-VM).Name

    class CheckpointInfo {
        [System.String]$SnapName
        [System.DateTime]$CreationTime
        [System.String]$AttachedVM;
    }
    
    $ListCheckpointInfo = New-Object System.Collections.ArrayList
}
Process {
    # Loop on all VM 
    foreach ($VMName in $VMList) {
        # Test if there is checkpoint
        if ($VMCheckpoint = Get-VMSnapshot -VMName $VMName) {
            # Loop on all checkpoint on the VM 
            for ($i = 0; $i -lt $VMCheckpoint.Count; $i++) {

                # Test if the snapshot is older than $LimitDate days
                if ($VMCheckpoint[$i].CreationTime -lt (Get-Date).AddDays(-$LimitDate)) {

                    # Add it to the ListCheckpointinfo object
                    $CheckpointInfo = New-Object -TypeName CheckpointInfo -Property @{
                        SnapName     = $VMCheckpoint[$i].Name
                        CreationTime = $VMCheckpoint[$i].CreationTime
                        AttachedVM   = $VMName
                    }
    
                    $ListCheckpointInfo.Add($CheckpointInfo) | Out-Null
                }  
            }
        }
    }
}

End {
    $ListCheckpointInfo
}