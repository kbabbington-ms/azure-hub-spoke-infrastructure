# Upload content to Azure Static Web App
# This script uploads the sample application to the Static Web App

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$StaticWebAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$SourcePath
)

Write-Host "Uploading content to Static Web App: $StaticWebAppName" -ForegroundColor Green

# Get the deployment token
Write-Host "Getting deployment token..." -ForegroundColor Yellow
$token = az staticwebapp secrets list --name $StaticWebAppName --resource-group $ResourceGroupName --query "properties.apiKey" --output tsv

if ([string]::IsNullOrEmpty($token)) {
    Write-Error "Failed to get deployment token"
    exit 1
}

Write-Host "Token retrieved successfully" -ForegroundColor Green

# Install SWA CLI if not available
Write-Host "Checking SWA CLI..." -ForegroundColor Yellow
try {
    $swaVersion = swa --version 2>$null
    if ([string]::IsNullOrEmpty($swaVersion)) {
        Write-Host "Installing SWA CLI..." -ForegroundColor Yellow
        npm install -g @azure/static-web-apps-cli
    }
} catch {
    Write-Host "Installing SWA CLI..." -ForegroundColor Yellow
    npm install -g @azure/static-web-apps-cli
}

# Deploy the content
Write-Host "Deploying content from: $SourcePath" -ForegroundColor Yellow
Push-Location $SourcePath
try {
    swa deploy . --deployment-token $token --verbose
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
} catch {
    Write-Error "Deployment failed: $_"
} finally {
    Pop-Location
}
