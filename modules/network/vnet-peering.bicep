// VNet Peering Module
// Creates bidirectional peering between hub and spoke VNets

@description('Hub VNet resource ID')
param hubVnetId string

@description('Spoke VNet resource ID')
param spokeVnetId string

@description('Hub VNet name')
param hubVnetName string

@description('Spoke VNet name')
param spokeVnetName string

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

// Hub to Spoke Peering
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${hubVnetName}/peer-hub-to-spoke-${workloadName}-${environment}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnetId
    }
  }
}

// Spoke to Hub Peering
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${spokeVnetName}/peer-spoke-to-hub-${workloadName}-${environment}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnetId
    }
  }
}

// Outputs
output hubToSpokePeeringId string = hubToSpokePeering.id
output spokeToHubPeeringId string = spokeToHubPeering.id
