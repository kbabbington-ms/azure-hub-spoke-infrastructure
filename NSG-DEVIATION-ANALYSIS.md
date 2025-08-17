# NSG Security Rules Deviation Analysis
**Date**: August 16, 2025  
**Resource Group**: `rg-platform-ops-dev-cen`  
**Analysis Scope**: Network Security Group rule deviations from templates

---

## 🔍 **SUMMARY OF NSG ANALYSIS**

### **NSGs Found:**
- `nsg-bastion-platform-ops-dev-centralus` ✅ **COMPLIANT**
- `nsg-vm-platform-ops-dev-centralus` ❌ **DEVIATIONS FOUND**
- `nsg-pep-platform-ops-dev-centralus` ✅ **COMPLIANT** 
- `nsg-sqlmi-platform-ops-dev-centralus` ✅ **COMPLIANT**

---

## 📊 **DETAILED NSG RULE ANALYSIS**

### **1. Bastion NSG** ✅ `nsg-bastion-platform-ops-dev-centralus`

#### **Template vs Deployed Rules Comparison:**
| Rule Name | Template | Deployed | Status |
|-----------|----------|----------|---------|
| `AllowHttpsInbound` | ✅ Port 443 from Internet | ✅ Port 443 from Internet | ✅ **MATCH** |
| `AllowGatewayManagerInbound` | ✅ Port 443 from GatewayManager | ✅ Port 443 from GatewayManager | ✅ **MATCH** |
| `AllowAzureLoadBalancerInbound` | ✅ Port 443 from AzureLoadBalancer | ✅ Port 443 from AzureLoadBalancer | ✅ **MATCH** |
| `AllowBastionHostCommunication` | ✅ Ports 8080,5701 from VNet | ✅ All ports from VNet | ⚠️ **BROADER** |
| `AllowSshRdpOutbound` | ✅ Ports 22,3389 to VNet | ✅ All ports to VNet | ⚠️ **BROADER** |
| `AllowAzureCloudOutbound` | ✅ Port 443 to AzureCloud | ✅ Port 443 to AzureCloud | ✅ **MATCH** |
| `AllowBastionCommunication` | ✅ Ports 8080,5701 to VNet | ✅ All ports to VNet | ⚠️ **BROADER** |
| `AllowGetSessionInformation` | ✅ Port 80 to Internet | ✅ Port 80 to Internet | ✅ **MATCH** |

#### **Analysis:**
- **Overall**: 🟡 **MOSTLY COMPLIANT** with broader permissions than template
- **Issue**: Some rules allow all ports instead of specific port ranges
- **Impact**: **LOW** - Bastion functionality maintained but less restrictive

---

### **2. VM NSG** ❌ `nsg-vm-platform-ops-dev-centralus`

#### **CRITICAL DEVIATION FOUND:**

**Template Expected:**
```bicep
{
  name: 'AllowRdpFromBastion'
  destinationPortRange: '3389'  // RDP port
  sourceAddressPrefix: '192.16.1.0/26'  // Bastion subnet
}
{
  name: 'AllowWinRMFromBastion'
  destinationPortRanges: ['5985', '5986']  // WinRM ports
  sourceAddressPrefix: '192.16.1.0/26'  // Bastion subnet
}
```

**Actually Deployed:**
```json
{
  "name": "AllowRdpFromBastion",
  "destinationPortRange": null,  // ❌ NO PORT RESTRICTION
  "sourceAddressPrefix": "192.16.1.0/26"
}
{
  "name": "AllowWinRMFromBastion", 
  "destinationPortRange": null,  // ❌ NO PORT RESTRICTION
  "sourceAddressPrefix": "192.16.1.0/26"
}
```

#### **Security Impact Assessment:**
| Security Aspect | Expected | Current | Risk Level |
|------------------|----------|---------|------------|
| **RDP Access** | Port 3389 only | **ALL PORTS** | 🔴 **HIGH** |
| **WinRM Access** | Ports 5985/5986 only | **ALL PORTS** | 🔴 **HIGH** |
| **Source IP** | Bastion subnet only | Bastion subnet only | ✅ **SECURE** |
| **Attack Surface** | Minimal (2-3 ports) | **MAXIMUM (65535 ports)** | 🔴 **HIGH** |

#### **Vulnerability Details:**
- ❌ **Overpermissive Rules**: VM accepts connections on ALL ports from Bastion
- ❌ **Excessive Attack Surface**: Instead of ~3 management ports, ALL 65535 ports are open
- ❌ **Defense in Depth Violation**: NSG not providing port-level protection
- ❌ **Compliance Risk**: May violate security standards requiring port restrictions

---

### **3. Private Endpoint NSG** ✅ `nsg-pep-platform-ops-dev-centralus`

#### **Rules Analysis:**
| Rule Name | Expected | Deployed | Status |
|-----------|----------|----------|---------|
| `AllowVNetInbound` | ✅ VNet to VNet all ports | ✅ VNet to VNet all ports | ✅ **MATCH** |
| `DenyAllInbound` | ✅ Deny all other traffic | ✅ Deny all other traffic | ✅ **MATCH** |

#### **Analysis:**
- **Status**: ✅ **FULLY COMPLIANT**
- **Security**: Appropriate for private endpoint subnet

---

### **4. SQL Managed Instance NSG** ✅ `nsg-sqlmi-platform-ops-dev-centralus`

#### **Rules Analysis:**
| Rule Name | Expected | Deployed | Status |
|-----------|----------|----------|---------|
| `allow_management_inbound` | ✅ Management ports from anywhere | ✅ Deployed correctly | ✅ **MATCH** |
| `allow_misubnet_inbound` | ✅ All from SQL MI subnet | ✅ From 10.2.0.128/27 | ✅ **MATCH** |
| `allow_health_probe_inbound` | ✅ Health probes | ✅ From AzureLoadBalancer | ✅ **MATCH** |
| `allow_management_outbound` | ✅ Management outbound | ✅ Deployed correctly | ✅ **MATCH** |
| `allow_misubnet_outbound` | ✅ All to SQL MI subnet | ✅ To 10.2.0.128/27 | ✅ **MATCH** |

#### **Analysis:**
- **Status**: ✅ **FULLY COMPLIANT**
- **Security**: Appropriate for SQL Managed Instance requirements

---

## 🚨 **CRITICAL SECURITY FINDINGS**

### **HIGH PRIORITY ISSUES:**

1. **VM NSG Port Exposure** 🔴
   - **Risk**: Critical security vulnerability
   - **Details**: All 65,535 ports open from Bastion instead of just RDP (3389) and WinRM (5985/5986)
   - **Impact**: Massive attack surface expansion
   - **Urgency**: **IMMEDIATE FIX REQUIRED**

### **MEDIUM PRIORITY ISSUES:**

2. **Bastion NSG Over-Permission** 🟡
   - **Risk**: Broader than necessary permissions
   - **Details**: Some rules allow all ports instead of specific ranges
   - **Impact**: Reduced defense in depth
   - **Urgency**: **SHOULD FIX**

---

## 🛠️ **REMEDIATION PLAN**

### **IMMEDIATE (Critical) - VM NSG Fix:**

```bash
# Fix VM NSG RDP rule to restrict to port 3389 only
az network nsg rule update \
  --resource-group "rg-platform-ops-dev-cen" \
  --nsg-name "nsg-vm-platform-ops-dev-centralus" \
  --name "AllowRdpFromBastion" \
  --destination-port-ranges "3389"

# Fix VM NSG WinRM rule to restrict to ports 5985 and 5986 only  
az network nsg rule update \
  --resource-group "rg-platform-ops-dev-cen" \
  --nsg-name "nsg-vm-platform-ops-dev-centralus" \
  --name "AllowWinRMFromBastion" \
  --destination-port-ranges "5985" "5986"
```

### **MEDIUM PRIORITY - Bastion NSG Hardening:**

```bash
# Fix Bastion communication rules to use specific ports
az network nsg rule update \
  --resource-group "rg-platform-ops-dev-cen" \
  --nsg-name "nsg-bastion-platform-ops-dev-centralus" \
  --name "AllowBastionHostCommunication" \
  --destination-port-ranges "8080" "5701"

az network nsg rule update \
  --resource-group "rg-platform-ops-dev-cen" \
  --nsg-name "nsg-bastion-platform-ops-dev-centralus" \
  --name "AllowSshRdpOutbound" \
  --destination-port-ranges "22" "3389"

az network nsg rule update \
  --resource-group "rg-platform-ops-dev-cen" \
  --nsg-name "nsg-bastion-platform-ops-dev-centralus" \
  --name "AllowBastionCommunication" \
  --destination-port-ranges "8080" "5701"
```

### **TEMPLATE UPDATES:**

Update Bicep templates to ensure consistent deployment:
- Verify `modules/network/spoke-vnet.bicep` VM NSG rules
- Add validation to prevent `destinationPortRange: null`
- Consider template linting rules for port specifications

---

## 📈 **RISK ASSESSMENT**

### **Current Security Posture:**
- 🔴 **VM NSG**: **CRITICAL VULNERABILITY** - All ports exposed
- 🟡 **Bastion NSG**: **MEDIUM RISK** - Over-permissive but functional  
- ✅ **Private Endpoint NSG**: **SECURE** - Properly configured
- ✅ **SQL MI NSG**: **SECURE** - Compliant with requirements

### **Overall Risk Level:** 🔴 **HIGH**
**Primary Concern**: VM NSG exposes all ports instead of specific management ports

### **Recommended Actions:**
1. **URGENT**: Fix VM NSG port restrictions immediately
2. **SOON**: Harden Bastion NSG port specificity  
3. **ONGOING**: Implement NSG rule validation in deployment pipeline
4. **MONITORING**: Set up alerts for NSG rule changes

---

## 🎯 **COMPLIANCE IMPACT**

### **Standards Affected:**
- **ISO 27001**: Network security controls
- **NIST Cybersecurity Framework**: Network segmentation
- **CIS Controls**: Secure network configuration
- **Azure Security Benchmark**: Network security guidelines

### **Audit Findings:**
- **Non-Compliance**: VM NSG port exposure violates least privilege principle
- **Documentation Gap**: Deployed rules don't match documented templates
- **Change Management**: No tracking of NSG rule modifications

**Recommendation**: Immediate remediation required before security audits.
