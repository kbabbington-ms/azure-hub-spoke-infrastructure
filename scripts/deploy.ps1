#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Deploy Azure Platform Engineering Environment using Bicep

.DESCRIPTION
    This script deploys the complete Azure environment for Platform Engineering and Operations
    using modular Bicep templates. It supports deployment to dev, test, and prod environments.

.PARAMETER Environment
    The target environment (dev, test, prod)

.PARAMETER Location
    The Azure region for deployment (default: southcentralus)

.PARAMETER ResourceGroupName
    The name of the resource group (auto-generated if not provided)

.PARAMETER SubscriptionId
    The Azure subscription ID

.PARAMETER KeyVaultAdminObjectId
    The object ID of the user/service principal to grant Key Vault access

.PARAMETER VmAdminPassword
    The VM administrator password (only for dev/test environments)

.PARAMETER SqlAdminPassword
    The SQL administrator password (only for dev/test environments)

.PARAMETER WhatIf
    Perform a what-if deployment to preview changes

.EXAMPLE
    .\deploy.ps1 -Environment dev -SubscriptionId "12345678-1234-1234-1234-123456789012" -KeyVaultAdminObjectId "87654321-4321-4321-4321-210987654321"

.EXAMPLE
    .\deploy.ps1 -Environment prod -SubscriptionId "12345678-1234-1234-1234-123456789012" -KeyVaultAdminObjectId "87654321-4321-4321-4321-210987654321" -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'southcentralus',

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$KeyVaultAdminObjectId,

    [Parameter(Mandatory = $false)]
    [SecureString]$VmAdminPassword,

    [Parameter(Mandatory = $false)]
    [SecureString]$SqlAdminPassword,

    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Import required modules
Import-Module Az.Accounts -Force
Import-Module Az.Resources -Force

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to generate secure password
function New-SecurePassword {
    param(
        [int]$Length = 16
    )
    
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    $password = ''
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $chars[(Get-Random -Maximum $chars.Length)]
    }
    return ConvertTo-SecureString -String $password -AsPlainText -Force
}

try {
    Write-ColorOutput "=== Azure Platform Engineering Environment Deployment ===" -Color 'Cyan'
    Write-ColorOutput "Environment: $Environment" -Color 'Yellow'
    Write-ColorOutput "Location: $Location" -Color 'Yellow'
    
    # Set default resource group name if not provided
    if (-not $ResourceGroupName) {
        $LocationShort = switch ($Location) {
            'southcentralus' { 'scus' }
            'eastus' { 'eus' }
            'westus' { 'wus' }
            'westus2' { 'wus2' }
            'centralus' { 'cus' }
            default { $Location.Substring(0, [Math]::Min(4, $Location.Length)) }
        }
        $ResourceGroupName = "rg-platform-ops-$Environment-$LocationShort"
    }
    
    Write-ColorOutput "Resource Group: $ResourceGroupName" -Color 'Yellow'
    
    # Connect to Azure
    Write-ColorOutput "`nConnecting to Azure..." -Color 'Green'
    $Context = Get-AzContext
    if (-not $Context -or $Context.Subscription.Id -ne $SubscriptionId) {
        Connect-AzAccount -SubscriptionId $SubscriptionId
    } else {
        Write-ColorOutput "Already connected to subscription: $($Context.Subscription.Name)" -Color 'Green'
    }
    
    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    
    # Create resource group if it doesn't exist
    Write-ColorOutput "`nChecking resource group..." -Color 'Green'
    $ResourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $ResourceGroup) {
        Write-ColorOutput "Creating resource group: $ResourceGroupName" -Color 'Green'
        $ResourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-ColorOutput "Resource group created successfully" -Color 'Green'
    } else {
        Write-ColorOutput "Resource group already exists" -Color 'Green'
    }
    
    # Generate passwords for dev/test environments if not provided
    if ($Environment -in @('dev', 'test')) {
        if (-not $VmAdminPassword) {
            Write-ColorOutput "Generating VM admin password..." -Color 'Yellow'
            $VmAdminPassword = New-SecurePassword
        }
        if (-not $SqlAdminPassword) {
            Write-ColorOutput "Generating SQL admin password..." -Color 'Yellow'
            $SqlAdminPassword = New-SecurePassword
        }
    }
    
    # Prepare deployment parameters
    $DeploymentName = "deploy-platform-ops-$Environment-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $TemplateFile = Join-Path $PSScriptRoot "..\main.bicep"
    $ParametersFile = Join-Path $PSScriptRoot "..\parameters\main.parameters.$Environment.json"
    
    Write-ColorOutput "`nDeployment Details:" -Color 'Cyan'
    Write-ColorOutput "Template: $TemplateFile" -Color 'White'
    Write-ColorOutput "Parameters: $ParametersFile" -Color 'White'
    Write-ColorOutput "Deployment Name: $DeploymentName" -Color 'White'
    
    # Validate template and parameters files exist
    if (-not (Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }
    if (-not (Test-Path $ParametersFile)) {
        throw "Parameters file not found: $ParametersFile"
    }
    
    # Build deployment parameters
    $DeploymentParameters = @{
        keyVaultAdminObjectId = $KeyVaultAdminObjectId
    }
    
    # Add passwords for dev/test environments
    if ($Environment -in @('dev', 'test')) {
        $DeploymentParameters.vmAdminPassword = $VmAdminPassword
        $DeploymentParameters.sqlAdminPassword = $SqlAdminPassword
    }
    
    # Perform what-if analysis if requested
    if ($WhatIf) {
        Write-ColorOutput "`nPerforming what-if analysis..." -Color 'Magenta'
        $WhatIfResult = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParametersFile `
            -WhatIf `
            @DeploymentParameters
        
        Write-ColorOutput "`nWhat-if analysis completed" -Color 'Magenta'
        return
    }
    
    # Validate deployment
    Write-ColorOutput "`nValidating deployment..." -Color 'Green'
    $ValidationResult = Test-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        @DeploymentParameters
    
    if ($ValidationResult) {
        Write-ColorOutput "Validation failed:" -Color 'Red'
        $ValidationResult | ForEach-Object {
            Write-ColorOutput "  $($_.Message)" -Color 'Red'
        }
        throw "Template validation failed"
    }
    
    Write-ColorOutput "Validation passed successfully" -Color 'Green'
    
    # Deploy template
    Write-ColorOutput "`nStarting deployment..." -Color 'Green'
    $Deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -Name $DeploymentName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -Verbose `
        @DeploymentParameters
    
    if ($Deployment.ProvisioningState -eq 'Succeeded') {
        Write-ColorOutput "`n=== Deployment Completed Successfully ===" -Color 'Green'
        Write-ColorOutput "Deployment Name: $($Deployment.DeploymentName)" -Color 'White'
        Write-ColorOutput "Duration: $($Deployment.Duration)" -Color 'White'
        
        Write-ColorOutput "`nDeployment Outputs:" -Color 'Cyan'
        $Deployment.Outputs.Keys | ForEach-Object {
            $outputValue = $Deployment.Outputs[$_].Value
            Write-ColorOutput "  $_`: $outputValue" -Color 'White'
        }
        
        Write-ColorOutput "`nNext Steps:" -Color 'Yellow'
        Write-ColorOutput "1. Connect to the VM using Azure Bastion" -Color 'White'
        Write-ColorOutput "2. Access SQL Managed Instance using private endpoint" -Color 'White'
        Write-ColorOutput "3. Configure RBAC assignments as needed" -Color 'White'
        Write-ColorOutput "4. Set up monitoring and alerting" -Color 'White'
        
    } else {
        Write-ColorOutput "`nDeployment failed with state: $($Deployment.ProvisioningState)" -Color 'Red'
        throw "Deployment failed"
    }
    
} catch {
    Write-ColorOutput "`nDeployment failed with error:" -Color 'Red'
    Write-ColorOutput $_.Exception.Message -Color 'Red'
    exit 1
}
