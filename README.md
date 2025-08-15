# Azure Platform Engineering Environment

This repository contains Bicep templates and deployment scripts for creating a comprehensive Azure environment designed for Platform Engineering and Operations teams. The solution follows Microsoft Cloud Adoption Framework naming conventions and implements DevOps best practices with modular, reusable Bicep templates.

## Architecture Overview

The solution deploys a **hub-spoke network topology** with the following components:

### Network Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Resource Group                           │
│                rg-platform-ops-prod-scus                   │
├─────────────────────────────────────────────────────────────┤
│  Hub VNet (192.16.1.0/24)    │  Spoke VNet (192.16.2.0/24) │
│  ┌─────────────────────────┐  │  ┌─────────────────────────┐ │
│  │ AzureBastionSubnet      │  │  │ snet-vm (/26)          │ │
│  │ (/26 - minimum req)     │◄─┼──┤ - Windows VM           │ │
│  └─────────────────────────┘  │  │ - NSG                  │ │
│                               │  └─────────────────────────┘ │
│                               │  ┌─────────────────────────┐ │
│                               │  │ snet-pep (/28)         │ │
│                               │  │ - SQL MI Private EP    │ │
│                               │  │ - Key Vault Private EP │ │
│                               │  │ - Private DNS Zones    │ │
│                               │  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

- **Hub Virtual Network**: Contains Azure Bastion for secure remote access
- **Spoke Virtual Network**: Hosts compute workloads and private endpoints
- **Azure Bastion**: Provides secure RDP/SSH access without public IPs
- **Windows Server VM**: Latest Azure Edition with Entra ID join and extensions
- **SQL Managed Instance**: Private, managed database service
- **Key Vault**: Secure storage for secrets and certificates
- **Private Endpoints**: Secure connectivity to Azure PaaS services
- **Network Security Groups**: Layered security controls

## Prerequisites

- Azure CLI or Azure PowerShell
- Azure subscription with appropriate permissions
- Bicep CLI (latest version)
- PowerShell 7.0+ (for deployment scripts)

## Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd Simple Environment
```

### 2. Update Parameters
Edit the parameter files in the `parameters/` directory:
- `main.parameters.dev.json` - Development environment
- `main.parameters.test.json` - Test environment  
- `main.parameters.prod.json` - Production environment

**Important**: Update the following values:
- `keyVaultAdminObjectId`: Your Azure AD user/service principal object ID
- Subscription ID in Key Vault references (prod environment only)

### 3. Deploy Using PowerShell Script

**Development Environment:**
```powershell
.\scripts\deploy.ps1 -Environment dev -SubscriptionId "your-subscription-id" -KeyVaultAdminObjectId "your-object-id"
```

**Production Environment:**
```powershell
.\scripts\deploy.ps1 -Environment prod -SubscriptionId "your-subscription-id" -KeyVaultAdminObjectId "your-object-id"
```

**What-If Analysis:**
```powershell
.\scripts\deploy.ps1 -Environment dev -SubscriptionId "your-subscription-id" -KeyVaultAdminObjectId "your-object-id" -WhatIf
```

### 4. Deploy Using Azure CLI

```bash
# Create resource group
az group create --name rg-platform-ops-dev-scus --location southcentralus

# Deploy template
az deployment group create \
  --resource-group rg-platform-ops-dev-scus \
  --template-file main.bicep \
  --parameters @parameters/main.parameters.dev.json \
  --parameters keyVaultAdminObjectId="your-object-id"
```

## Directory Structure

```
├── main.bicep                          # Main deployment template
├── modules/                            # Reusable Bicep modules
│   ├── network/
│   │   ├── hub-vnet.bicep             # Hub virtual network
│   │   ├── spoke-vnet.bicep           # Spoke virtual network
│   │   └── vnet-peering.bicep         # VNet peering
│   ├── bastion/
│   │   └── bastion.bicep              # Azure Bastion
│   ├── compute/
│   │   └── virtual-machine.bicep      # Windows Server VM
│   ├── database/
│   │   └── sql-managed-instance.bicep # SQL Managed Instance
│   └── security/
│       └── key-vault.bicep            # Key Vault with private endpoint
├── parameters/                         # Environment-specific parameters
│   ├── main.parameters.dev.json
│   ├── main.parameters.test.json
│   └── main.parameters.prod.json
├── scripts/
│   └── deploy.ps1                     # PowerShell deployment script
└── README.md                          # This file
```

## Resource Naming Convention

Following Microsoft Cloud Adoption Framework (CAF):

| Resource Type | Naming Pattern | Example |
|---------------|----------------|---------|
| Resource Group | `rg-{workload}-{environment}-{region}` | `rg-platform-ops-prod-scus` |
| Virtual Network | `vnet-{hub/spoke}-{workload}-{environment}-{region}` | `vnet-hub-platform-ops-prod-scus` |
| Subnet | `snet-{purpose}-{workload}-{environment}-{region}` | `snet-vm-platform-ops-prod-scus` |
| Virtual Machine | `vm-{workload}-{environment}-{instance}` | `vm-platform-ops-prod-001` |
| SQL MI | `sqlmi-{workload}-{environment}-{region}` | `sqlmi-platform-ops-prod-scus` |
| Key Vault | `kv-{workload}-{environment}-{uniquestring}` | `kv-platform-ops-prod-abc123` |
| Bastion | `bas-{workload}-{environment}-{region}` | `bas-platform-ops-prod-scus` |

## Security Features

### Network Security
- Private endpoints for SQL MI and Key Vault
- Network Security Groups with least privilege rules
- No public IP addresses on VMs
- Hub-spoke network isolation

### Identity & Access Management
- Azure RBAC for Key Vault (recommended over access policies)
- Entra ID (Azure AD) joined VMs
- Managed identities where applicable
- Principle of least privilege

### Data Protection
- SQL MI with private endpoint only
- Key Vault for secure secret storage
- Encrypted storage accounts
- TLS 1.2 minimum encryption

## VM Extensions Included

- **Azure Monitor Agent**: Enhanced monitoring and logging
- **Microsoft Antimalware**: Real-time protection
- **AAD Login Extension**: Entra ID authentication
- **Custom Script Extension**: Post-deployment configuration

## Monitoring & Operations

- Boot diagnostics enabled with managed storage
- Azure Monitor Agent for telemetry collection
- Centralized secret management via Key Vault
- Automated backup capabilities (configurable)

## Environment Differences

| Feature | Dev | Test | Prod |
|---------|-----|------|------|
| Network Range | 10.1.x.x/10.2.x.x | 10.11.x.x/10.12.x.x | 192.16.1.x/192.16.2.x |
| Password Management | Generated | Generated | Key Vault Reference |
| SQL MI Backup | 7 days | 7 days | 35 days |
| VM SKU | Standard_D4s_v5 | Standard_D4s_v5 | Standard_D4s_v5 |

## Troubleshooting

### Common Issues

1. **Key Vault Access**: Ensure the `keyVaultAdminObjectId` parameter contains your correct Azure AD object ID
2. **Deployment Timeout**: SQL MI deployment can take 4-6 hours - this is expected
3. **Network Conflicts**: Verify VNet address spaces don't overlap with existing networks
4. **Permissions**: Ensure you have Contributor access to the target subscription

### Validation Commands

```bash
# Validate Bicep template
az deployment group validate \
  --resource-group rg-platform-ops-dev-scus \
  --template-file main.bicep \
  --parameters @parameters/main.parameters.dev.json

# Check deployment status
az deployment group show \
  --resource-group rg-platform-ops-dev-scus \
  --name deploy-platform-ops-dev-20240815120000
```

## Contributing

1. Follow the existing naming conventions
2. Update documentation for any new modules
3. Test deployments in dev environment first
4. Ensure Bicep templates pass linting (`bicep build`)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review Azure documentation for specific services
3. Open an issue in this repository with deployment logs
