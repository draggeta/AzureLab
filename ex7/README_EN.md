# Day 7 - Private/service endpoints and VNET integration

* [Azure Functions](#azure-functions)
* [Service endpoint](#service-endpoint)
* [Private endpoint](#private-endpoint)
* [VNET integration](#vnet-integration)
* [(Optioneel) Traffic manager aanpassingen](#optioneel-traffic-manager-aanpassingen)
* [Lab clean-up](#lab-clean-up)

VMs are convenient, as they allow consistent deployment models between Azure and on-prem, but are not cost efficient. By wants to move to `Azure functions` (PaaS API webservers) for their API services.

Security has also introduced another request. Due to the massive amount of PII being handled by the insurer, all outbound north-south traffic must be blocked for management services unless needed.

To meet the requirements, `function apps` will replace the API servers and service endpoints and private endpoints will be used to limit north-south traffic.

![Private and service endpoint topology](./data/pe_se.svg)

## Azure Functions

The migration windows allows for downtime of the service. There is no need for a slow migration with no service interruption.

How could the migration be performed with a minimal amount of downtime?

> <details><summary>Migration options</summary>
>
> There are many options. Downtime can be limited with DNS record changes or by using `AGW`, `traffic manager` or `Azure front door` as load balancers. `NVAs` are of course also a possibile solution.

</details>

### Remove deprecated/decommisioned services

Remove the following resources and related resources:
* spoke A webserver (and `disk`, `NIC`)
* spoke B webserver (and `disk`, `NIC`)
* `application gateway` (and `disk`, `NIC`)
* `external load balancer` (and `disk`, `NIC`)
* VM and `AGW` subnets
* keep the `NSGs` and `route tables`

### Update firewall configuration

Block all outbound internet traffic on the `AZF`. **DO NOT** block any other east-west traffic. Make sure that [`kms.core.windows.net`](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/custom-routes-enable-kms-activation#solution) and [`azkms.core.windows.net`](https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/custom-routes-enable-kms-activation#solution) are still available on `http/tcp:1688`. Without these rules, Windows VMs won't be able to activate.

### Deploy Azure functions

> **NOTE:** `Function apps` are not a part of the exam. In the following exercises its all about the (service/private) endpoints. `Function apps` run on (and as such require) an  [`App Service Plan`](https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans) and a `storage account`. An `ASP` is just an Azure managed VM that can (multiple) functions.

Deploy two [`function apps`](https://learn.microsoft.com/en-us/azure/azure-functions/functions-create-function-app-portal), one in West Europe and one in North Europe.
* Basics
    * Publish: Code
    * Runtime stack: Python
    * Version: 3.9
    * Plan type: App service plan
    * SKU and size: Dev/Test > B1
* Monitoring
    * Enable Application Insights: No

After succesful deployment of the `functions`, the next step is to deploy the API. Go to `function app` > Deployment Center > Tabblad Settings.
1. Select 'External Git' as source
1. Enter 'https://github.com/draggeta/AzureLabFunction.git' as the repository
1. Enter 'master' as branch
1. Save the deployment
1. (Optional) Verify the deployment status under the tab 'Logs'. When the status becomes 'Success (Active)' the deployment is done. This can take a while.
1. Try to access the API on `https://<fqdn>/api/info` and `https://<fqdn>/api/health` (without a trailing '/')
1. Try to access the API from the management server. This should not succeed.

> **NOTE:** The following exercises are purely lab exercises to learn the possibilities and limits of the services.
>
> The spoke A `function app` will be made available to the management server via `service endpoints`. The B `function app` will be accessible via private endpoints. We'll also be testing with VNET integration to learn about PaaS outbound connectivity.

## Service endpoint

It's now not possible to access the APIs from the management server. This is something the developers do want. However, as mentioned before, the security department doesn't want the management server to access the internet.
[`Service endpoints`](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview) are not the preffered solution, but they can still be used without issues. `Service endpoints` add direct routes over the Microsoft backbone to the enabled PaaS services. The traffic does not go out to the internet and the devices using the service endpoint don't need an internet connection. In most cases, service endpoint traffic will bypass `NVAs`.

A disadvantage of `service endpoint` is that only the devices in subnets with `service endpoints` can access these services. Other subnets (and on-prem networks) cannot access services via a configured `service endpoint`. 

`Service endpoints` are only available for a limited set of resoruces.

### Configure service endpoint 

Go to the hub network and open the management server subnet. Select the 'Microsoft.Web' service under `Service Endpoints` and apply the changes. 
* Verify the access to the spoke A and B APIs from the management server. 
* Check the effective routes of the management server NIC.

> <details><summary>Secure service endpoints</summary>
>
> When a `service endpoint` is attached to a subnet, every device in that subnet's able to access resources of the `service endpoint` type. This may be an issue. Outbound traffic  to `service endpoints` can be limited by using `NSGs` and [`service tags`](https://learn.microsoft.com/en-us/azure/virtual-network/service-tags-overview).
>
> `Storage accounts` `service endpoints` can also use [`service endpoint policies`](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoint-policies-overview) to limit traffic only to specific storage accounts.

</details>

The managament server is able to access all `app services`/`function apps`. Limit the management server's access to only function apps in 'West Europe' (spoke A) and block all other function apps. This can be done by using the existing management `NSG` and `service tags`.

> <details><summary>Hint</summary>
>
> This action requires more than one outbound rule.

</details>

Why can this traffic not be blocked on the `Azure firewall`?
How does the on-prem traffic flow to the `function app`?

## Private endpoint

It's (still) not possible to access the API server in spoke B from the management server. [`Private endpoints`](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview) are the Microsoft recommended solution for internal connectivity. For this lab, we'll be attaching the 'North Europe' `function app` with a `private endpoint` to the spoke B `VNET`.

### Deploying private endpoints

`Private endpoints` can be deployed in subnets together with other resources. Make sure that `VNET` B has a subnet available for the `private endpoint`. Create an `NSG` (if it doesn't already exist) that only allows inbound HTTP(S) from the management server. Attach the `NSG` to the subnet. Also attach the `spoke` B route table to the subnet to make sure return traffic is able to find its way back.


## Lab clean-up

If you're not continuing to the next exercises, it's easier and cheaper to delete the lab when done. The end state of this lab can be [redeployed](../README_EN.md#lab-checkpoints) via the included [Terraform files](./tf/)
