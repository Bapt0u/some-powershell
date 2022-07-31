<#
.SYNOPSIS
Check the presence of checkpoint.

.DESCRIPTION
Verifie la presence d'ancien snapshot

.PARAMETER LimiteDate
Definies the maximum age for a checkpoint 

.INPUTS
LimiteDate

.OUTPUTS
PS > .\CheckpointVM.ps1 -LimiteDate 4
[V1.0] Warning
2 snapshots are above the limit of 4 days on the following VMs:
* vm1 (node1)

.EXAMPLE
PS C:\Users\toto\dev\some-powershell> .\CheckpointVM.ps1 -LimitDate 15
[V1.0] Warning
2 snapshots are above the limit of 15 days on the following VMs:
* vm1 (node1)
* vm2 (node2)

.LINK
None

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

    # Test whether the cluster exists
    $msclusterexists = Get-WmiObject -Namespace "root\MSCluster" -ClassName "MSCluster_Resource" -List -ErrorAction SilentlyContinue
    if ($null -eq $msclusterexists) {
        $vmlist = Get-VM | Select-Object -Property Name, VMName, ComputerName
    }
    else {
        $clustername = (Get-Cluster).Name
        $vmlist = Get-VM -ComputerName (Get-ClusterNode -Cluster $clustername)  | Select-Object -Property Name, VMName, ComputerName
    }


    class CheckpointInfo {
        [System.String]$SnapName
        [System.DateTime]$CreationTime
        [System.String]$AttachedVM
        [System.String]$ClusterNodeName
    }
    
    $listcheckpointinfo = New-Object System.Collections.ArrayList
}

Process {
    # Loop on all VM 
    foreach ($vm in $vmlist) {
        # Test if there is checkpoint
        $listvmcheckpoint = Get-VMSnapshot -VMName $vm.VMName -ComputerName $vm.ComputerName

        # Loop on all checkpoint on the VM 
        foreach ($vmcheckpoint in $listvmcheckpoint) {
            # Test if the snapshot is older than $LimitDate days
            # if ($vmcheckpoint.CreationTime -lt (Get-Date).AddDays(-$LimitDate)) {

            # Add it to the ListCheckpointinfo object
            $checkpointinfo = New-Object -TypeName CheckpointInfo -Property @{
                SnapName        = $vmcheckpoint.Name
                CreationTime    = $vmcheckpoint.CreationTime
                AttachedVM      = $vm.VMName
                ClusterNodeName = $vm.ComputerName
            }
    
            $listcheckpointinfo.Add($checkpointinfo) | Out-Null
            # }  
        }
        
    }
}

End {
    $nbtotal = $listcheckpointinfo.Count
    $nbtodelete = ($listcheckpointinfo | Where-Object CreationTime -lt ((Get-Date).AddDays(-$LimitDate))).Count

    if ($nbtotal -eq 0) {
        Write-Output "[$VERSION] OK"
        Write-Output "No checkpoint on host"
        exit $returnStateOK
    }

    if ($nbtodelete -eq 0) {
        Write-Output "[$VERSION] OK"
        exit $returnStateOK
    }
    elseif ($nbtodelete -eq 1) {
        Write-Output "[$VERSION] Warning"
        $myoutput = "" + $nbtodelete + " snapshot is above the limit of " + $LimitDate + " days on " + $listcheckpointinfo.AttachedVM
        if ($msclusterexists) { $myoutput += " (" + $listcheckpointinfo.ClusterNodeName + ")" }
        Write-Output $myoutput
        exit $returnStateCritical

    }
    elseif ($nbtodelete -ge 2) {
        Write-Output "[$VERSION] Warning" 
        $myoutput = "" + $nbtodelete + " snapshots are above the limit of " + $LimitDate + " days on the following VMs: "
        Write-Output $myoutput
        foreach ($vm in ($listcheckpointinfo | Select-Object -Unique -Property AttachedVM, ClusterNodeName)) {
            if ($msclusterexists) { $myoutput = "* " + $vm.AttachedVM + " (" + $vm.ClusterNodeName + ")" }else { $myoutput = $vm.AttachedVM }
            Write-Output $myoutput
        }
        exit $returnStateCritical
    }
}