// Spoke Virtual Network Module
// Creates the spoke VNet with VM and private endpoint subnets

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('Spoke VNet address space')
param spokeVnetAddressSpace string = '192.16.2.0/24'

@description('VM subnet address space')
param vmSubnetAddressSpace string = '192.16.2.0/26'

@description('Private endpoint subnet address space')
param privateEndpointSubnetAddressSpace string = '192.16.2.64/28'

@description('SQL MI subnet address space')
param sqlMiSubnetAddressSpace string = '192.16.2.128/27'

@description('Tags to apply to resources')
param tags object = {}

// Spoke Virtual Network
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-spoke-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'snet-vm-${workloadName}-${environment}-${location}'
        properties: {
          addressPrefix: vmSubnetAddressSpace
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-pep-${workloadName}-${environment}-${location}'
        properties: {
          addressPrefix: privateEndpointSubnetAddressSpace
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-sqlmi-${workloadName}-${environment}-${location}'
        properties: {
          addressPrefix: sqlMiSubnetAddressSpace
          delegations: [
            {
              name: 'sqlMiDelegation'
              properties: {
                serviceName: 'Microsoft.Sql/managedInstances'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Network Security Group for VM Subnet
resource vmNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-vm-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRdpFromBastion'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '192.16.1.0/26' // Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowWinRMFromBastion'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '5985'
            '5986'
          ]
          sourceAddressPrefix: '192.16.1.0/26' // Bastion subnet
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowInternetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
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
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Network Security Group for Private Endpoint Subnet
resource pepNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-pep-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVNetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Network Security Group for SQL MI Subnet
resource sqlMiNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-sqlmi-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow_management_inbound'
        properties: {
          priority: 106
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: [
            '9000'
            '9003'
            '1438'
            '1440'
            '1452'
          ]
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow_misubnet_inbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '*'
          protocol: '*'
          sourceAddressPrefix: sqlMiSubnetAddressSpace
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow_health_probe_inbound'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '*'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow_management_outbound'
        properties: {
          priority: 102
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: [
            '80'
            '443'
            '12000'
          ]
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
      {
        name: 'allow_misubnet_outbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRange: '*'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: sqlMiSubnetAddressSpace
          sourcePortRange: '*'
        }
      }
    ]
  }
}

// Update VM subnet with NSG
resource vmSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spokeVnet
  name: 'snet-vm-${workloadName}-${environment}-${location}'
  properties: {
    addressPrefix: vmSubnetAddressSpace
    networkSecurityGroup: {
      id: vmNsg.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Update Private Endpoint subnet with NSG
resource pepSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spokeVnet
  name: 'snet-pep-${workloadName}-${environment}-${location}'
  properties: {
    addressPrefix: privateEndpointSubnetAddressSpace
    networkSecurityGroup: {
      id: pepNsg.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    vmSubnetUpdate
  ]
}

// Update SQL MI subnet with NSG and delegation
resource sqlMiSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spokeVnet
  name: 'snet-sqlmi-${workloadName}-${environment}-${location}'
  properties: {
    addressPrefix: sqlMiSubnetAddressSpace
    networkSecurityGroup: {
      id: sqlMiNsg.id
    }
    delegations: [
      {
        name: 'sqlMiDelegation'
        properties: {
          serviceName: 'Microsoft.Sql/managedInstances'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    pepSubnetUpdate
  ]
}

// Outputs
output spokeVnetId string = spokeVnet.id
output spokeVnetName string = spokeVnet.name
output vmSubnetId string = vmSubnetUpdate.id
output privateEndpointSubnetId string = pepSubnetUpdate.id
output sqlMiSubnetId string = sqlMiSubnetUpdate.id
output vmNsgId string = vmNsg.id
output pepNsgId string = pepNsg.id
output sqlMiNsgId string = sqlMiNsg.id
