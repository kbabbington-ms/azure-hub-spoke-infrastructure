// Virtual Machine Module
// Creates Windows Server VM with required extensions

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('VM subnet resource ID')
param vmSubnetId string

@description('Key Vault resource ID for storing VM admin password')
param keyVaultId string

@description('VM admin username')
param vmAdminUsername string = 'azureadmin'

@description('VM admin password')
@secure()
param vmAdminPassword string

@description('VM size')
param vmSize string = 'Standard_D4s_v5'

@description('Tags to apply to resources')
param tags object = {}

// Storage Account for Boot Diagnostics
resource bootDiagStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${take(uniqueString(resourceGroup().id), 21)}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
  }
}

// Network Interface for VM
resource vmNetworkInterface 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-vm-${workloadName}-${environment}-001'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vmSubnetId
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: true
    enableIPForwarding: false
  }
}

// Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-${workloadName}-${environment}-001'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-vm-${workloadName}-${environment}-001'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: 'vm-${take(workloadName, 8)}-001'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNetworkInterface.id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagStorageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

// Azure Monitor Agent Extension
resource azureMonitorAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// Microsoft Antimalware Extension
resource antimalwareExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'IaaSAntimalware'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: true
      ScheduledScanSettings: {
        isEnabled: true
        day: 7
        time: 120
        scanType: 'Quick'
      }
    }
  }
  dependsOn: [
    azureMonitorAgentExtension
  ]
}

// AAD Login for Windows Extension (Entra ID join)
resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: ''
    }
  }
  dependsOn: [
    antimalwareExtension
  ]
}

// Custom Script Extension for post-deployment configuration
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "Set-TimeZone -Id \'Central Standard Time\'; Write-Host \'VM configured successfully\'"'
    }
  }
  dependsOn: [
    aadLoginExtension
  ]
}

// Store VM admin password in Key Vault
resource vmPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/vm-admin-password'
  properties: {
    value: vmAdminPassword
    attributes: {
      enabled: true
    }
  }
}

// Outputs
output vmId string = virtualMachine.id
output vmName string = virtualMachine.name
output vmPrivateIpAddress string = vmNetworkInterface.properties.ipConfigurations[0].properties.privateIPAddress
output vmNetworkInterfaceId string = vmNetworkInterface.id
output bootDiagStorageAccountId string = bootDiagStorageAccount.id
output vmSystemAssignedIdentityPrincipalId string = virtualMachine.identity.principalId
