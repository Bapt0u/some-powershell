<#
.SYNOPSIS
Check whether this kb is installed or not.

Changelog :
- V0.1 - 26/05/22 @ Baptiste Porte
- V1.0 - 25/07/22 @ BP, Le test de reboot ne marchant pas, il a été enlevé. 

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

ServerName   KbName    KbInstalled  InstalledDate
----------   ------    -----------  -------------
srv-hyperv01 KB4512578        True  09/07/2019 00:00:00
srv-hyperv01 KB5013941       False  None


.EXAMPLE
PS > .\IsThisKbInstalled.ps1 -ListServer "srv-hyperv01","srv-hyperv02","foo"
Error on foo : NOT ACCESSIBLE.

ServerName   KbName    KbInstalled  InstalledDate
----------   ------    -----------  -------------
srv-hyperv01 KB4512578        True   09/07/2019 00:00:00
srv-hyperv01 KB4589208       False   None
srv-hyperv01 KB5014022       False   None
srv-hyperv02 KB4512578       False   None
srv-hyperv02 KB4589208        True   05/26/2022 00:00:00
srv-hyperv02 KB5014022        True   05/26/2022 00:00:00

.EXAMPLE
PS > .\IsThisKbInstalled.ps1 -ListServer "srv-hyperv02","foo" -ListKbToCheck "KB4512578","KB7"
Error on foo : NOT ACCESSIBLE.

ServerName   KbName    KbInstalled  InstalledDate
----------   ------    -----------  -------------
srv-hyperv02 KB4512578       False  None
srv-hyperv02 KB7             False  None

.LINK
None

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
        "srv-hds1-proc1",
        "SRV-HDS1-DFS1",
        "SRV-HDS1-DC2"

    }

    # Default value if no $ListKbToCheck parameter is set
    if (!$ListKbToCheck) {
        [System.String[]]$ListKbToCheck = 
        "KB5014692"
    }

    ################################################################
    ################################################################

    class KbInfo {
        [System.String]$ServerName
        [System.String]$KbName
        [Bool]$KbInstalled
        [System.String]$InstalledDate
    }

    $ListKbInfo = New-Object System.Collections.ArrayList

}

Process {
    # Loop on the server list
    foreach ($Server in $ListServer) {
        #Loop on the KB list
        for ($i = 0; $i -lt $ListKbToCheck.Count; $i++) {
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
