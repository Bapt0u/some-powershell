Function Check-WMINameSpace {
    <#
    .SYNOPSIS
    Verifie la presence des NameSpace WMI

    .DESCRIPTION
    Verifie la presence des NameSpace WMI

    .PARAMETER ComputerName
    Specifie le ou les nom des machines a tester 

    .PARAMETER NameSpace
    Specifie le ou les nom des NameSpace WMI à tester

    .PARAMETER Credentials
    Specifie le jeu de credit d'authentification à utiliser

    .INPUTS
    ComputerName

    .OUTPUTS
    [bool] si un seul element est recherché
    [Collections.Generic.List[WsMINamespace]] Retourne un tableau de données sous le format :

    ComputerName NameSpace    IsPresent
    ------------ ---------    ---------
    Computer01   NameSpace01  True
    Computer01   NameSpace02  True
    Computer02   NameSpace01  False
    Computer02   NameSpace02  True

    .EXAMPLE
    PS> Check-WMINamespace -ComputerName "Computer01"  -Namespace "NameSpace01"
    true

    .EXAMPLE
    PS> Check-WMINamespace -ComputerName "Computer01"  -Namespace "NameSpace01", "NameSpace02"

    ComputerName NameSpace    IsPresent
    ------------ ---------    ---------
    Computer01   NameSpace01  True
    Computer01   NameSpace02  True

    .EXAMPLE
    PS> Check-WMINamespace -ComputerName "Computer01", "Computer02"  -Namespace "NameSpace01", "NameSpace02"

    ComputerName NameSpace    IsPresent
    ------------ ---------    ---------
    Computer01   NameSpace01  True
    Computer01   NameSpace02  True
    Computer02   NameSpace01  False
    Computer02   NameSpace02  True

    .EXAMPLE
    PS> "Computer01", "Computer02" | Check-WMINamespace  -Namespace "NameSpace01", "NameSpace02"

    ComputerName NameSpace    IsPresent
    ------------ ---------    ---------
    Computer01   NameSpace01  True
    Computer01   NameSpace02  True
    Computer02   NameSpace01  False
    Computer02   NameSpace02  True

    .LINK
    Online version: http://gitlab.infocheops.local/microsoft

#>

    Param 
    ( 
        [parameter(Mandatory = $false, ValuefromPipeline = $True)]
        [string[]]$ComputerName = "localhost",
        [parameter(Mandatory = $true)]
        [string[]]$NameSpace,
        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credentials
    )
    Begin {
        # Variables => Declaration
        ## Variables => $Return : Definition du tableau de retour.
        [Collections.Generic.List[PSCustomObject]]$Return = New-Object Collections.Generic.List[PSCustomObject]
    }
    Process {
        
        ## Iteration => Pour chaque entrée $ComputerName
        foreach ($_ComputerName in $ComputerName) {
            ## Iteration => Pour chaque entrée $NameSpace
            foreach ($_Namespace in $NameSpace) {
                # Variables => Declaration
                ## Variables => $_Return : Definition du booleen en cas de non retour
                $_Return = $false
                
                try { 
                    # Condition => En cas de presence de l'entrée $Credentials
                    if ([bool]$Credentials) {
                        # Recuperation de de l'object WMI (retourne un object seulement si l'object WMI est present)
                        $_Return = Get-WmiObject -Class __Namespace -Namespace root  -ComputerName $_ComputerName -Credential $Credentials -ErrorAction Stop -WarningAction SilentlyContinue | Where-Object { $_.Name -eq $_Namespace } 
                    }
                    # Condition => En cas de l'absence de l'entrée $Credentials
                    else {
                        # Recuperation de de l'object WMI (retourne un object seulement si l'object WMI est present)
                        $_Return = Get-WmiObject -Class __Namespace -Namespace root  -ComputerName $_ComputerName -ErrorAction Stop -WarningAction SilentlyContinue | Where-Object { $_.Name -eq $_Namespace } 
                    }
                }
                catch {
                    # Writeexceptions : En cas de defaillance des actions precedentes
                    Write-Debug $_
                }
                finally {
                    # Tableau => Ajout d'un enregistrement pour chaque $_Namespace, pour chaque $_ComputerName
                    $Return.Add((New-Object PSObject -Property @{
                                PSTypeName   = "WsMINamespace"
                                ComputerName = $_ComputerName
                                NameSpace    = $_Namespace
                                IsPresent    = [bool]$_Return 
                            }))
                }
            }
        }
    }
    End {
        # Condition => Si le retour est unique, ne retourner qu'un boolean 
        if ($Return.Count -eq 1) {
            return [bool]$Return[0].IsPresent
        }
        # Sinon retourner le tableau
        return $Return
    }
}