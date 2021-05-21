
# Dag 3 - Load balancing en DNS

De omgeving vordert en interne IP adressen onthouden wordt vervelend. Ook zullen de servers binnenkort redundant uitgevoerd moeten worden, want downtime tijdens upgrades is steeds minder acceptabel.

## Private DNS Zones

We gaan een [`private DNS zone`](https://docs.microsoft.com/en-us/azure/dns/private-dns-privatednszone) maken waar we VMs en andere resources in kunnen registeren. De registratie van VMs moet automatisch zodat de kans op fouten kleiner is.

De zones per afdeling:

| naam | DNS zone |
| --- | --- |
| Rene | rene.by.cloud |
| Rob | rob.by.cloud |
| Ruud | ruud.by.cloud |
| Tamim | tamim.by.cloud |

1. [Maak](https://docs.microsoft.com/en-us/azure/dns/private-dns-getstarted-portal) een `private DNS zone` aan.
1. [Koppel](https://docs.microsoft.com/en-us/azure/dns/private-dns-virtual-network-links) de DNS Zone aan elke VNET waar [`auto registration`](https://docs.microsoft.com/en-us/azure/dns/private-dns-autoregistration) plaats moet vinden (hub en beide spokes).
    * Schakel `auto registration` in

    > <details><summary>Auto-registration</summary>
    >
    > `Auto registration` is handig, maar het kan voor elke zone maar voor [100 `VNETs`](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-dns-limits) ingeschakeld worden. 

    </details>

1. Controleer in overview of de `VMs` geregistreerd zijn. Wacht totdat alle `virtual machines` in de zone zijn opgenomen.
1. Resolve nu een van de servers:
    * linux: `dig <host>.<naam>.by.cloud`
    * windows: `Resolve-DnsName <host>.<naam>.by.cloud`
1. Dit [werkt niet](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-name-resolution-for-vms-and-role-instances#name-resolution-that-uses-your-own-dns-server), waarom?

    > <details><summary>DNS resolution</summary>
    >
    > Om een zone gekoppeld aan een `VNET` te kunnen resolven, moet je de `VNET` DNS servers gebruiken. Alle `VNETs` hier gebruiken de `AZF` als DNS server. De `AZF` gebruikt echter niet het `VNET` als DNS server, maar CloudFlare DNS en Google DNS.  
    >
    > De `VNET` DNS server is alleen bereikbaar vanuit de VNET. VM's kunnen dus niet de DNS server van een ander `VNET` gebruiken. Ook kun je niet vanuit een on-prem omgeving `private DNS zones` te resolven. 
    >
    > Om dit te kunnen in een productie omgeving, moet het resolven van de `private DNS zones` via een forwarder lopen in de `VNET`.
    >
    >**De enige reden dat de zone gekoppeld is aan de spokes, is dus voor de auto registratie, niet DNS resolving.**

    </details>

6. Pas de `AZF` DNS instellingen aan zodat resolving werkt. Pas de `VNET` DNS instellingen **NIET** aan.

## Load Balancing

De applicatie in spoke 01 moet redundant worden uitgevoerd. Een [`load balancer`](https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview) moet de load kunnen verdelen en bij uitval moet de uitgevallen server uit de pool gehaald worden.

1. Deploy nog een server met de boot script. Zie dag 1 indien je hulp nodig hebt.
    * Geen `NSG` en `public IP`.
    * Als de `NSG` de vorige keer op de subnet was toegepast, hoef je de bestaande `NSG` niet handmatig te koppelen.
1. [Rol](https://docs.microsoft.com/en-us/azure/load-balancer/quickstart-load-balancer-standard-internal-portal?tabs=option-1-create-internal-load-balancer-standard) een `load balancer` uit.
    * Type: Internal
    * SKU: Standard (Basic kan niet, want de VMs maken geen gebruik van een `availability set`)
    * IP address assignment: Dynamic
1. Configureer de `load balancer`.
    * Controleer de frontend IP configuration
    * Maak een backend pool aan. Zet de VMs erin
    * Maak een zinnige health probe om te controleren of de server werkt.
    * Maak een load balancing rule aan.
    * Session persistance: naar eigen keus

    > <details><summary>Floating IP/Direct Server Return</summary>
    >
    > Azure kent het concept van een floating IP niet. Gratuitous ARPs kunnen niet in een VNET. Zelfs normale ARPs worden niet gebroadcast maar gevijnsd door de onderliggende hypervisors. Een ander IP adres configureren in de `VM` dan dat geconfigureerd is op de `NIC` via de portal, maakt het mogelijk onbereikbaar.
    >
    > Om dit toch mogelijk te maken, kan een `load balancer` gebruikt worden met floating IP/Direct Server Return aan. Hiermee voert de LB geen DNAT uit. De frontend IP wordt as-is doorgegeven aan de achterliggende `VMs`. 
    >
    > Dit betekent dat de `VMs` de IPs moeten accepteren. Voor een firewall kan dit in de vorm zijn van een VIP. In een Windows Failover Cluster is dit een cluster IP.

    </details>

1. Bezoek de webserver/API via de management server.
    * Afhankelijk van de gekozen type session persistence kan je verschillende hosts tegen komen of steeds dezelfde.
1. `LB` adressen komen niet automatisch in DNS. Maak handmatig een DNS record aan voor het `LB` IP.
1. Test de interne werking op basis van IP en DNS
1. Maak een nieuwe `NAT rule collection` aan en sta inbound tcp/80 verkeer richting de `LB` IP toe. Indien de `NSGs` het toe staan, zou de website ook extern benaderbaar moeten zijn.

## Private Links 

Er kunnen gevoelige gegevens in de log `storage account` terecht komen. BY Verzekeringen wil graag dat de log `storage account` alleen intern vanuit het `VNET` benaderbaar is. Het verkeer moet in het `VNET` blijven en niet over de Azure backbone gaan. Dit betekent dat gebruik wordt moet worden gemaakt van [`Private Links`](https://docs.microsoft.com/en-us/azure/private-link/private-link-overview) en niet [`Service Endpoints`](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview).

1. Maak een nieuwe subnet aan in spoke 2 voor de private endpoint (niet noodzakelijk, wel overzichtelijker).
1. Ga naar de `Storage account` > Networking > Private endpoint connections en [voeg een private endpoint toe](https://docs.microsoft.com/en-us/azure/private-link/tutorial-private-endpoint-storage-portal#create-storage-account-with-a-private-endpoint).
    * Selecteer blob sub-resource
    * Schakel `Private DNS Zone` integration uit. Dit doen we handmatig.
1. Resolve waar de DNS record van je `storage account` nu naar verwijst.
    * linux: `dig <naam>.blob.core.windows.net`
    * windows:  `Resolve-DnsName <naam>.blob.core.windows.net`

    > **Note:** De `storage account` heeft nu een NIC in het subnet. Het is intern benaderbaar op IP. [De DNS record wijst intern nog steeds naar de publieke IP](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns).]

    > <details><summary>Creatief met private links</summary>
    >
    > Niet alleen resources zoals `storage accounts` en `key vaults` kunnen `private links` bevatten, maar ook `load balancers`. Het is mogelijk om een dienst met een `load balancer` in een apart `VNET` te plaatsen. Deze `load balancer` kan dan door middel van `private link` aan een ander netwerk gekoppeld worden. Dit kan zelfs een `VNET` zijn van een andere organisatie. Dit alles zonder VPNs of een andere connectiviteit oplossing.

    </details>

Om de resolving intern correct te krijgen, moet een specifieke `private DNS zone` worden aangemaakt
1. Maak een nieuwe `private DNS Zone` genaamd [privatelink.blob.core](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration).windows.net.
1. Koppel deze aan het hub VNET
    * Schakel auto registration uit

    > **Note:** De zone hoeft alleen gekoppeld te worden aan VNETs waar het resolved gaat worden. Aangezien de enige plek waar resolving plaats vindt, de `AZF` is, hoeft het dus alleen op de core.

1. Ga naar de Private Endpoint van de `Storage Account` > DNS configuration > Add configuration
    * Selecteer de recommended zone
1. Resolve de DNS record intern vanuit jouw management VM.
1. Resolve de DNS record extern.

## Firewallen van private links

De `storage account` is nu zowel intern als extern benaderbaar. Externe toegang moet conform de eisen dicht worden gezet.

1. Browse via de `portal` naar je `storage account` en open de blob storage. Probeer dit via de management VM als een externe computer.
    * Storage account > Containers > open een willekeurige container of maak er een aan.
    * Dit zou vanuit beide locaties moeten lukken.
1. Ga naar de `storage account` > Networking > Firewalls and virtual networks en selecteer Selected networks
    * Zorg ervoor dat '[Allow trusted Microsoft Services](https://docs.microsoft.com/en-us/azure/storage/common/storage-network-security?tabs=azure-portal#grant-access-to-trusted-azure-services) to access this storage account' aan staat
    * Wijzig voor de rest niks. Dit blokkeert overige internet verkeer.

    > <details><summary>Trusted Microsoft Services</summary>
    >
    > Microsoft diensten kunnen nooit een resource benaderen via een Private Link. Als een resource ook door MS diensten vanuit het internet benaderd moeten worden, moet de optie aan. 
    >
    > Dit staat netwerktechnisch verkeer toe vanuit alle Microsoft Services, ook die van andere klanten. Om erbij te kunnen zouden deze toegang moeten hebben tot de juiste credentials en is dit dus geen probleem.

    </details>

De `storage account` is nu alleen intern benaderbaar. Dit is te testen door weer de cointainers te openen. Logs kunnen wel nog steeds gearchiveerd worden door Azure, doordat Microsoft Services er naartoe mogen wegschrijven.

## Voorbereiding volgende opdracht

> **Note:** Een Virtual Network Gateway heeft een `public IP` nodig en een specifiek subnet.

Deploy alvast een Virtual Network Gateway in de core voor de volgende keer. 
* VPN
* Route-based
* VpnGw1
* In hub uitrollen

> **Note:** De VNG uitrollen duurt lang.

## Optioneel: Traffic Manager

[`Traffic Manager`](https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-overview) is een DNS `load balancer` dat op wereldwijde schaal verkeer kan afhandelen. Het is bedoeld voor load balancing tussen datacentra. We gaan in deze opdracht een `Traffic Manager profile` aanmaken dat verkeer tussen alle afdelingen verdeelt.

1. Maak een nieuwe `Traffic Manager profile` aan.
    * [Routing method](https://docs.microsoft.com/en-us/azure/traffic-manager/traffic-manager-routing-methods): Weighted
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
    * Gebruik Azure endpoints en kies een van de `AZF` IPs.
1. Herhaal dit voor de overige afdelingen.
1. Test nu het browsen naar de website vanuit een externe client door gebruik te maken van jouw DNS name, te vinden bij 'Overview'.
1. Optioneel: Speel met de routing method. Gebruik eventueel web proxies om verkeer vanuit andere regios te laten komen.
