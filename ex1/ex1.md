# Dag 1 - Basis netwerken

BY wil web applicaties in de cloud gaan draaien. De webapplicatie moet geografisch redundant neergezet worden. Er moet ook een management (hub) `virtual network` en server komen waar vandaan de applicaties beheerd kunnen worden.
Alle servers moeten gehardened worden door middel van `network security groups`. De enige server die direct vanuit het internet benaderbaar moet zijn, is de management server. 

## Uitrollen hub/management netwerk

> **NOTE:** Elke `virtual network` komt in een eigen resource group terecht. Dit helpt met het overzicht.

> **NOTE:** Gebruik `Standard_SSD` of `Standard_HDD` schijven. Gebruik geen `premium` disks.

> **NOTE:** Kies voor de size van de management server `Standard_B2ms`.

Als eerst wordt het management netwerk opgezet. Vanuit hier kunnen beheerders servers benaderen en beheren. Vervolgens rollen we een kleine kleine management server uit. De server moet vanuit het internet bereikbaar zijn, maar alleen voor werknemers. Er is nog geen client VPN oplossing aanwezig en het heeft geen prioriteit vanuit de business. Daarnaast moeten de kosten gedrukt worden. Schakel apparaten automatisch uit wanneer ze niet nodig zijn.

1. Bouw een core `virtual network` met een /16 IP.

1. Deploy een Windows Server 2022 management server. 
    * Maak geen gebruik van `availability zones` of `availability sets`.
    * Geef de VM geen `public IP`. Deze gaan we handmatig toevoegen.
    * Geef de VM geen `network security group`. Deze gaan we handmatig toevoegen. 
    * Schakel `Auto-shutdown` in en zet deze op 00:00 in jouw lokale tijdzone. Dit kan ook nadat de VM is aangemaakt.
    > <details><summary>B-serie VMs</summary>
    >
    > De B-serie is goedkoop en bedoeld voor workloads met een over het algemeen lage load en korte pieken. Bij CPU gebruik lager dan 5-10% spaar je credits op. Deze credits kan je inzetten om met CPU te bursten tijdens piek momenten.

    </details>

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
    > NSG rules kunnen gebruik maken van `tags` om bepaalde sources en destinations aan te duiden. Een van de interessante tags is de `VirtualNetwork` tag. Deze tag staat niet alleen verkeer vanuit jouw `VNET` toe, maar ook alle direct gepeerde `VNETs` en alle netwerken die door een `virtual network gateway`, `ExpressRoute gateway` of `route server` worden geleerd.

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
> * `NSG diagnostic` controleert alle `NSGs` in het pad. Het is een betere tool dan `IP flow verify`, maar vereist rechten om alle `NSGs` in het pad te kunnen lezen. Het geeft niet weer of het verkeer door een NVA mag. Ook niet de `Azure firewall`.

</details>

## Uitrollen spoke/applicatie netwerken

Een ontwerp doelstelling is dat voor applicaties, zoveel mogelijk gebruik wordt gemaakt van de redundantie mogelijkheden van Azure. Applicatie servers moeten verspreid worden over availability zones en uitgerold over twee regio's. De secundaire regio staat standby.

Het netwerk moet bestaan uit twee spokes gekoppeld aan een hub netwerk waar vandaan beheer wordt uitgevoerd. De webservers moeten niet met elkaar kunnen communiceren, maar wel met gedeelde diensten in de hub.

> **NOTE:** Dit is een lab en we hebben geen ruimte om veel servers en databases neer te zetten. We gaan er even van uit dat data tussen de regio's automagisch gerepliceerd wordt. Een voorbeeld hiervan is `Read-Access Geo Redundant Storage` .

1. Rol spoke A `virtual network` uit in West Europe, met een /16.
1. Rol spoke B `virtual network` uit in North Europe, met een /16.
1. Nadat de VNETs zijn aangemaakt, kan je onder de `virtual network` `Peering` selecteren en een [peering toevoegen](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering#create-a-peering) om de spokes netwerken aan de hub `virtual network` te koppelen. Doe dit voor elke spoke
    * Sta verkeer naar remote netwerken toe.
    * Sta verkeer van andere netwerken toe.

><details>
>  <summary>VNET peering</summary>  
>
> Peerings verbinden twee [`VNETs`](a "Virtual Networks") met elkaar. De peering moet in beide VNETs worden aangemaakt. In de [`portal`](a "Azure Portal") gebeurt dit automatisch wanneer je rechten hebt op beide VNETs. Doe je dit op een andere wijze (API/PowerShell/Azure CLI), moet elke zijde van de peering los worden opgezet.

</details>

## Uitrollen applicatie server

Twee servers worden uitgerold, elk in een eigen spoke netwerk. De servers zullen APIs aanbieden voor financiele gegevens en risk assessments. De APIs horen publiekelijk beschikbaar te zijn in de toekomst. Inbound SSH verkeer mag alleen vanuit de management server.

> **NOTE:** gebruik `Standard_SSD` of `Standard_HDD` schijven. Gebruik geen `premium` disks.  

> **NOTE:** Kies voor de size van de web server `Standard_B1s`.

1. Deploy twee Ubuntu 22.04 VMs, elk in een van de twee spokes. In spoke A moet de server in `West Europe` worden uitgerold. In spoke B in `North Europe`.  De VMs doen dienst als web servers.
    * Rol de VMs in een `availability zone` uit.
    * Geef de VMs geen `public IP`.
    * Geef de VMs geen `network security group`. Deze gaan we apart toevoegen.
    * Schakel `Auto-shutdown` in en zet deze op 00:00 in jouw lokale tijdzone.
    * Bij de `Advanced` tab tijdens de configuratie kan een script worden ingevoerd. Plak onderstaande script in de **USER DATA**, niet **CUSTOM DATA**. Hiermee gaan we de servers configureren.
      * Custom scripts zijn ook te gebruiken voor het bootstrappen van bijv. netwerk apparatuur.

    ```bash
    #!/bin/bash

    # license: https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh
    apt-get update -y && apt-get upgrade -y
    apt-get install -y nginx jq
    LOC=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq '.compute.location')
    echo "{\"service\": \"Finance API\", \"location\": $LOC, \"server\": \"$HOSTNAME\"}" | sudo tee /var/www/html/index.html
    sudo mkdir -p /var/www/html/health/
    echo "{\"health\": \"ok\"}" | sudo tee /var/www/html/health/index.html
    ```

Na het uitrollen van de applicatie servers, kan je via de management server inloggen op de API servers:
```powershell
ssh <username>@<ip/fqdn>
ssh admin@10.0.0.1
```

1. Vergelijk de externe IPs tussen de spokes en management
    * De publieke IP is te achterhalen: 
    * linux: `curl https://api.ipify.org`
1. Controleer hoe de verkeersstromen lopen:
    * Verkeer tussen spokes en hub
    * Verkeer richting internet vanuit de webservers

## NSG/ASG

De applicatie servers zijn nu vanuit elke resource te benaderen die een pad naar ze heeft. Om dit te fixen, gaan we `NSGs` en `Application Security Groups` (ASG) gebruiken om verkeer te limiteren.

1. Maak een `ASG` aan voor de servers.
    * een voor applicatie servers in spoke A
    * een voor applicatie servers in spoke B
    * een voor de management server in de hub
1. Voeg de servers aan hun respectievelijke `ASGs` toe.
    * VM > Networking > kopje Application Security Groups
1. Maak een `NSG` aan per spoke `VNET` en sta het onderstaande verkeer toe. Maak gebruik van de ASGs als source en destination in plaats van subnetten/IP-reeksen/IP-adressen voor de webservers en management server.
    * SSH vanuit de management server
    * HTTP vanuit overal
    * Al het andere inbound verkeer moet worden geblokkeerd.

Wat gaat er hier mis en waarom?
> <details><summary>ASG beperkingen</summary>
>
> Indien in een regel een `ASG` gebruikt wordt, moeten andere ASGs (indien aanwezig) in dezelfde regel alleen VMs bevatten die zich in dezelfde VNET bevinden als de eerst gebruikte ASG. Dit is een van [de (grote) beperking](https://docs.microsoft.com/en-us/azure/virtual-network/application-security-groups#allow-database-businesslogic) van `ASGs`. Voor verkeer tussen VNETs, zijn ASGs geen goede keuze.

</details>

1. Pas de `NSG` aan. Gebruik per spoke zoveel mogelijk ASGs en IP adressen alleen wanneer nodig. 
    
    > <details><summary>NSG hergebruiken</summary>
    >
    > NSGs zelf kunnen hergebruikt worden tussen `virtual networks` en VMs, mits deze zich in dezelfde subscription bevinden.

    </details>

1. Koppel de `NSG` aan de subnetten waar de web servers in zitten.
1. Bezoek de websites intern via de management VM.
1. Controleer hoe de verkeersstromen lopen:
    * Verkeer tussen spokes en hub
    * Verkeer tussen spokes
    * Verkeer richting internet vanuit de webservers

    > <details><summary>Standaard route tabellen in Azure</summary>
    >
    > Azure `virtual networks` hebben [standaard een null route](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview#default) staan voor de RFC1918 prefixes (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) en de RFC6598 prefix (100.64.0.0/10). Door een `address space` toe te voegen worden specifiekere routes aangemaakt en de route tabel overschreven.
    >
    > Directe `VNET peers` voegen elkaars `address spaces` toe. Van een peer geleerde routes worden echter niet doorgegeven aan andere peers. Dit betekent dat spoke A geen routes leert naar spoke B via het hub netwerk.

    </details>

    > <details><summary>Next hop/effective routes</summary>
    >
    > De [`Next hop`](https://docs.microsoft.com/en-us/azure/network-watcher/network-watcher-next-hop-overview) functionaliteit van de `Network Watcher` of de `Effective routes` functionaliteit van een `NIC` geeft informatie over waar verkeer van een VM naartoe gaat. Gebruik dit om verkeersstromen te verifieren.

    </details>

## Logging en archivering

De Hollandsche Bank eist dat BY verkeer dat langs komt kan analyseren voor 30 dagen en archiveert voor 90 dagen. Hiervoor kan gebruik worden gemaakt van de `Diagnostics settings` en/of de `NSG flow logs` van de `NSGs`. Aangezien dit een lab is, voeren we dit alleen uit voor de primaire regio.

1. Deploy een `Storage account`. De `storage account` gaat gebruikt worden voor log archivering.
    * `Standard` SKU, niet `premium`. 
    * Redundancy maakt niet uit. `LRS` is voor een lab het beste 
    * Gebruik geen `private endpoint` of `service endpoint`. De storage account moet vanuit het internet bereikbaar blijven.
1. Deploy een `Log Analytics Workspace`. De workspace gaat gebruikt worden voor analyse van het verkeer.
1. Ga naar de aangemaakte `NSGs` en configureer de `NSG` flow logs. 
    * Flow Logs version: Version 2
    * Retention: Conform DHB eis
    * Traffic Analytics status: On
    * Processing interval: Every 10 mins

> **Note:** Over ongeveer 10-15 minuten kan gebruik worden gemaakt van de `Traffic Analytics` functionaliteit van de `Network Watcher`. 
