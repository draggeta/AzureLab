# Dag 1

Jouw afdeling wil twee web applicaties in de cloud gaan draaien. Elke applicatie moet in een aparte `Virtual Network` terecht komen. Er moet ook een management (hub) `Virtual Network` en server komen waar vandaan de twee applicaties beheerd kunnen worden.
Alle servers moeten gehardened worden door middel van `NSGs`. De enige server die direct vanuit het internet benaderbaar moet zijn, is de management server. 

## Uitrollen Resource Groups

Elke `Virtual Network` komt in een eigen resource group terecht. Dit voor overzicht. Maak drie resource groups aan in `West Europe`.

## Uitrollen Virtual Networks en peerings

Het netwerk moet bestaan uit twee spokes gekoppeld aan een hub netwerk waar vandaan beheer wordt uitgevoerd. De applicaties moeten niet met elkaar kunnen communiceren.

1. Bouw een core `Virtual Network` met een /16 IP.
1. Rol de twee spoke `Virtual Networks` uit, elk met een eigen /16.
1. Gebruik `VNET Peering` om de spoke netwerken aan de core `Virtual Network` te koppelen. 
    * Sta verkeer naar remote netwerken toe.
    * Sta verkeer van andere netwerken toe.

## Uitrollen management server

Rol een kleine management server uit. De server moet vanuit het internet bereikbaar zijn, maar alleen voor werknemers. Er is nog geen client VPN oplossing aanwezig en die komt er ook niet snel. Daarnaast moeten de kosten gedrukt worden. Schakel apparaten automatisch uit wanneer ze niet nodig zijn.

> **NOTE:** Gebruik `Standard_SSD` of `Standard_HDD` schijven. Gebruik geen Premium Disks.  

> **NOTE:** Kies voor de size van de management server `Standard_B2ms`. De B-serie is goedkoop en bedoeld voor workloads met weinig load. Bij CPU gebruik lager dan 10% spaar je credits. Deze credits kan je inzetten om met CPU te bursten tijdens piek momenten.

1. Deploy een Ubuntu 18.04 of Windows Server 2019  management server. 
    * Geef de VM geen `Public IP`. Deze gaan we handmatig toevoegen.
    * Geef de VM geen `Network Security Group`. Deze gaan we handmatig toevoegen. 
    * Schakel `Auto-shutdown` in en zet deze op 19:00 UTC+1. Dit kan ook nadat de VM is aangemaakt.
1. Maak een `NSG` voor management.
    * Sta inbound RDP vanuit jouw publieke IP adres toe. Dit gaan we gebruiken voor management.
    * Overig inbound internet verkeer mag niet.
    * Blokkeer interne inbound verkeer niet!
1. Koppel de `NSG` aan het subnet.
1. Maak een `Public IP` en koppel deze aan de NIC van de management VM.
    * Basic SKU
    * Dynamic assignment (IP wisselt bij deallocaten VM).
    * Geef het een DNS label, hoef je geen IP te gebruiken.

De VM heeft nu een rechtstreekse internet verbinding. Ook zonder de publieke IP zou outbound internet verkeer mogelijk zijn. [Verbind](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/connect-logon) met de management VM.
* De publieke IP is te achterhalen: 
    * linux: `curl https://api.ipify.org`
    * windows: `irm https://api.ipify.org`

> **Note:** Bij problemen kan er gebruik worden gemaakt van de [`IP flow verify`](https://docs.microsoft.com/en-us/azure/network-watcher/diagnose-vm-network-traffic-filtering-problem#use-ip-flow-verify) of [`NSG diagnostic`](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-network-configuration-diagnostics-overview) functionaliteit van de [`Network Watcher`](https://docs.microsoft.com/en-us/azure/network-watcher/) om de `NSGs` te troubleshooten. 
>* `IP flow verify` geeft aan of de `NSGs` gekoppeld aan de VM het verkeer toe staan
> * `NSG diagnostic` controleert alle `NSGs` in het pad. Het is een betere tool dan `IP flow verify`, maar vereist rechten om alle `NSGs` in het pad te kunnen lezen.

## Uitrollen web servers

Twee servers worden uitgerold, elk in hun eigen netwerk. De content van beide servers mag openbaar zijn. SSH mag alleen vanuit de management server.

> **NOTE:** gebruik Standard SSD of Standard HDD schijven. Gebruik geen Premium.  

> **NOTE:** Kies voor de size van de web server Standard_B1s.

1. Deploy twee Ubuntu 18.04 VMs, elk in een van de twee spokes. De VMs doen dienst als web servers.
    * Geef de VMs geen `Public IP`.
    * Geef de VMs geen `Network Security Group`. Deze gaan we apart toevoegen.
    * Schakel `Auto-shutdown` in en zet deze op 19:00 UTC+1.
    * Gebruik de volgende custom script om de webservers te configureren.
      * Custom scripts zijn ook te gebruiken voor bootstrappen netwerk apparatuur.

```bash
#!/bin/bash

# license: https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh
apt-get update -y && apt-get upgrade -y
apt-get install -y nginx
echo "Finance API server on" $HOSTNAME "!" | sudo tee -a /var/www/html/index.html
```

```bash
#!/bin/bash

# license: https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh
apt-get update -y && apt-get upgrade -y
apt-get install -y nginx
echo "Risk Assessement API server on" $HOSTNAME "!" | sudo tee -a /var/www/html/index.html
```

2. Maak een `NSG` aan in de core resource group.
    * Sta inbound tcp/22 vanuit de management server toe. Sta tcp/80 toe vanuit de Internet tag. Poort tcp/22 moet dicht staan vanuit alle andere apparaten.
> **Note:** Je kunt een `NSG` dus koppelen aan meerdere subnets, zelfs in meerdere `Virtual Networks`. Ze moeten wel in een subscription zitten.
3. Koppel de `NSG` aan de subnetten waar de web servers in zitten.
1. Bezoek de websites intern via de management VM.
1. Bepaal de verkeersstromen
    * Verkeer tussen spokes en hub
    * Verkeer tussen spokes
    * Verkeer richting internet vanuit de webservers

> **Note:** De [`Next hop`](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-next-hop-overview) functionaliteit van de `Network Watcher` geeft informatie over waar verkeer van een VM naartoe gaat. Gebruik dit om verkeersstromen te verifieren.

## Logging en archivering

De Hollandsche Bank eist dat BY verkeer dat langs komt kan analyseren voor 30 dagen en archiveert voor 90 dagen. Hiervoor kan gebruik worden gemaakt van de `Diagnostics settings` en/of de `NSG flow logs` van de `NSGs`.

1. Deploy een `Storage account`. De type maakt niet echt uit, zolang het `blob` storage ondersteunt en niet de `premium` SKU gebruikt. De `storage account` gaat gebruikt worden voor log opslag
1. Deploy een `Log Analytics Workspace`. De workspace gaat gebruikt worden voor analyse van het verkeer.
1. Ga naar de aangemaakte `NSGs` en configureer de `NSG` flow logs. 
    * Flow Logs version: Version 2
    * Retention: Conform DHB eis
    * Traffic Analytics status: On
    * Processing interval: Every 10 mins

> **Note:** Over ongeveer 10-15 minuten kan gebruik worden gemaakt van de `Traffic Analytics` functionaliteit van de `Network Watcher`. Aangezien het einde dag is, kan hier prima de volgende keer naar gekeken worden.
