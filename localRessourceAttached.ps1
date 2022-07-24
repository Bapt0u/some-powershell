<#



#>


param (
    [parameter(Mandatory = $FALSE)]
    [int]$returnStateOK = 0,
    [int]$returnStateWarning = 1,
    [int]$returnStateCritical = 2,
    [int]$returnStateUnknown = 3
)

Begin {

    $version = "V0.1"
    $vmlist = Get-VM -ComputerName (Get-ClusterNode -Cluster cluster-labo)  | Select-Object -Property Name, VMName, ComputerName
    class localResourceInfo {
        [System.String]$Path
        [System.String]$ComputerName
        [System.String]$VMName
    }

    $listlocalresourceinfo = New-Object System.Collections.ArrayList
    $listvhdinfo = New-Object System.Collections.ArrayList
}


Process {

    # Test wheater the cluster exists

    $msclusterexists = Get-WmiObject -Namespace "root\MSCluster" -ClassName "MSCluster_Resource" -List -ErrorAction SilentlyContinue
    if ($null -eq $msclusterexists) {
        Write-Output "[$version] No cluster detected"
        exit $returnStateOK 
    }

    foreach ($vm in $vmlist) {
        $listvminfo = Get-VM -ComputerName $vm.ComputerName -VMname $vm.Name | Select-Object -Property VMid, ComputerName

        foreach ($vminfo in $listvminfo) {
            $listvhdinfo = Get-VHD -id $vminfo.VMid -ComputerName $vminfo.ComputerName
            # TODO: transform this foreach in function
            foreach ($vhdinfo in $listvhdinfo) {
                if ($vhdinfo.Path -notlike "C:\ClusterStorage\*") {
                    $tmplistlocalresourceinfo = New-Object -TypeName localResourceInfo -Property @{
                        Path         = $vhdinfo.Path
                        ComputerName = $vhdinfo.ComputerName
                        VMName       = $vm.VMName
                    }
                    $listlocalresourceinfo.Add($tmplistlocalresourceinfo)
                }
            }

            $listdvdinfo = Get-VMDvdDrive -VMname $vm.name
            # TODO: transform this foreach in function
            foreach ($dvdinfo in $listdvdinfo) {
                if ($dvdinfo.Path -notlike "C:\ClusterStorage\*") {
                    $tmplistlocallesourceinfo = New-Object -TypeName localResourceInfo -Property @{
                        Path         = $dvdinfo.Path
                        ComputerName = $dvdinfo.ComputerName
                        VMName       = $vm.VMName
                    }
                    $listlocalresourceinfo.Add($tmplistlocallesourceinfo)
                }
            }
        }
    }
}

End {
    $total = $listlocalresourceinfo.Count

    if ($total -eq 0) {
        Write-Output "[$version] Ok"
        exit $returnStateOK
    }
    elseif ($total -le 1) {
        Write-Output "[$version] One local resource is attached to a VM."
        Write-Output $listlocalresourceinfo[0].Path on $listlocalresourceinfo[0].VMName
        exit $returnStateWarning
    }
    elseif ($total -ge 2) {
        Write-Output "[$version] Multiple local resources are attached to VM."
        for ($i = 0; $i -lt $total; $i++) {
            Write-Output $listlocalresourceinfo[$i].Path on $listlocalresourceinfo[$i].VMName
        }
        exit $returnStateWarning
    }
}

