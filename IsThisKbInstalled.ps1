<#
.SYNOPSIS
Check whether this kb is installed or not.

Changelog :
- V0.1 - 26/05/22 @ Baptiste Porte

.DESCRIPTION
Check whether this kb is installed or not.
This script MUST be executed with an account that has access to
the server list that you have entered. 

.INPUTS
None ATM

.OUTPUTS
[Collections.Generic.List[OverAllocationInfo]] Retourne un tableau de données sous le format :

PS > .\DiskOveAlloc.ps1

DriveLetter DriveTotalSpace DriveUsedSpace IsOverAllocated
----------- --------------- -------------- ---------------
C:              42303746048   164179705856            True

A noter que DriveTotalSpace et DriveUsedSpace sont en Byte. 

.EXAMPLE
PS> IsThisKbInstalled.ps1

ServerName   KbName    KbInstalled PendingReboot InstalledDate
----------   ------    ----------- ------------- -------------
srv-hyperv01 KB4512578        True          True 09/07/2019 00:00:00
srv-hyperv01 KB5013941       False          True 09/07/2019 00:00:00
srv-hyperv02 KB4512578       False          True 09/07/2019 00:00:00
srv-hyperv02 KB5013941        True          True 05/26/2022 00:00:00

.LINK
Online version: http://gitlab.infocheops.local/microsoft

#>

Param (


)


Begin {
    # Shamely stolen from StackOverflow 
    # https://stackoverflow.com/questions/47867949/how-can-i-check-for-a-pending-reboot
    function Test-PendingReboot($Server) {
        try {
            Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
                if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $TRUE }
                if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $TRUE }
                if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $TRUE }
                try { 
                    $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
                    $status = $util.DetermineIfRebootPending()
                    if (($null -ne $status) -and $status.RebootPending) {
                        return $TRUE
                    }
                }
                catch { }
            
                return $FALSE
            }
        }
        catch {
            Write-Output "Cannot test pending reboot on $Server"
            return $FALSE
        }
    }
    function Test-PendingRebootLocal($Server) {
        if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $TRUE }
        if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $TRUE }
        if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $TRUE }
        try { 
            $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
            $status = $util.DetermineIfRebootPending()
            if (($null -ne $status) -and $status.RebootPending) {
                return $TRUE
            }
        }
        catch { }
        return $FALSE
    }


    class KbInfo {
        [System.String]$ServerName
        [System.String]$KbName
        [Bool]$KbInstalled
        [Bool]$PendingReboot
        [System.String]$InstalledDate
    }

    $ListKbInfo = New-Object System.Collections.ArrayList

    [System.String[]]$ListServer = 
    "srv-hyperv01",
    "srv-hyperv02",
    "test"

    [System.String[]]$ListKbToCheck = 
    "KB4512578",
    "KB5013941",
    "KB4589208",
    "KB5014022"

    [Bool]$PendingReboot = $FALSE

}

Process {
    # Loop on the server list
    foreach ($Server in $ListServer) {
        if ($env:COMPUTERNAME -match $Server){
            $PendingReboot = Test-PendingRebootLocal($Server)
        }else{
            $PendingReboot = Test-PendingReboot($Server)
        }

        #Loop on the KB list
        for ($i = 0; $i -lt $ListKbToCheck.Count; $i++) {
            Write-Debug "In the for here"
            try {
                # First try with the class Win32_QuickFixEngineering
                if ($QuickFixInfo = Get-WmiObject -Class Win32_QuickFixEngineering -Namespace root\cimv2 -ComputerName $Server -ErrorAction Stop | 
                    Where-Object { $_.HotFixID -eq $ListKbToCheck[$i] } ) {
                    $KbInstalled = $TRUE
                    $InstalledDate = $QuickFixInfo.InstalledOn
                }
                elseif ($QuickFixInfo = Get-WmiObject -Class Win32_ReliabilityRecords -Namespace root\cimv2 -ComputerName $Server -ErrorAction Stop |
                    Select-Object -Property @{LABEL = "InstallDate"; EXPRESSION = { $_.ConvertToDateTime($_.timegenerated) } } | 
                    Where-Object { $_.productname -match $ListKbToCheck[$i] } 
                ) {
                    $KbInstalled = $TRUE
                    $InstalledDate = $QuickFixInfo.InstallDate
                }
                else {
                    $KbInstalled = $FALSE
                    $InstalledDate = "None"
                }

                $KbInfoo = New-Object -TypeName KbInfo -Property @{
                    ServerName    = $Server
                    KbName        = $ListKbToCheck[$i]
                    KbInstalled   = $KbInstalled
                    InstalledDate = $InstalledDate
                    PendingReboot = $PendingReboot
                }

                $ListKbInfo.Add($KbInfoo) | Out-Null
            }
            # If the server is not reachable, handle the error
            catch {
                Write-Output "Error on $Server : NOT ACCESSIBLE."
                break
            }
        }
    }

}

End {
    $ListKbInfo | Format-Table

}