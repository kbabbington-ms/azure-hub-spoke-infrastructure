// Hub Virtual Network Module
// Creates the hub VNet with Bastion subnet

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('Hub VNet address space')
param hubVnetAddressSpace string = '10.1.0.0/24'

@description('Bastion subnet address space')
param bastionSubnetAddressSpace string = '10.1.0.0/26'

@description('Management subnet address space')
param managementSubnetAddressSpace string = '10.1.0.64/26'

@description('Tags to apply to resources')
param tags object = {}

// Hub Virtual Network
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-hub-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressSpace
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-management-${workloadName}-${environment}-${location}'
        properties: {
          addressPrefix: managementSubnetAddressSpace
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Network Security Group for Bastion Subnet
resource bastionNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-bastion-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 140
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 150
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformation'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Network Security Group for Management Subnet
resource managementNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-management-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowBastionInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '22'
            '3389'
            '5985'
            '5986'
          ]
          sourceAddressPrefix: bastionSubnetAddressSpace
          destinationAddressPrefix: managementSubnetAddressSpace
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowWinRMInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '5985'
            '5986'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: managementSubnetAddressSpace
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowWindowsAdminCenterInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: managementSubnetAddressSpace
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
          sourceAddressPrefix: managementSubnetAddressSpace
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowVnetOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: managementSubnetAddressSpace
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Update Bastion subnet with NSG
resource bastionSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: hubVnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetAddressSpace
    networkSecurityGroup: {
      id: bastionNsg.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

// Update Management subnet with NSG
resource managementSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: hubVnet
  name: 'snet-management-${workloadName}-${environment}-${location}'
  properties: {
    addressPrefix: managementSubnetAddressSpace
    networkSecurityGroup: {
      id: managementNsg.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    bastionSubnetUpdate
  ]
}

// Outputs
output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output bastionSubnetId string = bastionSubnetUpdate.id
output bastionNsgId string = bastionNsg.id
output managementSubnetId string = managementSubnetUpdate.id
output managementNsgId string = managementNsg.id
