
# Dag 4 - Load balancing en DNS

De omgeving vordert en interne IP adressen onthouden wordt vervelend. Ook zullen de servers binnenkort redundant uitgevoerd moeten worden, want downtime tijdens upgrades is steeds minder acceptabel. Een oplossing hiervoor is DNS. Voor interne resolving gaan we gebruik maken van een private DNS zone.

![Private DNS resolving](./data/private_dns.svg)

## Private DNS Zones

We gaan een [`private DNS zone`](https://docs.microsoft.com/en-us/azure/dns/private-dns-privatednszone) maken waar we VMs en andere resources in kunnen registeren. De registratie van VMs moet automatisch zodat de kans op fouten kleiner is. Wel moeten alle requests nog steeds door de `AZF` geinspecteerd blijven worden.

Er is gekozen voor de DNS zone `by.cloud`.

1. [Maak](https://docs.microsoft.com/en-us/azure/dns/private-dns-getstarted-portal) een `private DNS zone` aan.
1. [Koppel](https://docs.microsoft.com/en-us/azure/dns/private-dns-virtual-network-links) de DNS Zone aan elke VNET waar [`auto registration`](https://docs.microsoft.com/en-us/azure/dns/private-dns-autoregistration) plaats moet vinden (hub en beide spokes).
    * Via de private DNS zone > Virtual network links > Add
    * Schakel `auto registration` in

    > <details><summary>Auto-registration</summary>
    >
    > `Auto registration` is handig, maar het kan voor elke zone maar voor [100 `VNETs`](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-dns-limits) ingeschakeld worden. 

    </details>

1. Controleer in overview of de `VMs` geregistreerd zijn. Wacht totdat alle `virtual machines` in de zone zijn opgenomen.
1. Resolve nu een van de servers:
    * linux: `dig <host>.by.cloud`
    * windows: `Resolve-DnsName <host>.by.cloud`
1. Dit [werkt niet](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances#name-resolution-that-uses-your-own-dns-server), waarom?

    > <details><summary>DNS resolution</summary>
    >
    > Om een zone gekoppeld aan een `VNET` te kunnen resolven, moet je de `VNET` DNS servers gebruiken. Alle `VNETs` hier gebruiken de `AZF` als DNS server. De `AZF` gebruikt echter niet het `VNET` als DNS server, maar CloudFlare DNS en Google DNS.  
    >
    > De ingebouwde `VNET` DNS server (168.63.129.16) is alleen bereikbaar vanuit de VNET. VM's kunnen dus niet de ingebouwde DNS server van een ander `VNET` gebruiken. Ook kun je niet vanuit een on-prem omgeving de VNET DNS banderen om `private DNS zones` te resolven. 
    >
    > Er moet ten tijde van schijven dus altijd een eigen DNS server in Azure aanwezig zijn om de zones te resolven. Om dit te kunnen in een productie omgeving, moet het resolven van de `private DNS zones` via een DNS forwarder/proxy lopen in een gekoppelde `VNET`.
    >
    >**De enige reden dat de zone gekoppeld is aan de spokes, is dus voor de auto registratie, niet DNS resolving.**

    </details>

6. Pas de `AZF` DNS instellingen aan zodat resolving werkt. Pas de `VNET` DNS instellingen **NIET** aan.

## Application Gateway

De applicatie in spoke A moet extern benaderbaar worden. We hebben hiervoor enkele opties:
* Public IP aan de instance(s)
* Via de Azure Firewall de servers ontsluiten vanaf het internet (al dan niet met interne load balancer)
* Gebruik maken van een externe/publieke `load balancer`
* Gebruik maken van een `application gateway` (`AGW`)

De applicatie moet zo veilig mogelijk uitgerold worden en BY wil graag beginnen met het testdraaien van de [`AGW`](https://docs.microsoft.com/en-us/azure/application-gateway/overview) en zijn L7 (WAF) beveiliging.

![Load balancing](./data/load_balancing.svg)

> **NOTE:** We gaan geen WAF fuctionaliteit hier gebruiken. Het opzetten hiervan is wat ingewikkelder, is duurder en kan wat tijd kosten.

> **NOTE:** Hoe de AGW geplaatst wordt is afhankelijk van wat de organisatie wil. In dit lab gaan we de [AGW en AZF parallel](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/gateway/firewall-application-gateway#firewall-and-application-gateway-in-parallel) naast elkaar draaien. Dit is een van de makkelijkere opties. Lees de gelinkte documentatie door voor andere architecturen. Het is in deze opzet mogelijk om de AGW in de hub neer te zetten, indien het in meerdere VNETs gebruikt zal worden.

1. Configureer de `application gateway`.
    * Kies voor een v2 application gateway
    * Controleer de frontend IP configuration
    * Maak een backend pool aan. Zet de VM(s) erin
    * Maak een zinnige health probe om te controleren of de server werkt. De server heeft een healthcheck op de `/health/` API endpoint die een `HTTP 200 OK` teruggeeft met bericht `{"health": "ok"}`. 
    > **NOTE:** Indien voor de HTTP health check is gekozen, is de '/' aan het eind nodig.

    > <details><summary>Floating IP/Direct Server Return</summary>
    >
    > Azure kent het concept van een floating IP niet. Gratuitous ARPs kunnen niet in een VNET. Zelfs normale ARPs worden niet gebroadcast maar gevijnsd door de onderliggende hypervisors. Een ander IP adres configureren in de `VM` dan dat geconfigureerd is op de `NIC` via de portal, maakt het mogelijk onbereikbaar.
    >
    > Om dit toch mogelijk te maken, kan een `load balancer` gebruikt worden met floating IP/Direct Server Return aan. Hiermee voert de LB geen DNAT uit. De frontend IP wordt as-is doorgegeven aan de achterliggende `VMs`. 
    >
    > Dit betekent dat de `VMs` de IPs moeten accepteren. Voor een firewall kan dit in de vorm zijn van een VIP. In een Windows Failover Cluster is dit een cluster IP.

    </details>
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

De applicatie in spoke B moet redundant worden uitgevoerd. Application Gateways zijn duur en die als standby hebben draaien kost teveel. Voor de backup site is daarom gekozen voor een publieke load balancer. Een [`load balancer`](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview) moet de load kunnen verdelen en bij uitval moet de uitgevallen server uit de pool gehaald worden.

1. [Rol](https://docs.microsoft.com/en-us/azure/load-balancer/quickstart-load-balancer-standard-public-portal#create-load-balancer) een `load balancer` uit.
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
    > Het is op te lossen [door het verkeer als volgt](https://docs.microsoft.com/en-us/azure/firewall/integrate-lb#public-load-balancer) te laten lopen: 
    > * Azure Firewall PIP
    > * DNAT richting ELB PIP
    > * ELB load balancet verkeer naar server
    > * Server heeft UDR voor AZF PIP direct naar het internet
    >   * Azure SDN NAT de server IP terug naar LB IP
    >   * AZF NAT het weer naar zijn IP en stuurt het door naar de client
    > 
    > Dit is best onzinnig om verschillende redenen.

    </details>

Kies een van de twee opties om het op te lossen:
1. Richt het verkeer in conform de microsoft documentatie.
1. Verwijder de ELB en NAT verkeer vanuit de AZF direct richting de spoke B webserver.

## Traffic Manager

[`Traffic Manager`](https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-overview) is een DNS `load balancer` dat op wereldwijde schaal verkeer kan afhandelen. Het is vooral handig voor load balancing tussen datacentra. BY wil dat verkeer altijd in `West Europe` binnenkomt, tenzij er een probleem is in deze regio. In die gevallen moet het verkeer naar `North Europe`. We gaan in deze opdracht een `Traffic Manager profile` aanmaken dat verkeer over de regio's verdeelt.

1. Maak een nieuwe `Traffic Manager profile` aan.
    * [Routing method](https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-routing-methods): Priority
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
    * Geef het een lagere prioriteit (hogere metric) dan de AGW IP
1. Test nu het browsen naar de website vanuit een externe client door gebruik te maken van jouw DNS name, te vinden bij 'Overview'.
    * Schakel de VM in spoke A uit en controleer of je in spoke B uit komt.
1. Optioneel: Speel met de routing method. Gebruik eventueel web proxies om verkeer vanuit andere regio's te laten komen.

> **NOTE:** Onder normale omstandigheden maak je gebruik van een CNAME die naar de traffic manager FQDN verwijst en ga je niet direct naar de TM FQDN. Voor het lab is geen externe DNS zone beschikbaar.

## Opruimen lab

Het is het gemakkelijkst en goedkoopst om het lab z.s.m. op te ruimen wanneer het niet meer nodig is en [opnieuw uit te rollen](../README.md#lab-checkpoints) via de bijgevoegde [Terraform bestanden](./tf/).
