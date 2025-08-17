// Main Bicep Template
// Deploys complete Azure environment for Platform Engineering and Operations

targetScope = 'resourceGroup'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'prod'

@description('The workload name')
param workloadName string = 'platform-ops'

@description('Hub VNet address space')
param hubVnetAddressSpace string = '192.16.1.0/24'

@description('Spoke VNet address space')
param spokeVnetAddressSpace string = '192.16.2.0/24'

@description('VM admin username')
param vmAdminUsername string = 'azureadmin'

@description('VM admin password')
@secure()
param vmAdminPassword string

@description('SQL MI administrator login')
param sqlAdminLogin string = 'sqladmin'

@description('SQL MI administrator password')
@secure()
param sqlAdminPassword string

@description('Name of the existing Key Vault created by the foundation deployment')
param existingKeyVaultName string

@description('Resource ID of the existing Key Vault created by the foundation deployment')
param existingKeyVaultId string

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  Workload: workloadName
  'Created-By': 'Bicep'
  'Created-Date': utcNow('yyyy-MM-dd')
}

// Calculate subnet address spaces
var bastionSubnetAddressSpace = cidrSubnet(hubVnetAddressSpace, 26, 0) // 192.16.1.0/26
var vmSubnetAddressSpace = cidrSubnet(spokeVnetAddressSpace, 26, 0) // 192.16.2.0/26
var privateEndpointSubnetAddressSpace = cidrSubnet(spokeVnetAddressSpace, 28, 4) // 192.16.2.64/28
var sqlMiSubnetAddressSpace = cidrSubnet(spokeVnetAddressSpace, 27, 4) // 192.16.2.128/27

// Deploy Hub VNet
module hubVnet 'modules/network/hub-vnet.bicep' = {
  name: 'deploy-hub-vnet'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    hubVnetAddressSpace: hubVnetAddressSpace
    bastionSubnetAddressSpace: bastionSubnetAddressSpace
    tags: tags
  }
}

// Deploy Spoke VNet
module spokeVnet 'modules/network/spoke-vnet.bicep' = {
  name: 'deploy-spoke-vnet'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    spokeVnetAddressSpace: spokeVnetAddressSpace
    vmSubnetAddressSpace: vmSubnetAddressSpace
    privateEndpointSubnetAddressSpace: privateEndpointSubnetAddressSpace
    sqlMiSubnetAddressSpace: sqlMiSubnetAddressSpace
    tags: tags
  }
}

// Deploy VNet Peering
module vnetPeering 'modules/network/vnet-peering.bicep' = {
  name: 'deploy-vnet-peering'
  params: {
    hubVnetId: hubVnet.outputs.hubVnetId
    spokeVnetId: spokeVnet.outputs.spokeVnetId
    hubVnetName: hubVnet.outputs.hubVnetName
    spokeVnetName: spokeVnet.outputs.spokeVnetName
    environment: environment
    workloadName: workloadName
  }
}

// Reference existing Key Vault (deployed by foundation)
resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: existingKeyVaultName
}

// Deploy Virtual Machine
module virtualMachine 'modules/compute/virtual-machine.bicep' = {
  name: 'deploy-virtual-machine'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    vmSubnetId: spokeVnet.outputs.vmSubnetId
    keyVaultId: existingKeyVaultId
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    tags: tags
  }
}

// Deploy SQL Database
module sqlDatabase 'modules/database/sql-database.bicep' = {
  name: 'deploy-sql-database'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointSubnetId
    spokeVnetId: spokeVnet.outputs.spokeVnetId
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPassword: sqlAdminPassword
    keyVaultId: existingKeyVaultId
    tags: tags
  }
}

// Deploy Azure Bastion
module bastion 'modules/bastion/bastion.bicep' = {
  name: 'deploy-bastion'
  params: {
    location: location
    environment: environment
    workloadName: workloadName
    bastionSubnetId: hubVnet.outputs.bastionSubnetId
    tags: tags
  }
}

// Outputs
output hubVnetId string = hubVnet.outputs.hubVnetId
output spokeVnetId string = spokeVnet.outputs.spokeVnetId
output keyVaultName string = existingKeyVaultName
output keyVaultUri string = existingKeyVault.properties.vaultUri
output vmName string = virtualMachine.outputs.vmName
output vmPrivateIpAddress string = virtualMachine.outputs.vmPrivateIpAddress
output sqlServerName string = sqlDatabase.outputs.sqlServerName
output sqlServerFqdn string = sqlDatabase.outputs.sqlServerFqdn
output sqlDatabaseName string = sqlDatabase.outputs.sqlDatabaseName
output bastionHostName string = bastion.outputs.bastionHostName
output bastionPublicIpAddress string = bastion.outputs.bastionPublicIpAddress
