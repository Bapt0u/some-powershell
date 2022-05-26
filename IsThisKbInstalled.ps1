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
ListServer
ListKbToCheck

.PARAMETER ListServer
String list of which server you want to check

.PARAMETER ListKbToCheck
String list of which KB you want to check

.OUTPUTS
[Collections.Generic.List[KbInfo]] Retourne un tableau de données sous le format :

PS > .\IsThisKbInstalled.ps1

ServerName   KbName    KbInstalled PendingReboot InstalledDate
----------   ------    ----------- ------------- -------------
srv-hyperv01 KB4512578        True         False 09/07/2019 00:00:00
srv-hyperv01 KB5013941       False         False None


.EXAMPLE
PS > .\IsThisKbInstalled.ps1 -ListServer "srv-hyperv01","srv-hyperv02","foo"
Error on foo : NOT ACCESSIBLE.

ServerName   KbName    KbInstalled PendingReboot InstalledDate
----------   ------    ----------- ------------- -------------
srv-hyperv01 KB4512578        True         False 09/07/2019 00:00:00
srv-hyperv01 KB4589208       False         False None
srv-hyperv01 KB5014022       False         False None
srv-hyperv02 KB4512578       False         True  None
srv-hyperv02 KB4589208        True         True  05/26/2022 00:00:00
srv-hyperv02 KB5014022        True         True  05/26/2022 00:00:00

.EXAMPLE
PS > .\IsThisKbInstalled.ps1 -ListServer "srv-hyperv02","foo" -ListKbToCheck "KB4512578","KB7"
Error on foo : NOT ACCESSIBLE.

ServerName   KbName    KbInstalled PendingReboot InstalledDate
----------   ------    ----------- ------------- -------------
srv-hyperv02 KB4512578       False         False None
srv-hyperv02 KB7             False         False None

.LINK
Online version: http://gitlab.infocheops.local/microsoft

#>

Param (
    [parameter(Mandatory = $FALSE, ValuefromPipeline = $True)]
    [System.String[]]$ListServer,
    [parameter(Mandatory = $FALSE, ValuefromPipeline = $True)]
    [string[]]$ListKbToCheck

)


Begin {

    ################################################################
    #          You can HARD CODE your values here                  #
    ################################################################

    # Default value if no $ListServer parameter is set
    if (!$ListServer) {
        [System.String[]]$ListServer = 
        "server-1",
        "server-2",
        "test"

    }

    # Default value if no $ListKbToCheck parameter is set
    if (!$ListKbToCheck) {
        [System.String[]]$ListKbToCheck = 
        "KB4512578",
        "KB5013941"
    }

    ################################################################
    ################################################################


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
    # Test on local machine
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

    [Bool]$PendingReboot = $FALSE

}

Process {
    # Loop on the server list
    foreach ($Server in $ListServer) {
        if ($env:COMPUTERNAME -match $Server) {
            $PendingReboot = Test-PendingRebootLocal($Server)
        }
        else {
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
                # Then try with the class Win32_ReliabilityRecords
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