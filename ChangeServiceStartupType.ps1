[string]$ServiceName = "Wuauserv"

$complist = (
    "test01",
    "test02",
   )

foreach ($computer in $complist) {
    Invoke-Command -ComputerName $computer -ScriptBlock {
      Set-Service -Name Wuauserv -StartupType Manual
      Get-Service -Name Wuauserv | Select -Property Name,StartType,PSComputerName | ft -Autosize
    }
}
