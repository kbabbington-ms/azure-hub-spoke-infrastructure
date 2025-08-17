# Azure Infrastructure Drift Analysis Report
**Date**: August 16, 2025  
**Resource Group**: `rg-platform-ops-dev-cen`  
**Analysis Scope**: Deviation from Infrastructure as Code templates

---

## 🔍 **SUMMARY OF FINDINGS**

### **Manual Changes Detected:**
1. **Key Vault Security Updates** (Post-deployment remediation)
2. **VM Extensions** (Policy-driven and manual installations)
3. **User-Assigned Managed Identity** (External monitoring system)
4. **Additional Resources** (Not in original templates)

---

## 📊 **DETAILED DRIFT ANALYSIS**

### **1. Key Vault Configuration Changes**

**Resource**: `kv-t5cl7dldgq4`  
**Original Template**: `foundations-core.bicep`

#### **Template vs Reality:**
| Property | Template Value | Current Value | Status |
|----------|---------------|---------------|---------|
| `publicNetworkAccess` | `Enabled` | `Disabled` | ✅ **IMPROVED** |
| `networkAcls.defaultAction` | `Allow` | `Deny` | ✅ **IMPROVED** |
| `privateEndpoints` | None | 1 endpoint | ✅ **ADDED** |
| `privateDnsZones` | None | 1 zone | ✅ **ADDED** |

#### **Manual Changes Made:**
```
Last Modified: 2025-08-16T15:13:43.005000+00:00
Modified By: admin@MngEnvMCAP248461.onmicrosoft.com
Change Type: Security remediation deployment
```

#### **Impact**: 
- ✅ **Positive**: Enhanced security posture
- ⚠️ **Template Drift**: `foundations-core.bicep` still has insecure configuration

---

### **2. VM Extension Drift**

**Resource**: `vm-platform-ops-dev-001`

#### **Extensions Not in Original Template:**
| Extension | Publisher | Purpose | Installation Type |
|-----------|-----------|---------|------------------|
| `AdminCenter` | Microsoft.AdminCenter | Windows Admin Center | ⚠️ **Manual** |
| `MDE.Windows` | Microsoft.Azure.AzureDefenderForServers | Microsoft Defender | 🤖 **Policy** |
| `ChangeTracking-Windows` | Microsoft.Azure.ChangeTrackingAndInventory | Change Tracking | 🤖 **Policy** |
| `DependencyAgentWindows` | Microsoft.Azure.Monitoring.DependencyAgent | Dependency Mapping | 🤖 **Policy** |

#### **Failed Extensions:**
- `AADLoginForWindows`: **Failed** - Azure AD login not working properly

#### **Impact**:
- ✅ **AdminCenter**: Manually installed (not managed by IaC)
- ✅ **Security/Monitoring**: Policy-driven (expected behavior)
- ❌ **AAD Login**: Failed state may impact authentication

---

### **3. User-Assigned Managed Identity**

**Resource**: `vm-platform-ops-dev-001` identity configuration

#### **Unexpected Identity Assignment:**
```json
"userAssignedIdentities": {
  "/subscriptions/.../resourceGroups/MAL-mgmt/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ama-prod-centralus-001": {
    "clientId": "4589b2b0-3b82-46ea-9459-9ad7c964a580",
    "principalId": "7c2a26c0-0618-4624-9bd0-76e50177e4fd"
  }
}
```

#### **Analysis**:
- **External Identity**: `id-ama-prod-centralus-001` from `MAL-mgmt` resource group
- **Purpose**: Likely Azure Monitor Agent identity for centralized monitoring
- **Type**: Policy-driven assignment (not manual)

---

### **4. Additional Resources Created**

#### **Resources Not in Original Templates:**

| Resource | Type | Source | Purpose |
|----------|------|--------|---------|
| `stt5cl7dldgq42i-AvailabilityAlert` | Microsoft.Insights/metricalerts | AMBA Policy | Storage monitoring |
| `stt5cl7dldgq42i-aa556782...` | Microsoft.EventGrid/systemTopics | Auto-created | Event Grid system topic |
| Key Vault Private Endpoint | Microsoft.Network/privateEndpoints | Manual Security Fix | Private connectivity |
| Key Vault Private DNS Zone | Microsoft.Network/privateDnsZones | Manual Security Fix | Name resolution |

---

### **5. Tag Inconsistencies**

#### **Key Vault Tags Changed:**
**Original Template Tags:**
```json
{
  "Cost-Center": "Platform Engineering",
  "Created-By": "Bicep-Bootstrap",
  "Environment": "dev",
  "Owner": "Platform Team",
  "Purpose": "Secure Credential Management",
  "Workload": "platform-ops"
}
```

**Current Tags:**
```json
{
  "cost-center": "IT",
  "data-classification": "restricted", 
  "environment": "dev",
  "workload": "platform-ops"
}
```

#### **Changes:**
- ❌ **Case sensitivity**: `Cost-Center` → `cost-center`
- ❌ **Value change**: "Platform Engineering" → "IT"
- ✅ **Added**: `data-classification: restricted`
- ❌ **Removed**: `Created-By`, `Owner`, `Purpose`

---

## 🛠️ **REMEDIATION RECOMMENDATIONS**

### **1. Update Templates to Match Reality**

#### **foundations-core.bicep**
```bicep
// Add private endpoint configuration by default
publicNetworkAccess: 'Disabled'
networkAcls: {
  defaultAction: 'Deny'
  bypass: 'AzureServices'
}
```

#### **main.bicep - VM Extensions**
```bicep
// Consider adding AdminCenter extension if needed organization-wide
// Document expected policy-driven extensions
```

### **2. Standardize Tags**
```bicep
// Create consistent tag schema
var standardTags = {
  'cost-center': 'IT'
  'data-classification': 'restricted'
  'environment': environment
  'workload': workloadName
  'created-by': 'bicep'
  'owner': 'Platform Team'
}
```

### **3. Address Failed Extensions**
```bash
# Fix AAD Login extension
az vm extension delete --vm-name "vm-platform-ops-dev-001" --name "AADLoginForWindows" --resource-group "rg-platform-ops-dev-cen"
az vm extension set --vm-name "vm-platform-ops-dev-001" --name "AADLoginForWindows" --publisher "Microsoft.Azure.ActiveDirectory" --resource-group "rg-platform-ops-dev-cen"
```

---

## 📈 **DRIFT IMPACT ASSESSMENT**

### **Positive Changes** ✅
- **Enhanced Security**: Key Vault private endpoints
- **Improved Monitoring**: Policy-driven agent installations
- **Better Compliance**: Security-focused tag additions

### **Concerns** ⚠️
- **Template Drift**: IaC templates don't reflect current secure state
- **Manual Installations**: AdminCenter not managed by automation
- **Failed Services**: AAD Login extension needs fixing
- **Tag Inconsistency**: Different naming conventions

### **Risk Level**: 🟡 **MEDIUM**
- Infrastructure is more secure than templates
- Manual changes need to be incorporated into IaC
- Some services not functioning as expected

---

## 🎯 **NEXT STEPS**

1. **Update `foundations-core.bicep`** to include private endpoint configuration
2. **Standardize tag schema** across all templates
3. **Fix AAD Login extension** for proper Azure AD authentication
4. **Document policy-driven changes** in template comments
5. **Consider template validation** to prevent future drift

**Recommendation**: Run this analysis monthly to catch configuration drift early.
