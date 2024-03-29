# Day 8 - Azure Front Door and others

* [Remove Traffic Manager profiles](#remove-traffic-manager-profiles)
* [Azure Front Door](#azure-front-door)
* [Uncovered items](#uncovered-items)
* [(Optional) IPv6](#optional-ipv6)
* [(Optional) Forceer traffic through the Azure firewall](#optional-force-traffic-through-the-azure-firewall)
* [(Optional) Global/Cross regional load balancer](#optional-globalcross-regional-load-balancer)
* [(Optional) Security/WAF policies](#optional-securitywaf-policies)
* [(Optional) ExpressRoute](#optional-expressroute)
* [(Optional) Virtual WAN](#optional-virtual-wan)
* [Lab clean-up](#lab-clean-up)

With the new regulations imposed by De Hollandsche Bank, BY has to start offering all external services via IPv6.

BY has also noticed that users outside of the Netherlands and Ireland have a significantly worse experience when using their services. The biggest problem is the added delay retrieving static resources from the services. Especially instructional videos tend to buffer a lot. These issues have an adverse effect on consumer retention.

BY wants a solution to cache data closer to users. A CDN can be used, but the architects have decided to use Azure `Front door`. `AFD` namely has the benefit of also exposing services via IPv6, which is another checkbox checked. Using `AFD` also makes it so that less separate services need to be managed.

![Azure Front Door topology](./data/front_door.svg)

## Remove Traffic Manager profiles

Remove the `Traffic Manager` profiles. These resources won't be needed after implementing Azure `front door`. Especially as the TM profiles are broken [due to the `function app`/FQDN](../ex7/README_EN.md#optional-traffic-manager-changes) issues.

> **NOTE:** In production it's a valid architecture to use `AFD` and `TM` profiles side by side or `AFD` in front of `TM`.

## Azure Front Door

Due to the fact that the endpoints are completely different between the function apps and on-prem servers, it's not really possible to load balance traffic accross all three endpoints (spoke A, B and on-prem). For this reason, the exercise is split into two, one for the function apps and one for the on-prem webservers.

Front door can be deployed in an existing environment without issues. Search the Azure portal for `Front Door and CDN profiles`. Select `Front door` and `custom settings`. This allows us to view more configurations before deployment.
* Secrets: keep it empty. This is used for certs for custom domains.
* Endpoint:
    * Choose a name as the FQDN of the front door
    * Add a route for the function apps: (a path to match)
        * Patterns to match: `/*` (any path not matched by other rules is matched by this rule)
        * Add an origin group with both function apps as origin. (Use app service as type. Divide the traffic evenly over both origins)
        * Health probe interval: 10 seconds
        * Accepted Protocols: HTTP and HTTPS
        * Redirect: check
        * Enable caching.        

            > <details><summary>Query string behavior</summary>
            >
            > The chosen query string caching behaviour doesn't matter in the lab environment, but in production it's good to know what [each option does](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-caching?pivots=front-door-standard-premium#query-string-behavior).

            </details>
    * Add a route for the on-prem environment:
        * Patterns to match: `/on-prem` and `/on-prem/*`
        * Add an origin group with the on-prem firewall/API service as **custom** destination and use HTTP for the backend
        * Health probe interval: 10 secondes
        * Accepted Protocols: HTTP en HTTPS
        * Redirect: check
        * Origin path: `/`
            > <details><summary>Origin Path</summary>
            >
            > De origin path can be used for URL rewrites. Without the path, the path is passed as is to the backend server. With an origin path, everything in the pattern match is replaced by the origin path. Below is a quote from the [documentatie](https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-configure-route#create-a-new-azure-front-door-standardpremium-route):
            >
            >	*This path is used to rewrite the URL that Azure Front Door will use when constructing the request forwarded to the origin. By default, this path isn't provided. As such, Azure Front Door will use the incoming URL path in the request to the origin. You can also specify a wildcard path, which will copy any matching part of the incoming path to the request path to the origin. Origin path is case sensitive.*
            >
            > *Pattern to match: /foo/**  
            > *Origin path: /fwd/*  
            >
            > *Incoming URL path: /foo/a/b/c/*  
            > *URL from Azure Front Door to origin: fwd/a/b/c.**  
   
            </details>
    * Security policy: keep it empty

It can take more than two minutes before the front door configuration is active. This is due to the fact that the configuration has to be deployed to all regions and edges. The provisioning state can be viewed under the 'Front Door Manager' section.

Perform requests to the API::
* `https://<front door fqdn>/api/info`  # azure functions
* `https://<front door fqdn>/on-prem/`  # on-prem

Also try to resolve the FQDNs. Both IPv4 and IPv6 addresses should be returned.
* linux: `dig <front door fqdn> +short`
* windows: `Resolve-DnsName <front door fqdn>`

## Uncovered items

This is the end of the lab. However, there are some items not covered by this lab that can come up in the exam. The reasons for the omissions are varied, but mostly come down to the fact that these are expensive resources or that the deployments of these resources aren't lab friendly.

### (Optional) IPv6

Front door makes all services (externally) available on IPv6. This may ease the burden of deploying IPv6 internally in your organization. It even works for Azure resources that don't support IPv6, such as Azure functions.

IPv6 is GA for [VNETs and VMs](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/ipv6-overview), but quite a lot of PaaS services don't yet [support](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/ipv6-overview#limitations) the [address family](https://msandbu.org/ipv6-support-in-microsoft-azure/).

* Deploy IPv6 in the 'on-prem VNET'.
* Attach a public IPv6 address to the 'on-prem firewall'.
* Edit NSGs. Can IPv4 and IPv6 sources and destinations be combined in the same rule? 

### (Optional) Force traffic through the Azure firewall

Traffic between 'on-prem' and the spokes don't traverse the Azure firewall. This is the default scenario and may not be desired. By editing route tables, traffic between 'on-prem'and spokes can be forced through the `AZF`.

* [Edit](https://learn.microsoft.com/en-us/azure/virtual-network/manage-route-table#create-a-route-table) the UDR [propagation settings](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview#border-gateway-protocol).
* Configure a UDR on the VGW subnet.
* Create firewall rules allowing the traffic between the locations.
* Use the log analytics workspace to view the logs.

### (Optional) Global/Cross Regional load balancer

De cross regional load balancer is for L4 what Azure front door is for L7 traffic. It uses an anycast public IP address and is able to load balance traffic over external load balancers. Try to deploy two external load balancers fronted by a cross regional load balancer. 

* Which SKU must be used to deploy a CRLB?
* Which regions support the CRLB?
* What happens when the region hosting the CRLB goes becomes unavailable?

### (Optional) Security/WAF policies

Security policies can be used to filter traffic on the application level. These policies can be used in multiple resources, including `front door` and `application gateway`.

* Create a policy blocking traffic from non-European countries.
* Apply the policy to the `front door`.
* Test the policy (maybe using a web proxy or for example from a VM in the US.)

### (Optional) ExpressRoute

Its not possible to configure a working ExpressRoute, but it's possible to get a good idea of the initial configuration.

* Deploy an ExpressRoute circuit.
* Deploy an ExpressRoute gateway. This gateway can be deployed side-by-side with the `VPN gateway`.
* Find the service key for the ExpressRout circuit. This key has to be entered on the provider side.
* The connection between the circuit and the gateway cannot be made as there is no way to get the circuit running without an actual contract with a provider.

### (Optional) Virtual WAN

Azure VWAN is a solution to connect multiple locations within a region on a somewhat easier way. The deployment and cleanup of VWAN can take a lot of time and the resource is billed by the hour, making it expensive.

* Deploy a virtual WAN and take not of the settings along the way.
* Which providers integrate with the VWAN?
* Transform the virtual hub into a secure hub.

## Lab clean-up

If you're not continuing to the next exercises, it's easier and cheaper to delete the lab when done. The end state of this lab can be [redeployed](../README_EN.md#lab-checkpoints) via the included [Terraform files](./tf/)
