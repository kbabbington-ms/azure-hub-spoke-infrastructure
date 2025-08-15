// SQL Managed Instance Module
// Creates SQL Managed Instance with private endpoint

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
param environment string

@description('The workload name')
param workloadName string

@description('SQL MI subnet resource ID')
param sqlMiSubnetId string

@description('Private endpoint subnet resource ID')
param privateEndpointSubnetId string

@description('Spoke VNet resource ID for private DNS zone')
param spokeVnetId string

@description('SQL MI administrator login')
param sqlAdminLogin string = 'sqladmin'

@description('SQL MI administrator password')
@secure()
param sqlAdminPassword string

@description('Key Vault resource ID for storing SQL admin password')
param keyVaultId string

@description('Tags to apply to resources')
param tags object = {}

// SQL Managed Instance
resource sqlManagedInstance 'Microsoft.Sql/managedInstances@2023-08-01-preview' = {
  name: 'sqlmi-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 4
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    subnetId: sqlMiSubnetId
    licenseType: 'LicenseIncluded'
    vCores: 4
    storageSizeInGB: 32
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    publicDataEndpointEnabled: false
    timezoneId: 'Central Standard Time'
    maintenanceConfigurationId: subscriptionResourceId('Microsoft.Maintenance/publicMaintenanceConfigurations', 'SQL_Default')
    minimalTlsVersion: '1.2'
  }
}

// Private DNS Zone for SQL MI
resource sqlMiPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${az.environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
}

// Link Private DNS Zone to Spoke VNet
resource sqlMiPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlMiPrivateDnsZone
  name: 'link-to-${workloadName}-spoke-vnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

// Private Endpoint for SQL MI
resource sqlMiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pep-sqlmi-${workloadName}-${environment}-${location}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'sqlMiConnection'
        properties: {
          privateLinkServiceId: sqlManagedInstance.id
          groupIds: [
            'managedInstance'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for SQL MI Private Endpoint
resource sqlMiPrivateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  parent: sqlMiPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: sqlMiPrivateDnsZone.id
        }
      }
    ]
  }
}

// Store SQL admin password in Key Vault
resource sqlPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/sql-admin-password'
  properties: {
    value: sqlAdminPassword
    attributes: {
      enabled: true
    }
  }
}

// Outputs
output sqlManagedInstanceId string = sqlManagedInstance.id
output sqlManagedInstanceName string = sqlManagedInstance.name
output sqlManagedInstanceFqdn string = sqlManagedInstance.properties.fullyQualifiedDomainName
output sqlMiPrivateEndpointId string = sqlMiPrivateEndpoint.id
output sqlMiPrivateDnsZoneId string = sqlMiPrivateDnsZone.id
output sqlManagedInstanceSystemAssignedIdentityPrincipalId string = sqlManagedInstance.identity.principalId
