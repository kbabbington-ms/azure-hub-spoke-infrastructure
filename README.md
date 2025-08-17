# Azure Hub-Spoke Infrastructure with Bicep

A production-ready Azure infrastructure solution implementing a hub-spoke network topology with secure compute, database, and storage resources.

## 🏗️ Architecture Overview

This solution deploys a comprehensive Azure infrastructure following Microsoft's Cloud Adoption Framework and Well-Architected Framework principles:

### Network Architecture
- **Hub VNet**: Central connectivity point with Azure Bastion
- **Spoke VNet**: Workload-specific network with multiple subnets
- **VNet Peering**: Secure connectivity between hub and spoke
- **Private Endpoints**: Secure access to PaaS services

### Key Components
- **Azure Bastion**: Secure RDP/SSH access without public IPs
- **Windows Server VM**: Enterprise-ready with Azure extensions
- **Azure SQL Database**: Serverless database with private connectivity
- **Key Vault**: Centralized secrets management with private endpoint
- **Network Security Groups**: Micro-segmentation and traffic control

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and configured
- PowerShell 5.1 or later
- Azure subscription with appropriate permissions

### Deployment

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd azure-hub-spoke-infrastructure
   ```

2. **Configure parameters**
   - Update `parameters/main.parameters.dev.json` with your values
   - Set your Key Vault admin object ID
   - Adjust network address spaces if needed

3. **Deploy using PowerShell script**
   ```powershell
   .\scripts\deploy.ps1 -Environment dev -SubscriptionId "your-subscription-id" -KeyVaultAdminObjectId "your-object-id"
   ```

4. **Or deploy using Azure CLI**
   ```bash
   az deployment group create \
     --resource-group "rg-platform-ops-dev-cus" \
     --template-file "main.bicep" \
     --parameters "@parameters/main.parameters.dev.json"
   ```

## 📁 Project Structure

```
├── main.bicep                          # Main orchestration template
├── modules/
│   ├── bastion/
│   │   └── bastion.bicep              # Azure Bastion configuration
│   ├── compute/
│   │   └── virtual-machine.bicep      # VM with extensions
│   ├── database/
│   │   ├── sql-database.bicep         # Azure SQL Database
│   │   └── sql-managed-instance.bicep # Alternative SQL MI option
│   ├── network/
│   │   ├── hub-vnet.bicep            # Hub virtual network
│   │   ├── spoke-vnet.bicep          # Spoke virtual network
│   │   └── vnet-peering.bicep        # VNet peering configuration
│   └── security/
│       └── key-vault.bicep           # Key Vault with private endpoint
├── parameters/
│   ├── main.parameters.dev.json      # Development environment
│   ├── main.parameters.test.json     # Test environment
│   └── main.parameters.prod.json     # Production environment
├── scripts/
│   └── deploy.ps1                    # PowerShell deployment script
└── Documentation/
    ├── README.md                     # Documentation index
    ├── RELEASE-NOTES-v1.0.0.md       # Release notes and features
    ├── SECURITY-REMEDIATION-SUMMARY.md # Security improvements overview
    └── *.md                          # Additional analysis and security reports
```

## 🔧 Configuration

### Environment Parameters
Each environment has its own parameter file in the `parameters/` folder:

- **Development**: `main.parameters.dev.json`
- **Test**: `main.parameters.test.json`
- **Production**: `main.parameters.prod.json`

### Key Parameters
- `location`: Azure region for deployment
- `workloadName`: Used in resource naming
- `hubVnetAddressSpace`: CIDR for hub network
- `spokeVnetAddressSpace`: CIDR for spoke network
- `keyVaultAdminObjectId`: Your Azure AD object ID for Key Vault access

## 🛡️ Security Features

- **Network Isolation**: Private subnets with NSG rules
- **Private Endpoints**: Secure access to PaaS services
- **Azure Bastion**: Eliminates need for public IPs on VMs
- **Key Vault**: Centralized secrets management
- **Azure AD Integration**: VM login with Azure AD credentials
- **Security Extensions**: Antimalware and monitoring agents

## 🌐 Network Design

### Hub VNet (10.1.0.0/24)
- **AzureBastionSubnet**: 10.1.0.0/26 (Bastion service)

### Spoke VNet (10.2.0.0/24)
- **VM Subnet**: 10.2.0.0/26 (Virtual machines)
- **Private Endpoint Subnet**: 10.2.0.64/26 (PaaS services)
- **SQL MI Subnet**: 10.2.0.128/27 (Reserved for SQL MI if needed)

## 🔄 Deployment Options

### SQL Database vs SQL Managed Instance
This template includes both options:
- **SQL Database** (default): Faster deployment, better for most workloads
- **SQL Managed Instance**: Enterprise features, longer deployment time

Switch by modifying the main.bicep template to use the appropriate module.

## 📊 Monitoring and Compliance

- **Azure Monitor**: VM monitoring with Windows Agent
- **Azure Policy**: Compliance monitoring
- **Diagnostic Settings**: Centralized logging
- **Security Extensions**: Threat protection

## 🎯 Use Cases

Perfect for:
- **Development/Test Environments**: Isolated, secure infrastructure
- **Small to Medium Workloads**: Cost-effective enterprise features
- **Hub-Spoke Architecture**: Centralized connectivity and security
- **Private Cloud**: Minimal internet exposure
- **Platform Engineering**: Reusable infrastructure patterns

## � Version History

### v1.0.0-working-basic (Current)
- ✅ Complete hub-spoke network topology with VNet peering
- ✅ Azure Bastion for secure remote access without public IPs
- ✅ Windows Server VM with Azure extensions (Monitor, Policy, Antimalware, AAD Login)
- ✅ Azure SQL Database with private endpoint connectivity
- ✅ Key Vault with private endpoint and RBAC integration
- ✅ PowerShell deployment automation and multi-environment support
- ✅ Successfully tested and deployed in Central US region
- ⚠️ **Security Note**: Uses plaintext passwords in dev/test parameter files

### 🔄 Upcoming v1.1.0-secure
- 🚀 Bootstrap pattern for secure credential management
- 🔐 Key Vault-based password generation and storage
- 🔄 CI/CD-ready deployment process with Azure DevOps integration
- 🛡️ Enhanced security best practices

## �🔍 Troubleshooting

### Common Issues
1. **SQL MI Quota**: Switch to SQL Database if MI quota unavailable
2. **VM Name Length**: Computer name limited to 15 characters
3. **Region Capacity**: Try different Azure regions if deployment fails

### Validation
```bash
# Validate template before deployment
az deployment group validate \
  --resource-group "your-rg" \
  --template-file "main.bicep" \
  --parameters "@parameters/main.parameters.dev.json"
```

## 📚 Documentation

For detailed documentation about security analysis, remediation activities, and release notes, see the **[Documentation/](./Documentation/)** folder:

- **[Release Notes](./Documentation/RELEASE-NOTES-v1.0.0.md)** - Complete v1.0.0 features and deployment guide
- **[Security Summary](./Documentation/SECURITY-REMEDIATION-SUMMARY.md)** - Overview of security improvements
- **[Documentation Index](./Documentation/README.md)** - Complete documentation navigation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test the deployment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Microsoft Azure Architecture Center
- Azure Bicep team
- Cloud Adoption Framework
- Well-Architected Framework

---

**Note**: This infrastructure was successfully deployed and tested in the Central US region. Adjust parameters according to your specific requirements and compliance needs.
