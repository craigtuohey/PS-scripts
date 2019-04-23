Add-WindowsFeature “RSAT-AD-Tools”
Restart-Computer

Add-WindowsFeature -Name “ad-domain-services” -IncludeAllSubFeature -IncludeManagementTools 


$domainname = “potato.com” 
$netbiosName = “POTATO” 
Import-Module ADDSDeployment 
Install-ADDSForest -CreateDnsDelegation:$false ` 
-DatabasePath “C:\Windows\NTDS” ` 
-DomainMode “Win2016” ` 
-DomainName $domainname ` 
-DomainNetbiosName $netbiosName ` 
-ForestMode “Win2016” ` 
-InstallDns:$true ` 
-LogPath “C:\Windows\NTDS” ` 
-NoRebootOnCompletion:$false ` 
-SysvolPath “C:\Windows\SYSVOL” ` 
-Force:$true

dcpromo.exe