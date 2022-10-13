# Day 2 - Firewalling

* [Uitrol AZF](#uitrol-azf)
* [Aanpassen interne routering](#aanpassen-interne-routering)
* [IP groups en network rules](#ip-groups-en-network-rules)
* [Aanpassing routering richting internet](#aanpassing-routering-richting-internet)
* [Inbound management verkeer repareren](#inbound-management-verkeer-repareren)
* [Opruimen lab](#opruimen-lab)

![DNS resolution](./data/dns_inspection.svg)

The security department wants to have `threat intelligence`/threat detection capabilities and want to start by logging and inspecting all DNS queries. For this reason, the `Azure Firewall` will be used as DNS proxy.

> **Note:** Don't start the VMs yet if they aren't running. We're going to change VNET DNS settings. Changes to the VNET DNS settings. VMs in Azure by default use static DHCP and only pick up changes after a reboot or by telling the DHCP client in the OS to renew.

## Deploying the Azure firewall

1. Deploy an [`Azure firewall`](https://learn.microsoft.com/en-us/azure/firewall/overview) in the hub network. It will serve as an NVA with DNS server/proxy capabilities and can perform threat inspection.
    * Place it in the hub
    * The `AZF` requires some other resources to function, such as a subnet with the name `AzureFirewallSubnet`. This subnet must exist before you start the firewall deployment.
    * Standard tier
    * Firewall Policy management
    * Turn off forced tunneling
1. Most of the firewall configuration will happen in the **`firewall policy`**, not on the firewall itself. Configure the firewall as a [DNS proxy](https://learn.microsoft.com/en-us/azure/firewall/dns-settings).
    * DNS > Enabled
    * DNS Proxy > Enabled
    * DNS Servers > Use Google DNS and Cloudflare DNS as DNS servers in place of the `VNET` default DNS.
1. Configure the `AZF` internal/private IP as the [DNS server for the `VNETs`](https://learn.microsoft.com/en-us/azure/virtual-network/manage-virtual-network#change-dns-servers).
    * This has to be configured per `VNET`
    * It can be configured on each `NIC`, but ain't nobody got time for that
1. The firewall now has the capability to see DNS requests, but isn't logging them. Configure the `AZF` `Diagnostics settings`. This has to happen on the firewall, **NOT** the firewall policy. Log everything to the `Log Analytics Workspace` and `storage account`. Configure a retention of 90 days.
1. (Re)Start the VMs or run the below commands to perform a DHCP renew.
    * linux: `sudo dhclient -r && sudo dhclient`
    * windows: `ipconfig /renew`
1. Check the DNS settings received by DHCP.
    * linux: `resolvectl status`
    * windows: `Get-DnsClientServerAddress`
1. Try to resolve some addresses.
    * linux: `dig google.com +short`
    * windows: `Resolve-DnsName google.com`

The `AZF` can now be used as a DNS proxy. Visit some websites on the management server. Then go to the `firewall` > `logs` > `Firewall logs` > `Azure Firewall DNS proxy logs data` > `Run`. Here you can see DNS queries.

> <details><summary>Threat intelligence</summary>
>
> The Azure `firewall` can make use of Microsoft's [`threat intelligence`](https://learn.microsoft.com/en-us/azure/firewall/threat-intel) capabilities to inspect FQDNs and DNS queries.

</details>

## Internal routing

As usual, requirements change over time and the network has to support business needs.

One of the changes is that the API must be able to replicate data between the primary and secondary region. Sadly, a message queue isn't an option. The developed replication method requires that data is directly exchanged between hosts (even if routed).

Creating a full-mesh of VNET peers isn't something that BY wants to do (why?). The solution the architects are gravitating to is to use a `network virtual appliance` and [route tables`](https://learn.microsoft.com/en-us/azure/virtual-network/manage-route-table) to route traffic via the hub.
The AZF can function as the `NVA` doing the routing.

![NVA Routing](./data/internal_routing.svg)

> <details><summary>Default system route tables in Azure</summary>
>
> Azure `virtual networks` contain default [null routes](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview#default) for RFC1918 prefixes (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) and the RFC6598 prefix (100.64.0.0/10). By adding `address spaces` to a `VNET`, more specific routes are added to the default route table.
>
> Direct `VNET peers` add each other's `address spaces` to their system route tables. Routes learned for a peer are not passed on to other peers. This means that spoke A won't learn spoke B routes via the hub peering.

</details>

1. Create a `route table` with a `UDR` for the spoke networks.
    * Use the /14 superscope as destination
    * Use the `AZF` private IP as next-hop
1. Attach the `route table` to the spoke `subnets`.
    > <details><summary>Attaching UDRs</summary>
    >
    > `Route tables` can be attached to multiple VNETs, but the VNETs must be in the same region and subscription as the `route table`. Each region'll require a separate spoke `route table`.

    </details>
1. Verify the traffic flows:
    * Traffic between the spokes and hub
    * Traffic between the spokes
    * Use the `Effective routes` functionality of `NIC` or `Next hop` functionality of the `Network Watcher`

    > <details><summary>Next hop/effective routes</summary>
    >
    > The [`Next hop`](https://learn.microsoft.com/en-us/azure/network-watcher/network-watcher-next-hop-overview) feature of the `Network Watcher` and the `Effective routes` functionality of a `NIC` provide information on the path a packet will take. Use these two tools to verify traffic flows.

    </details>

    > <details><summary>ARP, traceroute and ping</summary>
    >
    > Azure virtual networking is not real networking. It's basically fake.Layer 1 and 2 don't really exist in a `VNET`. Packets within a host are basically copied from `NIC` to `NIC` after passing SDN policies. 
    >
    > There is no real default gateway for example. It's only there so no VM network stacks need to be modified. If you check a system's ARP table
    
    
     Pakketten worden van de ene `NIC` naar een andere `NIC` gekopieerd. De default gateway bestaat dus niet echt en is alleen aanwezig zodat VMs normaal functioneren.
    >
    > Controleer de ARP tabel. Hier zie je dat de MAC-adres van de default gateway opvallend is. De gateway is ook niet te pingen. Verder werkt traceroute niet zoals je verwacht. In een `VNET` laat de traceroute alle default gateways niet zien. `network virtual appliances` zijn wel zichtbaar.

    </details>

1. Test het verbinden van een spoke VM naar een andere spoke VM. Werkt dit?
    * `curl http://<ip>`

    > <details><summary>Antwoord</summary>
    >
    > Dit werkt nog niet, omdat de AZF niet een router, maar een firewall is. Het verkeer moet dus worden toegestaan.
    > Verkeer van/naar de management server werkt wel, omdat dit de firewall omzeilt.

    </details>

## IP groups en network rules

De `Azure Firewall` moet het verkeer van spoke naar spoke toestaan. Bij het aanmaken van regels kunnen IP adressen direct worden ingevoerd, maar het is (soms) handiger om gebruik te maken van `IP groups`. `IP groups` zijn niks anders dan objecten in andere firewalls.

1. Maak voor de spoke VM subnet elk een `IP group`.
1. Maak een `rule collection group` op de firewall policy aan en maak daar in weer een `network rule collection` in aan die verkeer tussen de spokes toe staan. Dit is standaard L4 firewalling.
    * Maak gebruik van `IP groups` om de sources en destinations aan te geven.
    * Verkeer tussen spokes zou nu moeten werken.

    > <details><summary>Rule collection verificatie</summary>
    >
    > De `Azure Firewall` heeft geen optie om te controleren of verkeer is toegestaan. Er moet dus in de logs worden gedoken. Als de `diagnostics settings` geconfigureerd zijn met een `Log Analytics Workspace`, kan gebruik worden gemaakt van de [`Logs` functionaliteit](https://learn.microsoft.com/en-us/azure/firewall/firewall-diagnostics#view-and-analyze-the-activity-log) van een `AZF` om toegestane en gedropte verkeer te bekijken.
    >
    > Ten tijde van schrijven is het bekijken van de logs in de `portal` vervelend. Met de integratie met Azure Sentinel krijgt Azure eindelijk een [single pane of glass](https://learn.microsoft.com/en-us/azure/firewall/firewall-workbook) voor netwerk verkeer. Dit valt echter buiten de lab en examen.

    </details>

## Aanpassing routering richting internet

Vanuit het raad van bestuur komt het bericht dat verkeer van en naar het internet geanalyseerd moet worden voor threats. Ook hiervoor kan de `AZF` gebruikt worden.

![Inspecting internet traffic](./data/internet_firewall.svg)

1. Configureer `threat intelligence` zodat het daadwerkelijk verkeer blokkeert.
    
    > <details><summary>Threat intelligence</summary>
    >
    > `Threat intelligence` staat standaard aan op de `firewall policy`, maar in de alerting modus. Dit kan aangepast worden naar `none` of `alert and block`. De alerts worden weggeschreven naar de `Log Analytics Workspace`.

    </details>

1. Pas de spoke `UDR` aan. Voeg een 0.0.0.0/0 route toe via de `AZF`.
1. Voeg een nieuwe `network rule collection/network rule` toe zodat outbound verkeer richting het internet toegestaan is vanuit de supernet op de `AZF`. 
    * Let op dat je niet alle interne verkeer open zet. Mogelijk moeten er meer regels/collections toegevoegd worden.
1. Controleer de externe IPs van de web servers. Dit zou gelijk moeten zijn aan (een van) de `public IP(s)` gekoppeld aan de firewall
    * linux: `curl https://api.ipify.org`
    * windows: `irm https://api.ipify.org`
    > **Note:** Zie Rule collection verificatie voor informatie.
1. Maak ook een `UDR` aan voor de hub. Deze moet ook een default route richting de `AZF` hebben. Koppel de `UDR` aan de management server `subnet`.
    * Heb je nog verbinding? Waarom wel/niet?

    > <details><summary>Antwoord</summary>
    >
    > Er is sprake van asymmetrische routering. Verkeer komt binnen via de [PIP]('' "Public IP"), maar gaat langs de AZF naar buiten. 
    >
    > De `AZF` doet [automatisch SNAT](https://learn.microsoft.com/en-us/azure/firewall/snat-private-range) voor destination IPs buiten RFC1918.

    </details>

> <details><summary>Service tags en UDRs</summary>
>
> `Service tags` zijn lijsten van IP adressen die een dienst kan gebruiken. De lijst wordt bijgehouden door Microsoft. `Service tags` zijn te gebruiken in `network security groups`, `Azure Firewalls` en sinds kort ook `user defined routes`.

</details>

## Inbound management verkeer repareren

Om de asymmetrische routering te repareren, moet de inbound verkeer via de firewall lopen. We gaan dus via de firewall RDP verkeer NATten naar de management server.

1. Maak een NAT rule collection op de `AZF` aan voor inbound RDP of SSH (Windows of Linux) richting de management server.
    * Sta dit toe alleen vanuit jouw lokale IP.

    > <details><summary>NAT rule collections</summary>
    >
    > `NAT rule collections` maken onder water voor elke match een [tijdelijke `network rule` aan](https://learn.microsoft.com/en-us/azure/firewall/rule-processing#nat-rules). Hierdoor is het niet nodig om handmatig `network rules` te genereren.

    </details>

1. Voeg een nieuwe `network rule collection` toe zodat outbound verkeer toegestaan is vanuit de hub. Gebruik hier optioneel een `IP group`.
1. Verwijder de publieke IP van de management server.
1. Controleer of inbound verkeer werkt. Gebruik hiervoor de externe IP van de `AZF`.
    > <details><summary>RDP werkt niet</summary>
    >
    > Afhankelijk van de NSG instellinge kan RDP nog steeds niet werken. Indien RDP alleen vanuit jouw IP is toegestaan en al het overige inbound verkeer geblokkeerd wordt, zal dit het geval zijn. De `AZF` doet naast DNAT ook SNAT voor inbound verkeer. De reden hiervoor is simpel: het verkeer moet symmetrisch lopen.
    > 
    > Hierdoor is de source van het verkeer een `AZF` instance IP en niet de load balanced IP. Je zal dus verkeer toe moeten staan van de gehele 'AzureFirewallSubnet' reeks. Het is onmogelijk om te weten vanuit welke instance in dat subnet het verkeer af komt.

    </details>
1. Controleer de nu gebruikte externe IP.
1. Test de `threat intelligence` door de volgende website te bezoeken vanuit de management VM:
    * `https://testmaliciousdomain.eastus.cloudapp.azure.com`

> **Note:** de bovenstaande URL werkt niet meer.

> **Optioneel:** configureer een [DNS record](https://learn.microsoft.com/en-us/azure/virtual-network/public-ip-addresses#dns-hostname-resolution) op de `public IP` van de firewall.

## Clean up lab resources

If you're not continuing to the next exercises, it's easier and cheaper to delete the lab when done. The end state of this lab can be [redeployed](../README_EN.md#lab-checkpoints) via the included [Terraform files](./tf/).

In case you do want to keep the lab, it's possible to minimize costs by performing the following steps: 
* Shut down the VMs
* Keep the Azure firewall policy
* Remove the Azure firewall
    * Keep the public IPs
    * The firewall has to be redeployed before starting the next lab.
