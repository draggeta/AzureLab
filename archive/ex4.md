# Dag 4 - ExpressRoute/VPN

Zoals te verwachten was, moeten de afdelingen toch met elkaar kunnen communiceren. Om de afzonderlijke afdelingen aan elkaar te knopen heeft BY Verzekeringen een apart netwerk gemaakt dat als knooppunt dient: de Secure Transit Hub (STH). 

BY wil geen handwerk in het bekend maken van routes. Gebruik hiervoor BGP. Elke afdeling wordt als een eigen Autonomous System gezien. Hierbij worden de [toegestane ASNs](https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-bgp-overview#what-asns-autonomous-system-numbers-can-i-use) gebruikt.

De ASNs per afdeling:

| naam | ASN |
| --- | --- |
| Rene | 65521 |
| Rob | 65525 |
| Ruud | 65529 |
| Tamim | 65533 |
| STH | 65516 |

## Inschakelen BGP

1. Ga naar je Virtual Network Gateway > Configuration > Configure BGP
    * Configureer jouw ASN op de VNG
1. Maak een Local Network Gateway aan. De Local Network Gateway is het apparaat aan de andere kant waar je een VPN verbinding mee wilt maken.
    * Configureer als IP de IP van de STH: `40.68.217.9`
    * Gebruik 65516 als ASN voor de "Secure Transit Hub"
    * Gebruik 10.108.2.254 als de BGP Peer IP
    * Vul geen address spaces in. BGP zal de routes uitwisselen.
1. Maak een Connection aan. Een Connection is de verbinding tussen jouw VNG en een LNG. Hier worden alle VPN instellingen ingesteld.
    * Connection Type: Site-to-site
    * PSK: `BY_Verzekeringen`
    * Enable BGP: `true`
1. Wacht tot de VPN up komt
    * Gebruik `VPN troubleshoot` en `VPN Connection Packet Capture` onder de Connection om de verbinding te troubleshooten indien het niet werkt.
1. Controleer de peerings en de geleerde routes op de VNG
<!-- # TODO: Betere beschrijving! -->
1. Verifieer dat je vanuit jouw core netwerk een ander apparaat in een apparaat in een ander core netwerk kan pingen
1. Kun je pingen vanuit een spoke apparaat naar een apparaat in een andere afdeling?
    * `traceroute` vanuit VMs
    * Controleer de geleerde routes, staan jouw spoke routes ertussen?

    > <details><summary>Peerings en netwerk resources</summary>
    >
    > Als het goed is zijn er alleen core routes geleerd door de VNG. Dit heeft te maken met het feit dat peerings niet direct gebruik kunnen maken van een Virtual Network Gateway of ExpressRoute Gateway. Om dit te kunnen, moet de peering aangepast worden aan beide zijde.

    </details>

## Spoke VPN Toegang

Voer de onderstaande acties uit voor alle peerings in de core VNET.

1. VNET > Peerings > open peering
1. Vink aan `Use this virtual network's gateway or Route Server` > Save

Voer de onderstaande acties uit voor al jouw spoke VNETs.

1. VNET > Peerings > open de peering 
1. Vink aan `Use the remote virtual network's gateway or Route Server` > Save

    > <details><summary>Route server</summary>
    >
    > De route server optie is nog in preview. De route server is een Azure dienst die BGP sessies op kan zetten om zo routes uit te wisselen. Dit is te gebruiken om bijvoorbeeld routes tussen een SD-WAN wolk en VNETs uit te wisselen.

    </details>

1. Controleer de learned routes.
1. Controleer connectiviteit, mits de andere afdelingen hun koppeling opgeleverd hebben.
    * `ping`
    * `traceroute`
    * `curl` (linux) of `irm` (windows)
1. Er is geen echte DNS server die conditional forwarding kan doen, maar DNS resolution werkt!
    * linux: `dig @<ip-remote-dns-server> <server>.<naam>.by.cloud +short`
    * windows `Resolve-DnsName <server>.<naam>.by.cloud -Server <ip-remote-dns-server>`

## DNS resolving

Met een echte DNS server zou conditional forwarding gebruikt kunnen worden om de overige netwerken te resolven. We gaan dit simuleren door de Private DNS Zones van de andere afdelingen te koppelen aan jouw core netwerk. Dit werkt alleen omdat alles in dezelfde subscription zit en hierdoor de Private DNS Zones beschikbaar zijn voor ons.

Voer het onderstaande uit voor alle DNS zones

1. Private DNS Zone > Virtual network links > Add
1. Koppel het aan jouw core VNET.
    * Gebruik **GEEN** auto registration. We willen niet dat de servers in deW core zich registreren in de DNS zone van een andere afdeling
1. Resolve een server/load balancer in de zone vanuit een van jouw VMs
    * linux: `dig <server>.<naam>.by.cloud +short`
    * windows `Resolve-DnsName <server>.<naam>.by.cloud`

## Aanpassen address space

BY verzekeringen groeit hard en in Spoke A bij alle afdelingen beginnen de IP adressen op te raken. BY wil graag dat een /17 uit de overgebleven /16 uit de supernets van de afdelingen ingezet gaat worden voor Spoke A.

1. VNET > Address space
1. Voeg de /17 toe aan de address space > Save

    > <details><summary>Route server</summary>
    >
    > Het komt erop neer dat de VNET Peering verwijderd moet worden voordat aanpassingen gedaan kunnen worden aan een address space. Er is een private preview voor de funtionaliteit om address space aanpassingen te kunnen doen zonder de peerings te verbreken.

    </details>

1. VNET > Peerings
1. Verwijder de peering. 
    * Via de portal wordt meteen de peering aan de andere zijde verwijderd.
1. Pas de address space aan.
1. Maak de peering weer aan.
1. Controleer de geadverteerde routes.

<!-- ## Client/point-to-site VPN -->
