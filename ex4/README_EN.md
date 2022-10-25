# Dag 4 - Load balancing and DNS

* [Private DNS Zones](#private-dns-zones)
* [Application Gateway](#application-gateway)
* [Load Balancing](#load-balancing)
* [Traffic Manager](#traffic-manager)
* [Opruimen lab](#opruimen-lab)

The environment is getting more expansive and having to remember IP addresses is getting harder. A solution for this DNS. 
![Private DNS resolving](./data/private_dns.svg)

The API servers must also be made available externally. For the primary environment, an `application gateway` (`AGW`) will be used. The secondary environment will use an `Azure load balancer` for inbound external connectivity.

## Private DNS Zones

The architects have chosen to use [private DNS zone`](https://learn.microsoft.com/en-us/azure/dns/private-dns-privatednszone) to host their internal DNS zones. The zone should register all deployed VMs automatically to reduce the risk of configuration errors. All DNS requests have to continue going through the `AZF` for inspection.

The zone will be named `by.cloud`.

1. [Create](https://learn.microsoft.com/en-us/azure/dns/private-dns-getstarted-portal) a `private DNS zone`.
1. [Attach](https://learn.microsoft.com/en-us/azure/dns/private-dns-virtual-network-links) the DNS Zone to each VNET where [`auto registration`](https://learn.microsoft.com/en-us/azure/dns/private-dns-autoregistration) is desired (hub and both spokes).
    * Via private DNS zone > Virtual network links > Add
    * Turn on `auto registration`

    > <details><summary>Auto-registration</summary>
    >
    > `Auto registration` is a handy feature, but each zone can only be attached to [100 `VNETs`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-dns-limits) if the the feature is enabled.
    >
    > A `VNET` with a DNS zone with `auto registration` enabled can only have that zone attached.

    </details>

1. Check in the DNS zone overview if the `VMs` are registered. If not, wait until all `virtual machines` have registered themselves in the zone.
1. Resolve some of the servers:
    * linux: `dig <host>.by.cloud`
    * windows: `Resolve-DnsName <host>.by.cloud`
1. This [doesn't work](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances#name-resolution-that-uses-your-own-dns-server), why?

    > <details><summary>DNS resolution</summary>
    >
    > Zones attached to a `VNET` can only be resolved by using the `VNETs` built-in DNS server. The built-in DNS server is available on 168.63.129.16 for all VNETs. No `VNET`/on-prem network can use the DNS server of another `virtual network`. 
    >
    > All `VNETs` use the `AZF` DNS server. The `AZF` doesn't forward traffic to the network's DNS server, but CloudFlare DNS and Google DNS. This means that the zone is unresolveable for now. To fix this situation, have the firewall forward DNS requests to the `VNET` DNS.
    >
    > As of the time of writing, it's neccessary to deploy custom DNS servers in Azure to resolve `private DNS zones` from outside attached `VNETs`. Soon, the [`Azure DNS Private Resolver`](https://learn.microsoft.com/en-us/azure/dns/dns-private-resolver-overview) will be released which may make custom DNS servers unnecessary.
    >
    >**The only reason the private DNS zone is attached to the spokes, is for auto registration, not for DNS resolving.**

    </details>

6. Edit the `AZF` DNS settings so private DNS resolving works. **Don't** change the the `VNET` DNS settings.

## Application Gateway

The application in spoke A, the primary region, has to be made available externally. There are a few options:
* Public IP attached to the instance(s)
* Exposing the service via the Azure Firewall to the internet (albeit with an internal load balancer)
* Use an external/public `load balancer`
* Use an `application gateway` (`AGW`)

De applicatie moet zo veilig mogelijk uitgerold worden en BY wil graag beginnen met het testdraaien van de [`AGW`](https://learn.microsoft.com/en-us/azure/application-gateway/overview) en zijn L7 (WAF) beveiliging.

![Load balancing](./data/load_balancing.svg)

> **NOTE:** We gaan geen WAF fuctionaliteit hier gebruiken. Het opzetten hiervan is wat ingewikkelder, is duurder en kan wat tijd kosten.

> **NOTE:** Hoe de AGW geplaatst wordt is afhankelijk van wat de organisatie wil. In dit lab gaan we de [AGW en AZF parallel](https://learn.microsoft.com/en-us/azure/architecture/example-scenario/gateway/firewall-application-gateway#firewall-and-application-gateway-in-parallel) naast elkaar draaien. Dit is een van de makkelijkere opties. Lees de gelinkte documentatie door voor andere architecturen. Het is in deze opzet mogelijk om de AGW in de hub neer te zetten, indien het in meerdere VNETs gebruikt zal worden.

1. Configureer de `application gateway`.
    * Bepaal waar je de AGW uit wilt rollen. Hub of spoke A.
    * Kies voor een v2 application gateway
    * Controleer de frontend IP configuration
    * Maak een *listener* en *backend pool* aan. Zet de spoke A VM(s) in de backend pool.
1. (Optioneel) Na het uitrollen van de gateway, kan ook een custom health probe worden aangemaakt.
    * Maak een uitgebreidere health probe om te controleren of de server werkt. De server heeft een healthcheck op de `/health/` API endpoint die een `HTTP 200 OK` teruggeeft met bericht `{"health": "ok"}`. 
        * protocol: Http
        * pick host name from backend http settings: true
        * path: `/health/`
        > **NOTE:** Indien voor de HTTP health check is gekozen, is de '/' aan het eind nodig.
    * Koppel de health probe aan de HTTP setting

1. Configureer `diagnostics settings` conform de DHB standaarden.
1. Bezoek de webserver/API via de management server. Gebruik hiervoor de DNS naam die bij de `public IP` van de `AGW` hoort.
    * Afhankelijk van de gekozen type session persistence kan je verschillende hosts tegen komen of steeds dezelfde.
1. Maak handmatig een DNS CNAME record aan in de `private DNS zone` voor de `AGW` A record.
    * Deze CNAME is niet extern te resolven, alleen binnen in het netwerk.
1. Test de interne werking op basis van IP en DNS
    > <details><summary>Health probe status</summary>
    >
    > Voor de `application gateway` is het een stuk makkelijker om de health probe statussen te zien van de servers in een pool. Er is een sectie genaamd `Backend health` die een overzicht terug geeft.

    </details>

1. Wat is het verschil tussen inbound en outbound verkeer vanaf de spoke A webserver?

## Load Balancing

De applicatie in spoke B moet redundant worden uitgevoerd. Application Gateways zijn duur en die als standby hebben draaien kost teveel. Voor de backup site is daarom gekozen voor een publieke load balancer. Een [`load balancer`](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview) moet de load kunnen verdelen en bij uitval moet de uitgevallen server uit de pool gehaald worden.

1. [Rol](https://learn.microsoft.com/en-us/azure/load-balancer/quickstart-load-balancer-standard-public-portal#create-load-balancer) een `load balancer` uit.
    * Type: Public
    * SKU: Standard (Basic kan niet, want de VMs maken geen gebruik van een `availability set`)
    * IP address assignment: Dynamic
1. Configureer de `load balancer`.
    * Controleer de frontend IP configuration
    * Maak een backend pool aan. Zet de VMs erin
    * Maak een zinnige health probe om te controleren of de server werkt. De server heeft een healthcheck op de `/health/` API endpoint.
    > **NOTE:** Indien voor de HTTP health check is gekozen, is de '/' aan het eind nodig.
    * Maak een load balancing rule aan.
    * Session persistance: naar eigen keus

1. Configureer `diagnostics settings` conform de DHB standaarden.
1. Bezoek de webserver/API via de management server. Lukt dit? Waarom wel/niet?
    > <details><summary>External load balancers</summary>
    >
    > De Azure ELB's doen aan DNAT, maar geen SNAT. De reden hiervoor is dat het, in tegenstelling tot de AGW, geen interne IP-adres heeft. Wanneer jouw server dit verkeer ontvangt, zal het dus het antwoord terugsturen via zijn beste route. In dit geval, is dat de default route via de Azure Firewall. Dit is duidelijk een voorbeeld van asymmetrisch verkeer.
    > 
    > Het is op te lossen [door het verkeer als volgt](https://learn.microsoft.com/en-us/azure/firewall/integrate-lb#public-load-balancer) te laten lopen: 
    > * Azure Firewall PIP
    > * DNAT richting ELB PIP
    > * ELB load balancet verkeer naar server
    > * Server heeft UDR voor AZF PIP direct naar het internet
    >   * Azure SDN SNAT de server IP terug naar LB IP
    >   * AZF SNAT het weer naar zijn IP en stuurt het door naar de client
    > 
    > Dit is best onzinnig om verschillende redenen.

    </details>

Kies een van de twee opties om het op te lossen:
1. Richt het verkeer in conform de microsoft documentatie.
1. Verwijder de ELB en NAT verkeer vanuit de AZF direct richting de spoke B webserver.
1. Verwijder de ELB en NAT verkeer vanuit de AZF richting een interne load balancer waar de spoke B webserver achter hangt.

## Traffic Manager

[`Traffic Manager`](https://learn.microsoft.com/en-us/azure/traffic-manager/traffic-manager-overview) is een DNS `load balancer` dat op wereldwijde schaal verkeer kan afhandelen. Het is vooral handig voor load balancing tussen datacentra. BY wil dat verkeer altijd in `West Europe` binnenkomt, tenzij er een probleem is in deze regio. In die gevallen moet het verkeer naar `North Europe`. We gaan in deze opdracht een `Traffic Manager profile` aanmaken dat verkeer over de regio's verdeelt.

1. Maak een nieuwe `Traffic Manager profile` aan.
    * [Routing method](https://learn.microsoft.com/en-us/azure/traffic-manager/traffic-manager-routing-methods): Priority
    * Zet de probing interval op 10 secondes (scheelt met testen).
    > <details><summary>Routing Methods</summary>
    >
    > De routing methods bepalen wie op welke instance terecht komt.
    >    * priority: voor een active/passive of primary/backup setup
    >    * weighted: verkeer proportioneel verdelen op basis van weight
    >    * performance: verkeer sturen naar best presterende server, vanaf een gebruikersperspectief bekeken
    >    * geographic: gebruikers vanuit specifieke regio's naar een specifieke endpoint sturen
    >    * multivalue: stuurt meerdere endpoints terug in plaats van één enkele
    >    * subnet: verkeer verdelen op basis van source subnet

    </details>
1. Ga naar Traffic Manager > Endpoints en voeg een nieuwe endpoint toe.
    * Gebruik Azure endpoints en kies de AGW IP.
1. Herhaal dit voor de AZF PIP.
    * Geef het een hogere metric dan de AGW IP. Hierdoor is de AGW preferred.
1. Test nu het browsen naar de website vanuit een externe client door gebruik te maken van jouw DNS name, te vinden bij 'Overview'.
    * Schakel de VM in spoke A uit en controleer of je in spoke B uit komt.
1. Optioneel: Speel met de routing method. Gebruik eventueel web proxies om verkeer vanuit andere regio's te laten komen.

> **NOTE:** Onder normale omstandigheden maak je gebruik van een CNAME die naar de traffic manager FQDN verwijst en ga je niet direct naar de TM FQDN. Voor het lab is geen externe DNS zone beschikbaar.

## Opruimen lab

Het is het gemakkelijkst en goedkoopst om het lab z.s.m. op te ruimen wanneer het niet meer nodig is en [opnieuw uit te rollen](../README.md#lab-checkpoints) via de bijgevoegde [Terraform bestanden](./tf/).
