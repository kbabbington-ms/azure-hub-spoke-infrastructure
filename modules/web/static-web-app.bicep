// Azure Static Web App Module
// Creates a Static Web App with private endpoint integration

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('SKU for the Static Web App')
param skuName string = 'Standard'

@description('Repository URL for the static web app')
param repositoryUrl string = ''

@description('Repository branch')
param repositoryBranch string = 'main'

@description('App location in the repository')
param appLocation string = '/'

@description('API location in the repository')
param apiLocation string = ''

@description('Output location for built app')
param outputLocation string = 'build'

@description('Hub VNet ID for private endpoint integration')
param hubVnetId string

@description('Management subnet ID for private endpoint')
param managementSubnetId string

@description('Tags to apply to resources')
param tags object = {}

// Variables
var staticWebAppFullName = 'swa-${workloadName}-${environment}-${location}'
var privateEndpointName = 'pe-${staticWebAppFullName}'
var privateDnsZoneName = 'privatelink.azurestaticapps.net'

// Static Web App
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppFullName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    buildProperties: {
      skipGithubActionWorkflowGeneration: true
      appLocation: appLocation
      apiLocation: apiLocation
      outputLocation: outputLocation
    }
    repositoryUrl: repositoryUrl
    branch: repositoryBranch
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// Private DNS Zone for Static Web Apps
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
  properties: {}
}

// Private DNS Zone Virtual Network Link
resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

// Network Security Group for Private Endpoint
resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-pe-${staticWebAppFullName}'
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
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowVnetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
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
          priority: 110
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Private Endpoint for Static Web App
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: managementSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'swa-private-link'
        properties: {
          privateLinkServiceId: staticWebApp.id
          groupIds: [
            'sites'
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            description: 'Private endpoint for Static Web App'
          }
        }
      }
    ]
    customNetworkInterfaceName: 'nic-${privateEndpointName}'
  }
}

// Private DNS Zone Group for Private Endpoint
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// Custom domain for Static Web App (optional)
resource staticWebAppCustomDomain 'Microsoft.Web/staticSites/customDomains@2023-01-01' = if (!empty(repositoryUrl)) {
  parent: staticWebApp
  name: '${workloadName}-${environment}.example.com'
  properties: {
    validationMethod: 'dns-txt-token'
  }
}

// Outputs
output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output staticWebAppDefaultHostname string = staticWebApp.properties.defaultHostname
output staticWebAppCustomDomains array = staticWebApp.properties.customDomains
output repositoryUrl string = staticWebApp.properties.repositoryUrl
output branch string = staticWebApp.properties.branch
output privateEndpointId string = privateEndpoint.id
output privateDnsZoneId string = privateDnsZone.id
output privateIpAddress string = privateEndpoint.properties.networkInterfaces[0].properties.ipConfigurations[0].properties.privateIPAddress
