
# Day 3 - SD-WAN implementatie en NAT gateway

* [NVA deployment](#nva-deployment)
* [Load balancing for high availability](#load-balancing-for-high-availability)
* [NAT gateway deployment](#nat-gateway-deployment)
* [Route traffic to the SD-WAN load balancer](#route-traffic-to-the-sd-wan-load-balancer)
* [Lab clean-up](#lab-clean-up)

BY Health Insurances has deployed an SD-WAN solution in the intervening weeks. All branch offices are now connected to the SD-WAN. Their chosen solution cannot integrate (yet) with `Azure Virtual WAN`. For this reason, a `network virtual appliance` (`NVA`) will be deployed in the hub network. The prefixes listed below must be routed to and from the SD-WAN `NVA`.

| location | subnets | 
| --- | --- | 
| Nederland | 10.192.0.0/22 |
| Ierland | 10.192.4.0/22 |

![SD-WAN](./data/sd_wan.svg)

## NVA deployment

> **NOTE:** While this is a lab and we're deploying only one appliance for the NVA, the deployment will be treated as if it's an active/passive setup. 

You are tasked with an SD-WAN NVA in the hub network. This'll be an active/passive deployment with a `Standard Load Balancer` in front for fast HA failover times.

> **NOTE:** The SD-WAN appliance is an Ubuntu VM with some scripts that simulates the SD-WAN networks. This isn't a true SD-WAN solution from a vendor. 

1. Create a subnet for the NVAs in the hub network. Attach an NSG to the subnet to allow **all** traffic and not just `VirtualNetwork` to `VirtualNetwork`.
    > <details><summary>NSGs and NVAs</summary>
    >
    > Most NVAs have a firewalling component. This means that its often not neccessary to firewall the `NVAs` data ports. It is a good idea to filter traffic to the management/HA interfaces/subnets.
    > 
    > In a single appliance setup, no NSGs would be needed for data traffic. However, Azure `Standard Load Balancers` block all traffic by default and [require NGSs to allow traffic](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview#securebydefault). This limitation does not apply to Basic load balancers

    </details>
1. Deploy an Ubuntu 22.04 VM in the hub.
    * Place it in `West Europe`.
    * Make use of `availability zones`.
    * Don't attach a `public IP`.
    * Turn on `Auto-shutdown` and configure it for 00:00 local time.
    * Provide a custom script in the `Advanced`. Copy the contents of the [cloud init file](./tf/data/cloud-init.yml.j2) in to the **CUSTOM DATA** field, not the **USER DATA** field.
1. Edit all `UDRs` to route the SD-WAN subnets to the `SD-WAN NVA` appliance.
1. Try to ping SD-WAN IP addresses from the management server.
    > <details><summary>IP Forwarding</summary>
    >
    > VMs in Azure, by default, aren't allowed to originate traffic that isn't from their IPs. To allow devices to route, [`IP forwarding`](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview#user-defined) must be `Enabled` on the `network interface card` > `IP configurations`.

    </details>
1. ICMP may work fine, but not all traffic is stateless. For TCP testing purposes, theres an intranet page configured on the appliance. Try to access the HTTP IP page on any of the SD-WAN IP addresses.

## Load balancing for high availability

In production you'll most likely run a high available setup. In Azure, its not possible to use (gratuitous) ARPs to move IP addresses between hosts. A few alternatives are:
1. Via the API. Failovers may take up to two minutes.
1. Via a load balancer. Failovers by default may take up to 10 seconds.
1. Via a route server. Failover may take between 1 and 40 seconds.

A load balancer will be used for high availability. In later labs a the environment will be moved to route servers.

> <details><summary>Internal or public?</summary>
>
> Depending on the where the traffic is initiated, different load balancer types are needed:
> * Traffic initiated from inside: internal load balancer
> * Traffic initiated from outside: external load balancer
>
> Most firewalls often have both types of load balancer as traffic can be initiated from both the internet and the internal network.

</details>

The team has chosen for only an internal load balancer, as the SD-WAN device doesn't accept inbound internet connections.
1. Create a load balancer via the portal.
    * Size: B1s
    * Use the `Standard` SKU. Basic SKUs don't support availability zones and HA NVAs.
    * Chose the `Internal` type.
1. Create a `Frontend IP configuration`. This is the IP address where the `LB` accepts traffic on. A `load balancer` can have more than one frontend IP.
    * Place it in the same subnet as the SD-WAN `NVAs`.
    * Select a zone redundant load balancer
    > <details><summary>Zone redundancy</summary>
    >
    > The type of [redundancy](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-standard-availability-zones) chosen depends on your requirements and application architecture. In most cases, `zone-redundant` will be sufficient.
    >
    > If it's needed to keep traffic within a zone (e.g. reduce latency), it may be useful to chose specific zones. 
    
    </details>
1. Create a `Backend pool`. A `backend pool` is a group of hosts that can receive traffic. Add the SD-WAN appliance to the pool.
1. Create an inbound rule. Inbound rules match traffic entering a `frontend IP configuration` and send the matched traffic to the backend pool.
    * Check `HA Ports`. HA ports are only available on `Standard interne load balancers` and `Gateway load balancers`. `HA ports` send all traffic entering a `frontend IP` to a specific `backend pool`.
    * Create a new health probe to check for health/active VMs/NVAs.
        * A lot of `NVAs` have a way to probe for their health or active/passive status. As this is a basic Linux VM, use SSH on port TCP/22.
    * Turn on `Floating IP`. 
    > <details><summary>Floating IP/Direct Server Return</summary>
    >
    > Azure doesn't have the concept of a floating IP. As mentioned before, its not possible to send gratuitous ARPs in a `VNET`. Even normal ARPs aren't broadcasted. The hypervisors capture the ARP packets and fake the responses. This is why IP addresses always need to be configured on the Azure `network interface card` resource. Changing the IP address (only) in the `VM` may make it unreachable as the IP is unknown in the VNET.
    >
    > To make the concept of a floating IP possible, a `load balancer` can be configured to enable floating IP/Direct Server Return. This disables DNAT on the load balancer and as such the frontend IP is passed unedited to the backend `VMs`.
    >
    > This does mean that the backend `VMs` must have a way of accepting the `load balancer` IPs. For a firewall this can be configured in the form of a VIP or secondary IP. In a Windows Failover Cluster it is the cluster IP.

    </details>

Its important to enabled `diagnostics settings` for load balancers. Without `diagnostics settings`, it is difficult to check if the load balancer is working correctly:  (e.g.: is a server up/down in the backend pool).

1. Configure the `diagnostics settings` after creating the load balancer.
    * Adhere to the requirements from The Dutch Bank (De Hollandsche Bank, DHB): 30 days searchable logs (`log analytics`) and 90 days of archived storage (`storage account`).
    > <details><summary>Health probe status</summary>
    >
    > There is no easy way to check the health status of the backend VMs in the Azure portal. The best way of seeing the status is by using the `load balancer` metrics. Go to the metrics and choose the `Health Probe Status` metric. This graphs the overall health status.
    > 
    > To see the health status per device, split the graphs. Click on `Apply Splitting` > select `Backend IP Address`. This returns the health status history for each server in a `backend pool`.

    </details>

1. Test the SD-WAN appliance's internet connectivity.
    * `curl https://api.ipify.org`

> <details><summary>Internal load balancers and outbound connectivity</summary>
>
> In the situation where only a `standard internet load balancer` (not basic)  is attached to a VM, the VM [will lose the capability to reach the internet](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-troubleshoot#no-outbound-connectivity-from-standard-internal-load-balancers-ilb). This is a security feature by the Azure platform. To allow for outbound internet connectivity, Public IPs or an `external load balancer` can be attached to the VMs. However, a better solution may be the `NAT gateway`.

</details>

## NAT gateway deployment

> **NOTE:** The NAT gateway is a zonal resource. This means that each NGW is deployed in a single zone. For actual zone failure tolerance, you may need to [deploy multiple NGWs](https://learn.microsoft.com/en-us/azure/virtual-network/nat-gateway/nat-availability-zones).

We will deploy a `NAT gateway` (`NGW`) and attach it to the SD-WAN subnet. `NGWs` have the [benefit](https://learn.microsoft.com/en-us/azure/virtual-network/nat-gateway/nat-gateway-resource) of creating NAT translation entries based on:
* source IP
* destination IP
* source port
* destination port
* protocol
This allows each `public IP` to be able to create more than the expected 65535 translations/sessions. 

It is simple to click a gateway together, but if needed you can refer to the [documentation](https://learn.microsoft.com/en-us/azure/virtual-network/nat-gateway/quickstart-create-nat-gateway-portal) for information. 
1. Take care to configure the following settings while deploying the `NGW`:
    * Zone redundancy
    * Idle timeout: How long sessions will remain active on the gateway
2. Check the outbound connectivity from the SD-WAN appliance.
    * `curl https://api.ipify.org`
    * Compare the VMs external IP with the `NGW` IP.

## Route traffic to the SD-WAN load balancer

The SD-WAN appliance now has outbound connectivity and it's able to talk to other SD-WAN appliances. However, traffic is now being sent to the VM directly instead of the high available `internal load balancer` `frontend IP configuration`.

To fix the `HA` configuration, perform the following steps:
1. Edit the `UDRs` to forward traffic for the SD-WAN subnets to the load balancer.
1. Test traffic to the SD-WAN IP addresses.

> <details><summary>Active/active cluster</summary>
>
> A `standard load balancer` works fine for an active/passive cluster. In the case of active/active clusters, they will not function well as there is a chance for asymmetric flows on north-south traffic.
>
> This can be mitigated by performing not only DNAT, but also SNAT or by using a cluster mechanism to always direct traffic to the correct node.
>
> Both options have disadvantages. A more performant option can be the [`gateway load balancer`](https://learn.microsoft.com/en-us/azure/load-balancer/gateway-overview) and a more flexible option is the `route server`. The `gateway load balancer` esures that north-south traffic runs symmetrically. Sadly, the `GLB` doesn't (yet) support east-west traffic. The `route server` will be configured in later labs.

</details>

## Lab clean-up

If you're not continuing to the next exercises, it's easier and cheaper to delete the lab when done. The end state of this lab can be [redeployed](../README_EN.md#lab-checkpoints) via the included [Terraform files](./tf/).
