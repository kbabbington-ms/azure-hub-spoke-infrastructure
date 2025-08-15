#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys the main Azure infrastructure using secure credentials

.DESCRIPTION
    This script deploys the main infrastructure components:
    - Virtual Networks (Hub and Spoke)
    - Azure Bastion
    - Virtual Machine with extensions
    - Azure SQL Database
    - Key Vault integration
    
    Prerequisites: Must run deploy-foundations.ps1 first!

.PARAMETER Environment
    The environment to deploy to (dev, test, prod)

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be deployed

.PARAMETER Location
    Azure region for deployment (default: centralus)

.EXAMPLE
    .\deploy-infrastructure.ps1 -Environment dev -SubscriptionId "your-sub-id"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'centralus'
)

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Variables
$workloadName = 'platform-ops'
$resourceGroupName = "rg-$workloadName-$Environment-$($Location.Substring(0,3))"
$deploymentName = "deploy-infrastructure-$Environment-$(Get-Date -Format 'yyyyMMddHHmmss')"
$parametersFile = "parameters/main.parameters.$Environment.json"

try {
    Write-Host "🚀 Starting Infrastructure Deployment" -ForegroundColor Green
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan
    Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Cyan

    # Set Azure subscription context
    Write-Host "📋 Setting Azure subscription context..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription context" }

    # Verify resource group exists
    Write-Host "🔍 Verifying resource group exists..." -ForegroundColor Yellow
    $rgExists = az group exists --name $resourceGroupName --output tsv
    if ($rgExists -eq 'false') {
        throw "Resource group $resourceGroupName does not exist. Run deploy-foundations.ps1 first!"
    }

    # Check if parameter file exists
    if (-not (Test-Path $parametersFile)) {
        throw "Parameter file not found: $parametersFile"
    }

    # Verify Key Vault and secrets exist
    Write-Host "🔐 Verifying foundation setup..." -ForegroundColor Yellow
    $paramContent = Get-Content $parametersFile -Raw | ConvertFrom-Json
    
    if ($paramContent.parameters.vmAdminPassword.reference) {
        $keyVaultId = $paramContent.parameters.vmAdminPassword.reference.keyVault.id
        $keyVaultName = $keyVaultId.Split('/')[-1]
        
        # Check if Key Vault exists
        $kvExists = az keyvault show --name $keyVaultName --query "name" --output tsv 2>$null
        if (-not $kvExists) {
            throw "Key Vault $keyVaultName not found. Run deploy-foundations.ps1 first!"
        }
        
        # Check if secrets exist
        $vmSecret = az keyvault secret show --vault-name $keyVaultName --name "vm-admin-password" --query "name" --output tsv 2>$null
        $sqlSecret = az keyvault secret show --vault-name $keyVaultName --name "sql-admin-password" --query "name" --output tsv 2>$null
        
        if (-not $vmSecret -or -not $sqlSecret) {
            throw "Required secrets not found in Key Vault. Run deploy-foundations.ps1 first!"
        }
        
        Write-Host "✅ Foundation verification successful!" -ForegroundColor Green
    } else {
        throw "Parameter file does not contain Key Vault references. Run deploy-foundations.ps1 first!"
    }

    # Validate the infrastructure template
    Write-Host "✅ Validating infrastructure template..." -ForegroundColor Yellow
    az deployment group validate `
        --resource-group $resourceGroupName `
        --template-file "main.bicep" `
        --parameters "@$parametersFile"
    if ($LASTEXITCODE -ne 0) { throw "Template validation failed" }

    Write-Host "✅ Template validation successful!" -ForegroundColor Green

    # Deploy the infrastructure
    Write-Host "🚀 Deploying main infrastructure..." -ForegroundColor Yellow
    Write-Host "⏱️ This may take 15-30 minutes depending on the resources being deployed..." -ForegroundColor Yellow
    
    $deploymentResult = az deployment group create `
        --resource-group $resourceGroupName `
        --name $deploymentName `
        --template-file "main.bicep" `
        --parameters "@$parametersFile" `
        --output json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) { throw "Infrastructure deployment failed" }

    Write-Host "🎉 Infrastructure deployment completed successfully!" -ForegroundColor Green
    Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "  • Deployment Name: $deploymentName" -ForegroundColor White
    Write-Host "  • Resource Group: $resourceGroupName" -ForegroundColor White
    Write-Host "  • Environment: $Environment" -ForegroundColor White

    # Display deployed resources
    Write-Host "📦 Deployed Resources:" -ForegroundColor Cyan
    az resource list --resource-group $resourceGroupName --query "[].{Name:name, Type:type, Location:location}" --output table

    Write-Host "🔗 Next Steps:" -ForegroundColor Green
    Write-Host "  • Connect to VM via Azure Bastion in the Azure Portal" -ForegroundColor White
    Write-Host "  • Access SQL Database using private connectivity" -ForegroundColor White
    Write-Host "  • View all secrets in Key Vault: $keyVaultName" -ForegroundColor White

} catch {
    Write-Error "❌ Infrastructure deployment failed: $($_.Exception.Message)"
    
    # Show recent deployments for troubleshooting
    Write-Host "🔍 Recent deployments for troubleshooting:" -ForegroundColor Yellow
    az deployment group list --resource-group $resourceGroupName --query "[].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}" --output table
    
    exit 1
}
