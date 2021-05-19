# Dag 1 - Basis netwerken

Jouw afdeling wil twee web applicaties in de cloud gaan draaien. Elke applicatie moet in een aparte `virtual network` terecht komen. Er moet ook een management (hub) `virtual network` en server komen waar vandaan de twee applicaties beheerd kunnen worden.
Alle servers moeten gehardened worden door middel van `network security groups`. De enige server die direct vanuit het internet benaderbaar moet zijn, is de management server. 

## Uitrollen Resource Groups

Elke `virtual network` komt in een eigen resource group terecht. Dit helpt met het overzicht. Maak drie resource groups aan in `West Europe`.

## Uitrollen Virtual Networks en peerings

Het netwerk moet bestaan uit twee spokes gekoppeld aan een hub netwerk waar vandaan beheer wordt uitgevoerd. De applicaties moeten niet met elkaar kunnen communiceren.

1. Bouw een core `virtual network` met een /16 IP.
1. Rol de twee spoke `virtual networks` uit, elk met een eigen /16.
1. Nadat de VNET is aangemaakt, kan je onder de `virtual network` `Peering` selecteren en een [peering toevoegen](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering#create-a-peering) om de spokes netwerken aan de core `virtual network` te koppelen. 
    * Sta verkeer naar remote netwerken toe.
    * Sta verkeer van andere netwerken toe.

><details>
>  <summary>VNET peering</summary>  
>
> Peerings verbinden twee [`VNETs`](a "Virtual Networks") met elkaar. De peering moet in beide VNETs worden aangemaakt. In de [`portal`](a "Azure Portal") gebeurt dit automatisch wanneer je rechten hebt op beide VNETs. Doe je dit op een andere wijze (API/PowerShell/Azure CLI), moet elke zijde van de peering los worden aangemaakt.

</details>

## Uitrollen management server

Rol een kleine management server uit. De server moet vanuit het internet bereikbaar zijn, maar alleen voor werknemers. Er is nog geen client VPN oplossing aanwezig en die komt er ook niet snel. Daarnaast moeten de kosten gedrukt worden. Schakel apparaten automatisch uit wanneer ze niet nodig zijn.

> **NOTE:** Gebruik `Standard_SSD` of `Standard_HDD` schijven. Gebruik geen `premium` disks.  

> **NOTE:** Kies voor de size van de management server `Standard_B2ms`. 

> <details><summary>B-serie VMs</summary>
>
> De B-serie is goedkoop en bedoeld voor workloads met een over het algemeen lage load en korte pieken. Bij CPU gebruik lager dan 5-10% spaar je credits op. Deze credits kan je inzetten om met CPU te bursten tijdens piek momenten.

</details>

1. Deploy een Ubuntu 18.04 of Windows Server 2019  management server. 
    * Maak geen gebruik van `availability zones` of `availability sets`.
    * Geef de VM geen `public IP`. Deze gaan we handmatig toevoegen.
    * Geef de VM geen `network security group`. Deze gaan we handmatig toevoegen. 
    * Schakel `Auto-shutdown` in en zet deze op 19:00 in jouw lokale tijdzone. Dit kan ook nadat de VM is aangemaakt.
    > <details><summary>Availability</summary>
    >
    > Basic SKU IPs werken alleen met resources die niet `zone  redundant` zijn. Dit is de reden waarom de VM geen gebruik maakt van `availability zones`. Basic IPs werken wel met `availability sets`. Echter hebben `availability sets` weinig nut (en zelfs  nadelen) als je maar één VM hebt draaien. Hetzelfde geldt voor `zones`.
    
    </details>

1. Maak een `NSG` voor management.
    * Sta inbound RDP vanuit jouw publieke IP adres toe. Dit gaan we gebruiken voor management.
    * Overig inbound internet verkeer mag niet.
    * Blokkeer interne inbound verkeer niet!
    > <details><summary>Network Security Groups</summary>
    >
    > NSG rules kunnen gebruik maken van `tags` om bepaalde sources en destinations aan te duiden. Een van de interessante tags is de `VirtualNetwork` tag. Deze tag staat niet alleen verkeer vanuit jouw `VNET` toe, maar ook alle direct gepeerde `VNETs` en alle netwerken die door een `virtual network gateway` of `ExpressRoute gateway` worden geleerd.

    </details>  

1. Koppel de `NSG` aan het subnet.
1. Maak een `public IP` en koppel deze aan de NIC van de management VM.
    * Basic SKU
    * Dynamic assignment (IP wisselt bij deallocaten VM).
    * Geef het een DNS label. Hierdoor is het intikken van een IP niet meer nodig.
  
  De VM heeft nu een rechtstreekse internet verbinding. Ook zonder de publieke IP zou outbound internet verkeer mogelijk zijn. [Verbind](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/connect-logon) met de management VM.
* De publieke IP is te achterhalen: 
    * linux: `curl https://api.ipify.org`
    * windows: `irm https://api.ipify.org`

> <details><summary>NSG verificatie</summary>
>
> Bij problemen kan er gebruik worden gemaakt van de [`IP flow verify`](https://docs.microsoft.com/en-us/azure/network-watcher/diagnose-vm-network-traffic-filtering-problem#use-ip-flow-verify) of [`NSG diagnostic`](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-network-configuration-diagnostics-overview) functionaliteit van de [`Network Watcher`](https://docs.microsoft.com/en-us/azure/network-watcher/) om de `NSGs` te troubleshooten. 
>* `IP flow verify` geeft aan of de `NSGs` gekoppeld aan de VM het verkeer toe staan
> * `NSG diagnostic` controleert alle `NSGs` in het pad. Het is een betere tool dan `IP flow verify`, maar vereist rechten om alle `NSGs` in het pad te kunnen lezen.

</details>


## Uitrollen web servers

Twee servers worden uitgerold, elk in een eigen spoke netwerk. De servers zullen APIs aanbieden voor financiele gegevens en risk assessments. De APIs horen publiekelijk beschikbaar te zijn in de toekomst. Inbound SSH verkeer mag alleen vanuit de management server.

> **NOTE:** gebruik `Standard_SSD` of `Standard_HDD` schijven. Gebruik geen `premium` disks.  

> **NOTE:** Kies voor de size van de web server `Standard_B1s`.

1. Deploy twee Ubuntu 18.04 VMs, elk in een van de twee spokes. De VMs doen dienst als web servers.
    * Geef de VMs geen `public IP`.
    * Geef de VMs geen `network security group`. Deze gaan we apart toevoegen.
    * Schakel `Auto-shutdown` in en zet deze op 19:00 UTC+1.
    * Bij de `Advanced` tab tijdens de configuratie kan een custom script worden ingevoerd. Hiermee gaan we de servers configureren.
      * Custom scripts zijn ook te gebruiken voor het bootstrappen van bijv. netwerk apparatuur.

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
    > <details><summary>NSG in core resource group</summary>
    >
    > Dit is om aan te tonen dat veel resource is Azure hergebruikt kunnen worden, zolang ze zich in dezelfde subscription bevinden. Je kunt een `NSG` dus koppelen aan meerdere subnets, zelfs als de subnets in meerdere `virtual networks` staan. 

    </details>

3. Koppel de `NSG` aan de subnetten waar de web servers in zitten.
1. Bezoek de websites intern via de management VM.
1. Controleer hoe de verkeersstromen lopen:
    * Verkeer tussen spokes en hub
    * Verkeer tussen spokes
    * Verkeer richting internet vanuit de webservers

    > <details><summary>Standaard route tabellen in Azure</summary>
    >
    > Azure `virtual networks` hebben [standaard een null route](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview#default) staan voor een deel van de RFC1918 prefixes (10.0.0.0/8, 192.168.0.0/16) en de RFC6598 prefix (100.64.0.0/10). Door een `address space` toe te voegen worden specifiekere routes aangemaakt en de route tabel overschreven.
    >
    > Directe `VNET peers` voegen elkaars `address spaces` toe. Geleerde routes worden echter niet doorgegeven aan andere peers. Dit betekent dat spoke A geen routes leert naar spoke B via het core netwerk.

    </details>

    > <details><summary>Next hop/effective routes</summary>
    >
    > De [`Next hop`](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-next-hop-overview) functionaliteit van de `Network Watcher` of de `Effective routes` functionaliteit van een `NIC` geeft informatie over waar verkeer van een VM naartoe gaat. Gebruik dit om verkeersstromen te verifieren.

    </details>

## Logging en archivering

De Hollandsche Bank eist dat BY verkeer dat langs komt kan analyseren voor 30 dagen en archiveert voor 90 dagen. Hiervoor kan gebruik worden gemaakt van de `Diagnostics settings` en/of de `NSG flow logs` van de `NSGs`.

1. Deploy een `Storage account`. De `storage account` gaat gebruikt worden voor log archivering.
    * `Standard` SKU, niet `premium`. 
    * Redundancy maakt niet uit. `LRS` is voor een lab de beste * Gebruik geen `private endpoint` of `service endpoint`. De storage account moet vanuit het internet bereikbaar blijven.
1. Deploy een `Log Analytics Workspace`. De workspace gaat gebruikt worden voor analyse van het verkeer.
1. Ga naar de aangemaakte `NSGs` en configureer de `NSG` flow logs. 
    * Flow Logs version: Version 2
    * Retention: Conform DHB eis
    * Traffic Analytics status: On
    * Processing interval: Every 10 mins

> **Note:** Over ongeveer 10-15 minuten kan gebruik worden gemaakt van de `Traffic Analytics` functionaliteit van de `Network Watcher`. Aangezien het einde dag is, kan hier prima de volgende keer naar gekeken worden.
