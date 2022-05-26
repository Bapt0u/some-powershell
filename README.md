# Some PowerShell scripts about Hyper V

*In progress*

## General description

### Old Checkpoint 
CheckpointVM.ps1 check if there is checkpoint older than `-LimiteDate` attached to any VM on the HYPERV host  

### Disk over-allocation
DiskOverAlloc.ps1 is usefull in case you configure your disks in dynamic. It will calculate the case where all dynamic disks are fully used. If this sum is above the capacity of the drive where the VHD is stored, then it return the name of this drive as well as it maximum size and the over-allocation value. 

### IsThisKbInstalled

Check whether a kb is installed. As I didn't really understand where to query all installed updates, this script check two WMI class: 
- Win32_reliabilityRecords
- Win32_QuickFixEngineering  

It might be slower but you can trust the result. Moreover, it always be faster than to check manually in the control panel, at least I hope.  
