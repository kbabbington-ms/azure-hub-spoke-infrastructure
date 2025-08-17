// Windows Admin Center Gateway VM Module (Simplified)
// Creates a Windows Server VM with Windows Admin Center for infrastructure management

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('VM size for the Windows Admin Center Gateway')
param vmSize string = 'Standard_D2s_v5'

@description('Admin username for the VM')
param adminUsername string = 'azureadmin'

@description('Admin password for the VM')
@secure()
param adminPassword string

@description('Management subnet ID where VM will be deployed')
param managementSubnetId string

@description('Tags to apply to resources')
param tags object = {}

// Variables
var vmName = 'vm-wac-${take(workloadName, 6)}-${environment}' // Stays under 15 chars
var nicName = 'nic-wac-${workloadName}-${environment}-${location}'
var osDiskName = 'disk-${vmName}-os'
var dataDiskName = 'disk-${vmName}-data'
var computerName = take('wac-${workloadName}-${environment}', 15)

// Network Security Group for Windows Admin Center VM
resource wacVmNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-wac-vm-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowWACHttpsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowRDPFromBastion'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '10.1.0.0/26' // Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowWinRMFromVNet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '5985'
            '5986'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInternetOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowVNetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Public IP for Windows Admin Center
resource wacPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-wac-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'wac-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
}

// Network Interface for Windows Admin Center VM
resource wacNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: managementSubnetId
          }
          publicIPAddress: {
            id: wacPublicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: wacVmNsg.id
    }
  }
}

// Windows Admin Center Gateway Virtual Machine
resource wacVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 128
      }
      dataDisks: [
        {
          name: dataDiskName
          diskSizeGB: 256
          lun: 0
          createOption: 'Empty'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: wacNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// Custom Script Extension to install Windows Admin Center
resource wacInstallExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: wacVm
  name: 'InstallWindowsAdminCenter'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "New-Item -ItemType Directory -Path C:\\temp -Force; Invoke-WebRequest -Uri https://aka.ms/WACDownload -OutFile C:\\temp\\WindowsAdminCenter.msi -UseBasicParsing; Start-Process -FilePath msiexec.exe -ArgumentList /i, C:\\temp\\WindowsAdminCenter.msi, /qn, SME_PORT=443, SSL_CERTIFICATE_OPTION=generate -Wait; New-NetFirewallRule -DisplayName WindowsAdminCenter -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow; Enable-PSRemoting -Force; Write-Output Installation completed successfully"'
    }
  }
}

// Outputs
output vmId string = wacVm.id
output vmName string = wacVm.name
output computerName string = computerName
output privateIpAddress string = wacNic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = wacPublicIp.properties.ipAddress
output publicFqdn string = wacPublicIp.properties.dnsSettings.fqdn
output wacUrl string = 'https://${wacPublicIp.properties.dnsSettings.fqdn}'
output wacInternalUrl string = 'https://${wacNic.properties.ipConfigurations[0].properties.privateIPAddress}'
output networkSecurityGroupId string = wacVmNsg.id
output networkInterfaceId string = wacNic.id
output adminUsername string = adminUsername
