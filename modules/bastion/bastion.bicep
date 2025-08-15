// Azure Bastion Module
// Creates Azure Bastion host for secure remote access

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('Bastion subnet resource ID')
param bastionSubnetId string

@description('Tags to apply to resources')
param tags object = {}

// Public IP for Bastion
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-bas-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: 'bas-${workloadName}-${environment}-${uniqueString(resourceGroup().id)}'
    }
  }
}

// Azure Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: 'bas-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: bastionSubnetId
          }
        }
      }
    ]
  }
}

// Outputs
output bastionHostId string = bastionHost.id
output bastionHostName string = bastionHost.name
output bastionPublicIpId string = bastionPublicIp.id
output bastionPublicIpAddress string = bastionPublicIp.properties.ipAddress
