# Dag 6 - VPN Gateway

* [VPN Gateway](#vpn-gateway)
* [On-prem firewall uitrollen](#on-prem-firewall-uitrollen)
* [VPN configureren in Azure](#vpn-configureren-in-azure)
* [(Optioneel) Client VPN](#optioneel-client-vpn)
* [(Optioneel) Traffic manager aanpassingen](#optioneel-traffic-manager-aanpassingen)
* [Overig](#overig)
* [Lab clean-up](#lab-clean-up)

## VPN Gateway

### Deploying the VPN Gateway

> **NOTE:** De plaatsing van een VPN gateway is van belang. Bij peerings, geldt dat een Virtual Network Gateway en een route server precies hetzelfde behandeld worden. Het is niet mogelijk om in twee gepeerde VNETs, elk een VPN gateway neer te zetten en de twee VNETs gebruik te laten maken van elkaars VGWs.
>
> Het is ook niet mogelijk om dit te doen met een combinatie van Virtual Network Gateways en route servers.

## Lab clean-up

If you're not continuing to the next exercises, it's easier and cheaper to delete the lab when done. The end state of this lab can be [redeployed](../README_EN.md#lab-checkpoints) via the included [Terraform files](./tf/)
