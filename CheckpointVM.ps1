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
    [parameter(Mandatory = $FALSE)]
    [int]$LimitDate = 5,
    [string]$VERSION = "V1.0",
    [int]$returnStateOK = 0,
    [int]$returnStateWarning = 1,
    [int]$returnStateCritical = 2,
    [int]$returnStateUnknown = 3
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
    $nb = $ListCheckpointInfo.Count

    if ($nb -eq 0) {
        Write-Output "[$VERSION] OK"
        exit $returnStateOK
    } elseif ($nb -eq 1) {
        Write-Output "[$VERSION] $nb snapshot is above the limit of $LimitDate days on $($ListCheckpointInfo.AttachedVM)"
        exit $returnStateCritical

    }elseif ($nb -ge 2) {
        Write-Output "[$VERSION] $nb snapshots are above the limit of $LimitDate days on the following VMs: "
        foreach ($vm in ($ListCheckpointInfo | Select-Object -Unique -Property AttachedVM)) {
            Write-Output $vm.AttachedVM
        }
        exit $returnStateCritical
    }
}