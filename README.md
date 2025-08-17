# Azure Hub-Spoke Infrastructure

[![Azure](https://img.shields.io/badge/Azure-Cloud-blue?logo=microsoft-azure)](https://azure.microsoft.com/)
[![Bicep](https://img.shields.io/badge/Infrastructure-Bicep-orange?logo=azure-devops)](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0.0-green)](./Documentation/RELEASE-NOTES-v1.0.0.md)

A **production-ready**, **security-hardened** Azure infrastructure solution implementing a hub-spoke network topology with comprehensive security features, private connectivity, and enterprise-grade compliance.

## 🎯 What This Solution Provides

### 🏗️ **Complete Hub-Spoke Architecture**
- **Hub VNet** (10.1.0.0/24): Centralized connectivity with Azure Bastion
- **Spoke VNet** (10.2.0.0/24): Workload-specific network with micro-segmentation
- **Bidirectional VNet Peering**: Secure, high-performance connectivity
- **Zero Public IPs**: Fully private infrastructure with Bastion-only access

### 🛡️ **Security by Default**
- **Private Endpoints**: All PaaS services secured with private connectivity
- **Network Security Groups**: Hardened with specific protocol enforcement (no wildcards)
- **Azure Key Vault**: RBAC-enabled with private endpoint integration
- **Azure AD Integration**: VM access without local accounts
- **Security Extensions**: Antimalware, monitoring, and compliance agents

### 🔧 **Enterprise Features**
- **Modular Design**: Reusable Bicep templates for any environment
- **Multi-Environment Support**: Dev, Test, Production parameter sets
- **Bootstrap Pattern**: Secure credential generation and management
- **Comprehensive Documentation**: Security analysis and deployment guides
- **Infrastructure as Code**: 100% declarative with no manual steps

## 🚀 Quick Start

### Prerequisites
- **Azure CLI** 2.50+ with Bicep extension
- **PowerShell** 5.1+ (Windows) or PowerShell Core (Cross-platform)
- **Azure Permissions**: Contributor + Key Vault Administrator roles
- **Resource Group**: Pre-created in your target region

### Option 1: One-Command Deployment
```powershell
# Clone and deploy complete infrastructure
git clone https://github.com/kbabbington-ms/azure-hub-spoke-infrastructure.git
cd azure-hub-spoke-infrastructure

# Update parameters/main.parameters.dev.json with your values
# Then deploy everything:
.\scripts\deploy.ps1 -Environment dev -SubscriptionId "your-subscription-id"
```

### Option 2: Step-by-Step Deployment
```bash
# 1. Deploy foundation (Key Vault + Managed Identity)
az deployment group create \
  --resource-group "rg-platform-ops-dev-centralus" \
  --template-file "foundations-core.bicep" \
  --parameters environment=dev workloadName=platform-ops

# 2. Deploy main infrastructure
az deployment group create \
  --resource-group "rg-platform-ops-dev-centralus" \
  --template-file "main.bicep" \
  --parameters "@parameters/main.parameters.dev.json"
```

## 📋 What Gets Deployed

### 🌐 **Network Infrastructure**
| Component | Purpose | Configuration |
|-----------|---------|---------------|
| Hub VNet | Central connectivity | 10.1.0.0/24 |
| Bastion Subnet | Secure remote access | 10.1.0.0/26 |
| Spoke VNet | Workload hosting | 10.2.0.0/24 |
| VM Subnet | Virtual machines | 10.2.0.0/26 |
| Private Endpoint Subnet | PaaS connectivity | 10.2.0.64/26 |
| VNet Peering | Hub-Spoke connectivity | Bidirectional |

### 💻 **Compute & Services**
| Service | Configuration | Security Features |
|---------|---------------|-------------------|
| Azure Bastion | Standard SKU | NSG hardened, no public IPs |
| Windows Server VM | Standard_B2ms | Azure AD login, security extensions |
| Azure SQL Database | Serverless, S0 | Private endpoint, RBAC |
| Azure Key Vault | Standard | Private endpoint, RBAC, audit logs |
| Storage Account | Standard_LRS | Private endpoint, encryption |

### 🔒 **Security Components**
- **Network Security Groups**: Hardened rules with TCP-specific protocols
- **Private DNS Zones**: Name resolution for private endpoints
- **Managed Identity**: Service-to-service authentication
- **RBAC Assignments**: Least privilege access controls
- **Azure Monitor**: Comprehensive logging and monitoring

## 📁 Repository Structure

```
📁 azure-hub-spoke-infrastructure/
├── 🔧 Core Templates
│   ├── foundations-core.bicep      # Bootstrap: Key Vault + Identity (Recommended)
│   ├── foundations.bicep           # Bootstrap: Full with credential generation
│   └── main.bicep                  # Main: Hub-Spoke infrastructure
│
├── 🧩 Modular Components
│   └── modules/
│       ├── bastion/                # Azure Bastion module
│       ├── compute/                # Virtual machine module
│       ├── database/               # SQL Database/MI modules
│       ├── network/                # VNet, NSG, peering modules
│       └── security/               # Key Vault module
│
├── ⚙️ Configuration
│   └── parameters/
│       ├── main.parameters.dev.json     # Development environment
│       ├── main.parameters.test.json    # Test environment
│       └── main.parameters.prod.json    # Production environment
│
├── 🤖 Automation
│   └── scripts/
│       ├── deploy.ps1                   # Main deployment script
│       ├── deploy-foundations.ps1       # Foundation-only deployment
│       └── deploy-infrastructure.ps1    # Infrastructure-only deployment
│
└── 📚 Documentation
    ├── README.md                        # Documentation index
    ├── RELEASE-NOTES-v1.0.0.md          # Current release features
    ├── SECURITY-REMEDIATION-SUMMARY.md  # Security improvements
    └── *.md                             # Analysis and security reports
```

## 🔧 Configuration Options

### Template Selection
| Template | Use Case | Features |
|----------|----------|----------|
| `foundations-core.bicep` | **Recommended** | Secure Key Vault, optional private endpoint |
| `foundations.bicep` | Advanced | Full bootstrap with credential generation |
| `main.bicep` | Infrastructure | Complete hub-spoke network and services |

### Environment Configuration
Each environment has dedicated parameter files:
- **Development**: Smaller VMs, basic SKUs, simplified security
- **Test**: Production-like setup, automated testing friendly
- **Production**: High availability, premium SKUs, full security

### Key Parameters
```json
{
  "location": "centralus",                    // Azure region
  "workloadName": "platform-ops",            // Resource naming prefix
  "environment": "dev",                       // Environment designation
  "hubVnetAddressSpace": "10.1.0.0/24",     // Hub network CIDR
  "spokeVnetAddressSpace": "10.2.0.0/24",   // Spoke network CIDR
  "keyVaultAdminObjectId": "your-object-id"  // Azure AD object ID
}
```

## 🛡️ Security Features

### 🔒 **Zero Trust Network**
- **No Public IPs**: All VMs accessible only through Bastion
- **Private Endpoints**: PaaS services isolated from internet
- **Micro-segmentation**: NSG rules limit traffic to required ports
- **Protocol Specificity**: All rules use TCP/UDP (no wildcards)

### 🏛️ **Identity & Access Management**
- **Azure AD Integration**: VM login without local accounts
- **RBAC Everywhere**: Granular permissions for all services
- **Managed Identity**: Secure service-to-service authentication
- **Key Vault RBAC**: No access policies, only role-based access

### 📊 **Monitoring & Compliance**
- **Azure Monitor**: Comprehensive logging and metrics
- **Security Extensions**: Threat detection and response
- **Audit Logging**: All Key Vault and management operations
- **Policy Compliance**: Azure Policy integration ready

## 🔄 Deployment Scenarios

### 🧪 **Development/Testing**
```bash
# Quick development deployment
az deployment group create \
  --resource-group "rg-dev-centralus" \
  --template-file "foundations-core.bicep" \
  --parameters environment=dev workloadName=myapp
```

### 🏢 **Production**
```bash
# Production with full private endpoints
az deployment group create \
  --resource-group "rg-prod-centralus" \
  --template-file "foundations-core.bicep" \
  --parameters environment=prod workloadName=myapp \
  --parameters privateEndpointSubnetId="/subscriptions/.../subnets/pep" \
  --parameters spokeVnetId="/subscriptions/.../virtualNetworks/spoke"
```

### 🔄 **Multi-Region**
```bash
# Deploy to multiple regions using parameter files
az deployment group create --parameters "@parameters/main.parameters.eastus.json"
az deployment group create --parameters "@parameters/main.parameters.westus.json"
```

## 📚 Documentation

### 📖 **Getting Started**
- **[Release Notes](./Documentation/RELEASE-NOTES-v1.0.0.md)** - Current version features and deployment guide
- **[Documentation Index](./Documentation/README.md)** - Complete documentation navigation

### 🔒 **Security Information**
- **[Security Summary](./Documentation/SECURITY-REMEDIATION-SUMMARY.md)** - Comprehensive security improvements
- **[NSG Analysis](./Documentation/NSG-SECURITY-FIXES-APPLIED.md)** - Network security hardening details
- **[Key Vault Updates](./Documentation/KEYVAULT-SECURITY-TEMPLATE-UPDATES.md)** - Key Vault security configuration

### 🔍 **Analysis Reports**
- **[Infrastructure Drift](./Documentation/DRIFT-ANALYSIS-REPORT.md)** - Change tracking and remediation
- **[Repository Cleanup](./Documentation/REPOSITORY-CLEANUP-SUMMARY.md)** - Organization improvements

## 🎯 Use Cases

### Perfect For:
- **🏢 Enterprise Infrastructure**: Secure, compliant, production-ready foundation
- **🔬 Development Environments**: Isolated, secure development platforms
- **🚀 Platform Engineering**: Reusable infrastructure patterns and templates
- **🛡️ Security-First Workloads**: Zero trust network architecture
- **📊 Regulated Industries**: Compliance-ready with comprehensive audit trails

### Architecture Patterns:
- **Hub-Spoke Topology**: Centralized connectivity and security
- **Private Cloud**: Minimal internet exposure with secure access
- **Workload Isolation**: Separate environments with controlled connectivity
- **Bootstrap Pattern**: Secure credential management from day one

## 🔄 Version History

### **v1.0.0** (Current - August 16, 2025)
- ✅ **Complete Hub-Spoke Architecture**: Production-ready network topology
- ✅ **Security Hardening**: NSG protocol specificity, private endpoints
- ✅ **Bootstrap Pattern**: Secure Key Vault initialization
- ✅ **Comprehensive Documentation**: Security analysis and remediation guides
- ✅ **Clean Repository**: Organized structure with modular components
- ✅ **Enterprise Ready**: Tested, validated, and production-deployed

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes** following the established patterns
4. **Test deployment** in a development environment
5. **Update documentation** as needed
6. **Submit a pull request** with detailed description

### Development Guidelines
- Follow the modular structure in `modules/`
- Add documentation to `Documentation/` folder
- Update parameter files for new features
- Maintain security-by-default principles

## 🆘 Support & Troubleshooting

### Common Issues
- **Key Vault Access**: Ensure correct Azure AD object ID in parameters
- **Network Connectivity**: Verify NSG rules and private endpoint configuration
- **Deployment Failures**: Check Azure CLI version and subscription permissions

### Getting Help
1. **Check Documentation**: Start with `Documentation/README.md`
2. **Review Security Reports**: Check for configuration mismatches
3. **Validate Parameters**: Ensure all required values are set correctly
4. **Test Connectivity**: Use Bastion to verify VM and service access

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Microsoft Azure Team**: Azure Bicep and ARM template guidance
- **Azure Architecture Center**: Hub-spoke topology best practices
- **Cloud Adoption Framework**: Enterprise architecture patterns
- **Well-Architected Framework**: Security and operational excellence principles

---

**🚀 Ready to deploy enterprise-grade Azure infrastructure?**

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template)

**Get started today with secure, scalable, production-ready infrastructure!**
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
