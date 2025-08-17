@description('Updates the existing Key Vault to be secure with private endpoint')
param location string = resourceGroup().location

@description('Environment name')
param environment string

@description('Workload name')  
param workloadName string

@description('Existing Key Vault name to secure')
param existingKeyVaultName string

@description('Private endpoint subnet ID')
param privateEndpointSubnetId string

@description('Spoke VNet ID for private DNS zone linking')
param spokeVnetId string

@description('Common resource tags')
param tags object = {}

// Reference the existing Key Vault
resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: existingKeyVaultName
}

// Update Key Vault to disable public access
resource secureKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: existingKeyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableSoftDelete: true
    enablePurgeProtection: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Disabled'  // Secure: Disable public access
    networkAcls: {
      defaultAction: 'Deny'          // Secure: Deny by default
      bypass: 'AzureServices'
    }
  }
}

// Create Private DNS Zone for Key Vault
resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${az.environment().suffixes.keyvaultDns}'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to Spoke VNet
resource kvPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: kvPrivateDnsZone
  name: 'link-to-${workloadName}-spoke-vnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

// Create Private Endpoint for Key Vault
resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pep-kv-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyVaultConnection'
        properties: {
          privateLinkServiceId: existingKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
  dependsOn: [
    secureKeyVault
  ]
}

// Configure Private DNS Zone Group for Private Endpoint
resource kvPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: kvPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vault-azure-net'
        properties: {
          privateDnsZoneId: kvPrivateDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output keyVaultId string = secureKeyVault.id
output keyVaultName string = secureKeyVault.name
output keyVaultUri string = secureKeyVault.properties.vaultUri
output privateEndpointId string = kvPrivateEndpoint.id
output privateDnsZoneId string = kvPrivateDnsZone.id
