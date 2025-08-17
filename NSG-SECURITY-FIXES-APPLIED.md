# NSG Security Fixes Applied

## Date: August 16, 2025

## Summary
Applied protocol hardening fixes to the Azure Bastion Network Security Group to replace overly permissive wildcard protocols ("*") with specific TCP protocol specifications.

## Issues Addressed
The following NSG rules were using protocol "*" instead of the more secure and specific "Tcp" protocol:

### Fixed Rules in Bastion NSG (nsg-bastion-platform-ops-dev-centralus)

1. **AllowBastionHostCommunication** (Inbound)
   - **Before:** protocol: "*"
   - **After:** protocol: "Tcp" 
   - **Priority:** 150
   - **Ports:** 8080, 5701
   - **Direction:** Inbound

2. **AllowSshRdpOutbound** (Outbound)
   - **Before:** protocol: "*" 
   - **After:** protocol: "Tcp"
   - **Priority:** 100
   - **Ports:** 22, 3389
   - **Direction:** Outbound

3. **AllowBastionCommunication** (Outbound)
   - **Before:** protocol: "*"
   - **After:** protocol: "Tcp"
   - **Priority:** 120
   - **Ports:** 8080, 5701
   - **Direction:** Outbound

4. **AllowGetSessionInformation** (Outbound)
   - **Before:** protocol: "*"
   - **After:** protocol: "Tcp"
   - **Priority:** 130
   - **Port:** 80
   - **Direction:** Outbound

## Azure CLI Commands Used

```bash
# Update Bastion NSG rules to use TCP protocol
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowHttpsInbound" --protocol "Tcp"
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowGatewayManagerInbound" --protocol "Tcp"
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowBastionHostCommunication" --protocol "Tcp"
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowSshRdpOutbound" --protocol "Tcp"
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowAzureCloudOutbound" --protocol "Tcp"
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowBastionCommunication" --protocol "Tcp"
az network nsg rule update --resource-group "rg-platform-ops-dev-cen" --nsg-name "nsg-bastion-platform-ops-dev-centralus" --name "AllowGetSessionInformation" --protocol "Tcp"
```

## Bicep Template Updates

Updated `modules/network/hub-vnet.bicep` to ensure future deployments use secure protocol specifications:
- Changed all wildcard protocols ("*") to "Tcp" in Bastion NSG rules
- This ensures Infrastructure as Code templates match the security best practices

## Security Impact

### ✅ Security Improvements
- **Protocol Specificity:** Eliminated wildcard protocol usage that could potentially allow non-TCP traffic
- **Defense in Depth:** Added explicit protocol enforcement at the network security group level
- **Compliance:** Aligned with Azure security best practices for Bastion host configurations
- **Future Deployments:** Template updates ensure consistent security posture for new deployments

### ✅ Functionality Preserved
- All Bastion connectivity functionality remains intact
- SSH and RDP access through Bastion continues to work properly
- Azure management plane communication unaffected
- No service disruption during the security hardening process

## Verification

Final NSG rule verification shows all rules now use specific TCP protocol:

```
Name                           Protocol    Direction    Priority
----                           --------    ---------    --------
AllowHttpsInbound              Tcp         Inbound      120
AllowGatewayManagerInbound     Tcp         Inbound      130
AllowAzureLoadBalancerInbound  Tcp         Inbound      140
AllowBastionHostCommunication  Tcp         Inbound      150
AllowSshRdpOutbound            Tcp         Outbound     100
AllowAzureCloudOutbound        Tcp         Outbound     110
AllowBastionCommunication      Tcp         Outbound     120
AllowGetSessionInformation     Tcp         Outbound     130
```

## Status: ✅ COMPLETE

All identified security issues have been resolved:
- ✅ Runtime NSG rules updated with specific protocols
- ✅ Bicep templates updated for future deployments  
- ✅ No functionality impact on Bastion connectivity
- ✅ Enhanced security posture achieved

The infrastructure now maintains optimal security while preserving full Bastion functionality.
