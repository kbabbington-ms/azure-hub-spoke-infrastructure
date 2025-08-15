#Requires -Version 5.1
<#
.SYNOPSIS
    Deploys the bootstrap foundation for secure Azure infrastructure

.DESCRIPTION
    This script deploys the foundation components including:
    - User-Assigned Managed Identity
    - Key Vault with secure access
    - Secure credential generation and storage
    
    This must be run BEFORE deploying the main infrastructure.

.PARAMETER Environment
    The environment to deploy to (dev, test, prod)

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be deployed

.PARAMETER Location
    Azure region for deployment (default: centralus)

.PARAMETER KeyVaultAdminObjectId
    Object ID of user/service principal to grant Key Vault access

.EXAMPLE
    .\deploy-foundations.ps1 -Environment dev -SubscriptionId "your-sub-id" -KeyVaultAdminObjectId "your-object-id"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'centralus',

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultAdminObjectId
)

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Variables
$workloadName = 'platform-ops'
$resourceGroupName = "rg-$workloadName-$Environment-$($Location.Substring(0,3))"
$deploymentName = "deploy-foundations-$Environment-$(Get-Date -Format 'yyyyMMddHHmmss')"
$parametersFile = "parameters/foundations.parameters.$Environment.json"

try {
    Write-Host "🚀 Starting Bootstrap Foundation Deployment" -ForegroundColor Green
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan
    Write-Host "Resource Group: $resourceGroupName" -ForegroundColor Cyan

    # Set Azure subscription context
    Write-Host "📋 Setting Azure subscription context..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) { throw "Failed to set subscription context" }

    # Create resource group if it doesn't exist
    Write-Host "🏗️ Ensuring resource group exists..." -ForegroundColor Yellow
    $rgExists = az group exists --name $resourceGroupName --output tsv
    if ($rgExists -eq 'false') {
        Write-Host "Creating resource group: $resourceGroupName" -ForegroundColor Yellow
        az group create --name $resourceGroupName --location $Location --tags Environment=$Environment Workload=$workloadName
        if ($LASTEXITCODE -ne 0) { throw "Failed to create resource group" }
    } else {
        Write-Host "Resource group already exists: $resourceGroupName" -ForegroundColor Green
    }

    # Check if parameter file exists
    if (-not (Test-Path $parametersFile)) {
        throw "Parameter file not found: $parametersFile"
    }

    # Validate the foundation template
    Write-Host "✅ Validating foundation template..." -ForegroundColor Yellow
    az deployment group validate `
        --resource-group $resourceGroupName `
        --template-file "foundations.bicep" `
        --parameters "@$parametersFile" `
        --parameters keyVaultAdminObjectId=$KeyVaultAdminObjectId location=$Location
    if ($LASTEXITCODE -ne 0) { throw "Template validation failed" }

    Write-Host "✅ Template validation successful!" -ForegroundColor Green

    # Deploy the foundation
    Write-Host "🚀 Deploying foundation infrastructure..." -ForegroundColor Yellow
    $deploymentResult = az deployment group create `
        --resource-group $resourceGroupName `
        --name $deploymentName `
        --template-file "foundations.bicep" `
        --parameters "@$parametersFile" `
        --parameters keyVaultAdminObjectId=$KeyVaultAdminObjectId location=$Location `
        --output json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) { throw "Foundation deployment failed" }

    # Extract outputs
    $keyVaultName = $deploymentResult.properties.outputs.keyVaultName.value
    $keyVaultId = $deploymentResult.properties.outputs.keyVaultId.value
    $secretStatus = $deploymentResult.properties.outputs.secretGenerationStatus.value

    Write-Host "🎉 Foundation deployment completed successfully!" -ForegroundColor Green
    Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "  • Deployment Name: $deploymentName" -ForegroundColor White
    Write-Host "  • Key Vault Name: $keyVaultName" -ForegroundColor White
    Write-Host "  • Key Vault ID: $keyVaultId" -ForegroundColor White
    Write-Host "  • Secret Generation: $secretStatus" -ForegroundColor White

    # Update parameter files with the actual Key Vault ID
    Write-Host "🔧 Updating parameter files with Key Vault references..." -ForegroundColor Yellow
    
    $mainParamFile = "parameters/main.parameters.$Environment.json"
    if (Test-Path $mainParamFile) {
        $paramContent = Get-Content $mainParamFile -Raw | ConvertFrom-Json
        
        # Update Key Vault references
        if ($paramContent.parameters.vmAdminPassword.reference) {
            $paramContent.parameters.vmAdminPassword.reference.keyVault.id = $keyVaultId
        }
        if ($paramContent.parameters.sqlAdminPassword.reference) {
            $paramContent.parameters.sqlAdminPassword.reference.keyVault.id = $keyVaultId
        }
        
        # Save updated parameters
        $paramContent | ConvertTo-Json -Depth 10 | Set-Content $mainParamFile
        Write-Host "✅ Updated $mainParamFile with Key Vault ID" -ForegroundColor Green
    }

    Write-Host "🔐 Foundation Setup Complete!" -ForegroundColor Green
    Write-Host "Next step: Run deploy-infrastructure.ps1 to deploy the main infrastructure" -ForegroundColor Cyan

} catch {
    Write-Error "❌ Foundation deployment failed: $($_.Exception.Message)"
    exit 1
}
