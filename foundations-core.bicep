// Simplified foundations - just Key Vault without deployment scripts
targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Workload name for resource naming')
param workloadName string

@description('Object ID of the user/service principal to grant Key Vault access')
param keyVaultAdminObjectId string = ''

@description('Private endpoint subnet ID (optional - if not provided, Key Vault will be accessible only via private endpoint after manual configuration)')
param privateEndpointSubnetId string = ''

@description('Spoke VNet ID for private DNS zone linking (optional)')
param spokeVnetId string = ''

@description('Common resource tags')
param tags object = {}

// Variables
var resourceToken = uniqueString(resourceGroup().id)
var keyVaultName = 'kv-${take(resourceToken, 11)}'
var managedIdentityName = 'mi-${workloadName}-${environment}-${location}'

// User-Assigned Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
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
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Key Vault Administrator role for the managed identity
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentity.id, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Administrator role for the admin user (if provided)
resource keyVaultUserAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(keyVaultAdminObjectId)) {
  name: guid(keyVault.id, keyVaultAdminObjectId, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
    principalId: keyVaultAdminObjectId
    principalType: 'User'
  }
}

// Private DNS Zone for Key Vault (conditional)
resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(privateEndpointSubnetId)) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

// Private DNS Zone VNet Link (conditional)
resource keyVaultPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(privateEndpointSubnetId) && !empty(spokeVnetId)) {
  parent: keyVaultPrivateDnsZone
  name: 'vnet-link-${workloadName}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: spokeVnetId
    }
    registrationEnabled: false
  }
}

// Private Endpoint for Key Vault (conditional)
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = if (!empty(privateEndpointSubnetId)) {
  name: 'pep-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for Private Endpoint (conditional)
resource keyVaultPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (!empty(privateEndpointSubnetId)) {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output managedIdentityId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output keyVaultPrivateEndpointId string = !empty(privateEndpointSubnetId) ? keyVaultPrivateEndpoint.id : ''
