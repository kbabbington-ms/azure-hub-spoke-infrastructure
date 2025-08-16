// Foundation Bootstrap Template
// Deploys managed identity, Key Vault, and generates secure credentials

targetScope = 'resourceGroup'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Workload name for resource naming')
param workloadName string

@description('Object ID of the user/service principal to grant Key Vault access (GUID format)')
param keyVaultAdminObjectId string = ''

@description('Common resource tags')
param tags object = {}

// Variables for resource naming
var resourceToken = uniqueString(resourceGroup().id)
var keyVaultName = 'kv-${take(resourceToken, 11)}'
var managedIdentityName = 'mi-${workloadName}-${environment}-${location}'
var deploymentScriptName = 'ds-generate-secrets-${environment}'

// User-Assigned Managed Identity for deployment scripts
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// Key Vault for storing generated secrets
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
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled' // Required for deployment scripts
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Key Vault Administrator role for the managed identity
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentity.id, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Administrator role for the admin user (if provided)
resource keyVaultUserAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(keyVaultAdminObjectId)) {
  name: guid(keyVault.id, keyVaultAdminObjectId, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: keyVaultAdminObjectId
    principalType: 'User'
  }
}

// RBAC propagation delay to ensure permissions are active
resource roleAssignmentDelay 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'ds-rbac-delay-${environment}'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      Write-Output "Waiting for RBAC permissions to propagate..."
      Start-Sleep -Seconds 60
      Write-Output "RBAC propagation delay completed"
    '''
  }
  dependsOn: [
    keyVaultAdminRoleAssignment
  ]
}

// Deployment script to generate and store secure credentials
resource secretGenerationScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: deploymentScriptName
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      param(
        [string]$KeyVaultName,
        [string]$Environment
      )
      
      Write-Output "Starting secure credential generation for environment: $Environment"
      
      # Function to generate secure password
      function New-SecurePassword {
        param([int]$Length = 20)
        
        # Character sets for password complexity
        $upperCase = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        $lowerCase = "abcdefghijkmnpqrstuvwxyz"
        $numbers = "23456789"
        $specialChars = "!@#$%^&*"
        
        # Ensure at least one character from each set
        $password = @()
        $password += $upperCase[(Get-Random -Maximum $upperCase.Length)]
        $password += $lowerCase[(Get-Random -Maximum $lowerCase.Length)]
        $password += $numbers[(Get-Random -Maximum $numbers.Length)]
        $password += $specialChars[(Get-Random -Maximum $specialChars.Length)]
        
        # Fill remaining length with random characters from all sets
        $allChars = $upperCase + $lowerCase + $numbers + $specialChars
        for ($i = $password.Count; $i -lt $Length; $i++) {
          $password += $allChars[(Get-Random -Maximum $allChars.Length)]
        }
        
        # Shuffle the password array and join
        $shuffled = $password | Sort-Object { Get-Random }
        return ($shuffled -join "")
      }
      
      try {
        # Generate secure passwords
        $vmPassword = New-SecurePassword -Length 20
        $sqlPassword = New-SecurePassword -Length 20
        
        Write-Output "Generated secure credentials successfully"
        
        # Convert to SecureString for Key Vault
        $vmSecurePassword = ConvertTo-SecureString -String $vmPassword -AsPlainText -Force
        $sqlSecurePassword = ConvertTo-SecureString -String $sqlPassword -AsPlainText -Force
        
        # Store secrets in Key Vault
        Write-Output "Storing VM admin password in Key Vault..."
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "vm-admin-password" -SecretValue $vmSecurePassword
        
        Write-Output "Storing SQL admin password in Key Vault..."
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "sql-admin-password" -SecretValue $sqlSecurePassword
        
        Write-Output "All credentials generated and stored successfully in Key Vault: $KeyVaultName"
        
        # Output summary for deployment logs
        $result = @{
          KeyVaultName = $KeyVaultName
          SecretsGenerated = @("vm-admin-password", "sql-admin-password")
          Environment = $Environment
          Status = "Success"
        }
        
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['result'] = $result
        
      } catch {
        Write-Error "Failed to generate or store credentials: $($_.Exception.Message)"
        throw
      }
    '''
    arguments: '-KeyVaultName "${keyVault.name}" -Environment "${environment}"'
  }
  dependsOn: [
    roleAssignmentDelay
  ]
}

// Outputs
output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id
output managedIdentityId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output secretGenerationStatus string = 'Completed'
output resourceToken string = resourceToken
