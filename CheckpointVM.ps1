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

                # Test if the snapshot is older than 5 days
                if ($VMCheckpoint[$i].CreationTime -lt (Get-Date).AddDays(-$LimitDate)) {

                    # Add it to the ListCheckpointinfo object
                    $fuckit = New-Object -TypeName CheckpointInfo -Property @{
                        SnapName     = $VMCheckpoint[$i].Name
                        CreationTime = $VMCheckpoint[$i].CreationTime
                        AttachedVM   = $VMName
                    }
    
                    $ListCheckpointInfo.Add($fuckit) | Out-Null
                }  
            }
        }
    }
}

End {
    $ListCheckpointInfo
}