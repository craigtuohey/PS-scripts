<#
.SYNOPSIS
  Deploy a small AD domain behind load balancer

    
.PARAMETER <Parameter_Name>

    <Brief description of parameter input required. Repeat this attribute if required>
    
.INPUTS

  <Inputs if any, otherwise state None>

.OUTPUTS

  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>

.NOTES

  Version:        1.0

  Author:         Craig Tuohey

  Creation Date:  23/4/19

  Purpose/Change: Deploy a small domain to test various tools
    

.EXAMPLE

    .\MSPlayGround -resourceGroup "Azure Resource Group Name"

#>

Param (
[Parameter(Mandatory=$True)]
[ValidateNotNull()]
[String]
$resourceGroup
)


function setup()
{
    if (Get-Module -ListAvailable Az.Compute)
    {
        write-host -ForegroundColor DarkYellow "PowerShell Az module not loaded, loading now"
        Import-Module Az
        if (!(Get-Module -ListAvailable Az.Compute))
        {
            write-host -ForegroundColor DarkRed "Module not installed, installing now"
            Install-Module -Name Az -AllowClobber
            Import-Module Az
            if (Get-Module -ListAvailable Az)
            {
                write-host -ForegroundColor DarkGreen "Module Az installed"
            }
        }
        write-host -ForegroundColor Green "Az Module loaded\n"
    }
       
    write-host -ForegroundColor Green "logging you into Azure, check your browser\n"
    Connect-AzAccount
}


function createRG($resourceGroup, $region)
{
    write-host "Creating resrouce group named $resoruceGroup"
    New-AzResourceGroup -Name $resourceGroup -Location $region

}



function createInfra($resourceGroup, $region)
{

write-host -ForegroundColor Green "Creating Public IP rules\n"

$pip = New-AzPublicIpAddress -Name "LoadBal-pip" -Location $region -ResourceGroupName $resourceGroup -AllocationMethod Dynamic

write-host -ForegroundColor Green "Public IP is $pip.PublicIpAddress"

write-host -ForegroundColor Green "Creaging Front End IP Address\n"
$frontendIP = New-AzLoadBalancerFrontendIpConfig -Name LB-frontendIP -PublicIpAddress $pip

write-host -ForegroundColor Green "Creating Backend Address Pool\n"
$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name LB-backend 

$probe = New-AzLoadBalancerProbeConfig -Name "MyProbe" -Protocol "http" -Port 80 -IntervalInSeconds 15 -ProbeCount 2 -RequestPath "healthcheck.aspx"
write-host -ForegroundColor Green "Creating Load Balancer\n"


$lbrule = New-AzLoadBalancerRuleConfig -Name "HTTP" -FrontendIpConfiguration $frontendIP -BackendAddressPool $backendPool -Protocol Tcp -Probe $probe -FrontendPort 80 -BackendPort 80

write-host -ForegroundColor Green "Creating NAT rules\n"
$natrule1 = New-AzLoadBalancerInboundNatRuleConfig -Name "RDP1" -FrontendIpConfiguration $frontendIP -Protocol TCP -FrontendPort 3441 -BackendPort 3389

$lb = New-AzLoadBalancer -Name 'LoadBalancer-LB' -ResourceGroupName $resourceGroup -Location $region -FrontendIpConfiguration $frontendIP -BackendAddressPool $backendPool -Probe $probe -InboundNatRule $natrule1 



$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $resourceGroup"-Subnet" -AddressPrefix 192.168.1.0/24
write-host -foregroundcolor Green "subnet "$subnetConfig.Name" created with address space "$subnetConfig.AddressPrefix

# Create the virtual network
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroup -Location $region -Name $resourceGroup"-Vnet" -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig
write-host -foregroundcolor Green "virtual network created with address space "

$NSGrule = New-AzNetworkSecurityRuleConfig -Name 'NSG-RDP' -Description 'Allow RDP' -Access Allow -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389

$nsg = New-AzNetworkSecurityGroup `
-ResourceGroupName $resourceGroup `
-Location $region `
-Name 'NSG-rules' `
-SecurityRules $NSGrule


$nicVM1 = New-AzNetworkInterface `
-ResourceGroupName $resourceGroup `
-Location $region `
-Name 'MyVM1' `
-LoadBalancerBackendAddressPool $backendPool `
-NetworkSecurityGroup $nsg `
-LoadBalancerInboundNatRule $natrule1 `
-Subnet $vnet.Subnets[0]
$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString $(Read-Host "Enter VM Password") -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$vm1 = New-AzVm -ResourceGroupName $resourceGroup -Name "MyVM1" -Location $region -VirtualNetworkName $vnet.Name -SubnetName $subnetConfig.Name -SecurityGroupName $nsg.Name -OpenPorts 3389 -Credential $Credential -Image Win2016Datacenter
write-host "VM created: "+ $vm1.Name
Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -VMName $vm1.Name -CommandId 'RunPowerShellScript' -ScriptPath '.\support\DC-Setup.ps1'
}

function deployVMS($resourceGroup)
{

}

function enableLogging(){

    write-host -ForegroundColor Yellow "Creating Log analytics Workspace"
    $laws = New-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroup -Location $region -Name $resourceGroup'-la' -Sku standalone

    write-host -ForegroundColor Green 'Log Analytics Workspace' $laws.Name

    write-host -ForegroundColor Yellow "enabling logging on infrastructure"
}

function uploadTools()
{
#Start-Sleep -Seconds 600
}

function runScripts($resourceGroup, $vm1)
{
    write-host -ForegroundColor Yellow "Running script on vm"
    #while($vm1.StatusCode -ne 'Succeeded')
    #{
    #    write-host -ForegroundColor Yellow "status "$vm1.StatusCode " waiting 4 minutes!"
    #    Start-Sleep -Seconds 240
    #}
    write-host -ForegroundColor Green "status "$vm1.StatusCode
    Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -VMName $vm1.Name -CommandId 'RunPowerShellScript' -ScriptPath 'C:\users\crtuohey\Desktop\test.ps1'

    write-host -ForegroundColor Green "Finished\n"
}


setup
$region = "Australia East"
createRG $resourceGroup $region
$vm1 = createInfra $resourceGroup $region
enableLogging
uploadTools
runScripts $resourceGroup $vm1
