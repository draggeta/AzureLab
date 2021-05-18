
# Dag 3 - Load balancing en DNS

De omgeving vordert en interne IP adressen onthouden wordt vervelend. Ook zullen de servers binnenkort redundant uitgevoerd moeten worden, want downtime tijdens upgrades is steeds minder acceptabel.

## Private DNS Zones

We gaan een private DNS zone maken waar we alles in kunnen registeren. De registratie van VMs moet automatisch.

De zones per lab:

| naam | DNS zone |
| --- | --- |
| Rene | rene.by.cloud |
| Rob | rob.by.cloud |
| Ruud | ruud.by.cloud |
| Tamim | tamim.by.cloud |

1. Maak een Private DNS Zone aan.
1. Koppel de DNS Zone aan elke VNET waar autoregistratie plaats moet vinden (hub en beide spokes).
1. Controleer in overview of de VMs geregistreerd zijn. Wahct totdat ze allemaal erin staan.
1. Resolve nu een van de servers:
    * linux: dig spoke01.naam.by.cloud
    * linux: Resolve-DnsName spoke01.naam.by.cloud
1. Dit werkt niet, waarom?

> **Note**: Om een zone gekoppeld aan een VNET te kunnen resolven, moet je de VNET DNS servers gebruiken. Alle VNETs hier gebruiken de AZF als DNS server. De AZF gebruikt echter niet het VNET als DNS server, maar CloudFlare DNS en Google DNS.  
De enige reden dat de zone gekoppeld is aan de spokes, is dus voor de auto registratie, niet DNS.

6. Pas de AZF DNS instellingen aan zodat resolving werkt. Pas de VNET DNS instellingen NIET aan.

## Load Balancing

De applicatie in spoke 01 moet redundant worden uitgevoerd. Een loadbalancer moet de load kunnen verdelen en bij uitval moet de uitgevallen server uit de pool gehaald worden.

1. Deploy nog een server met de boot script. Zie dag 1 indien je hulp nodig hebt.
    * NSG en Public IP mogen beiden uit
    * Als de NSG de vorige keer op de subnet was toegepast, hoef je de bestaande NSG niet handmatig te koppelen.
1. Rol een Load Balancer uit
    * Type: Internal
    * SKU: Standard (basic kan niet want geen availability set)
    * IP address assignment: Dynamic
1. Configureer de Load Balancer
    * Controleer de frontend IP configuration
    * Maak een backend pool aan. Zet de VMs erin
    * Maak een zinnige health probe om te controleren of de server werkt.
    * Maak een load balancing rule aan.
1. Bezoek de website
1. LB adressen komen niet automatisch in DNS aan. Maak handmatig een DNS record aan voor het LBIP.
1. Test de interne werking op basis van IP en DNS
1. Maak een nieuwe NAT rule collection aan en sta inbound tcp/80 verkeer richting de LBIP toe. Indien de NSG's het toe staan, zou de website ook extern benaderbaar moeten zijn.

## Private Link resources

Er kunnen gevoelige gegevens in de log storage account terecht komen. BY Verzekeringen wil graag dat de log storage account alleen intern vanuit het VNET benaderbaar is. Het verkeer moet in het VNET blijven en niet over de Azure backbone gaan (geen Service Endpoint dus).

1. Maak een nieuwe subnet aan in spoke 2 voor de private endpoint (niet noodzakelijk, wel overzichtelijker)
1. Ga naar de Storage account > Networking > Private endpoint connections en voeg een private endpoint toe.
    * Selecteer blob sub-resource
    * Schakel Private DNS Zone integration uit. Dit gaan we handmatig doen.
1. Resolve waar de DNS record van je storage account nu naar verwijst
    * linux: dig _**naam**_.blob.core.windows.net
    * windows:  Resolve-DnsName _**naam**_.blob.core.windows.net

> **Note:** De Storage Account heeft nu een NIC in het subnet. Het is intern benaderbaar op IP nu. De DNS record wijst intern nog steeds naar de publieke IP.

Om de resolving intern correct te krijgen, moet een specifieke Private DNS zone worden aangemaakt
1. Maak een nieuwe Private DNS Zone genaamd privatelink.blob.core.windows.net.
1. Koppel deze aan het hub VNET
    * Schakel auto registration uit

> **Note:** De zone hoeft alleen gekoppeld te worden aan VNETs waar het resolved gaat worden. Aangezien de enige plek waar resolving plaats vindt, de AZF is, hoeft het dus alleen op de core.

3. Ga naar de Private Endpoint van de Storage Account > DNS configuration > Add configuration
    * Selecteer de recommended zone
1. Resolve de DNS record intern
1. Resolve de DNS record extern

De Storage Account is nu zowel intern als extern benaderbaar. Dit moet dicht.

1. Ga naar de Storage account > Networking > Firewalls and virtual networks en selecteer Selected networks
    * Zorg ervoor dat 'Allow trusted Microsoft Services to access this storage account' aan staat
    * Wijzig voor de rest niks

De Storage Account is nu alleen intern benaderbaar. DIt is te testen met Storage Explorer. Logs kunnen wel nog steeds gearchiveerd worden door Azure, doordat Microsoft Services er naartoe mogen wegschrijven.

## Voorbereiding volgende opdracht

> **Note:** Een Virtual Network Gateway heeft een Public IP nodig en een specifiek subnet.

Deploy alvast een Virtual Network Gateway in de core voor de volgende keer. 
* VPN
* Route-based
* VpnGw1
* In hub uitrollen

> **Note:** De VNG uitrollen duurt lang. Je kan nu afsluiten.
