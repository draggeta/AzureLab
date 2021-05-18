# Dag 2 - Firewalling

De afdeling wil alle DNS queries gelogd hebben. Omdat er misschien later nog wat gedaan gaat worden met threat detection, wordt hiervoor de `Azure Firewall` gebruikt.

> **Note:** Start de VM's nog niet op. We gaan de DNS instellingen aanpassen. Deze worden alleen bij het starten van een VM meegenomen door DHCP.

## Uitrol AZF
1. Deploy een [`Azure Firewall`](https://docs.microsoft.com/en-us/azure/firewall/overview). De reden hiervoor is dat er meteen een makkelijke NVA aanwezig is die ook als 'custom' DNS server/proxy kan dienen
    * Let op, een `AZF` heeft nog extra componenten nodig zoals een `subnet` en `public IP`. Deze kunnen tijdens het deployen aangemaakt worden
    * Zorg ervoor dat de `AZF` als DNS proxy kan dienen. Dit is een setting die na uitrol aan gezet kan worden
    * Standard tier
    * Classic Firewall management
    * Plaats het in de core
    * Forced tunneling uit
1. Configureer de firewall als [DNS proxy](https://docs.microsoft.com/en-us/azure/firewall/dns-settings).
    * DNS > Enabled
    * DNS Servers > Custom: `1.1.1.1` en `8.8.8.8`
    * DNS Proxy > Enabled
1. Configureer de `AZF` interne IP als standaard DNS server IP voor de VNETs.
    * Per VNET moet dit ingesteld worden.
    * Kan ook per NIC, maar daar heeft niemand tijd voor.
1. Configureer de `AZF` `Diagnostics settings`. Log alles naar de `Log Analytics Workspace` en `storage account`. Stel een retentie van 90 dagen in.
1. Start de VM's en controleer de DNS instellingen die ze via DHCP hebben ontvangen.
    * linux: `systemd-resolve --status`
    * windows: `Get-DnsClientServerAddress`
1. Probeer iets te resolven
    * linux: `dig google.com +short`
    * windows: `Resolve-DnsName google.com`

De `AZF` wordt nu gebruikt als DNS server/proxy.

## Aanpassen interne routering

Nu blijkt dat de API servers voor financien en risk assesment toch met elkaar moeten kunnen communiceren. Om dit mogelijk te maken, kan er gebruik worden gemaakt van [`User Defined Routes`](https://docs.microsoft.com/en-us/azure/virtual-network/manage-route-table) en de `AZF`.

1. Maak een `UDR` aan met als destination jouw superscope (bijv. 10.8.0.0/14) en als next-hop de IP van de `AZF`.
1. Koppel deze aan alle `subnet`s met een VM in de spokes
1. Controleer de verkeersstromen:
    * spoke <> spoke
    * hub <> spoke
    * gebruik de effective routes optie op een NIC indien nodig
1. Maak een Network rule collection op de firewall aan die verkeer tussen de spokes toe staan.
    * spoke <> spoke verkeer zou nu moeten werken

## Aanpassing routering richting internet

Vanuit management komt het bericht dat verkeer van en naar het internet geanalyseerd moet worden voor Threats. Ook hiervoor kan de `AZF` gebruikt worden.

1. Pas de spoke `UDR` aan. Voeg een 0.0.0.0/0 route toe via de `AZF`.
1. Voeg een nieuwe Network Rule collection toe zodat outbound verkeer toegestaan is op de `AZF`.
1. Controleer de externe IPs van de web servers.
    * linux: `curl https://api.ipify.org`
    * windows: `irm https://api.ipify.org`
> **Note:** Gebruik de `Logs` functionaliteit van de `AZF` voor troubleshooting. Hiermee kan je verkeer analyseren. Er zijn nog meer opties voor [Dashboards voor AZF verkeer](https://docs.microsoft.com/en-us/azure/firewall/firewall-workbook).
4. Maak ook een `UDR` aan voor de hub. Deze moet ook een default route richting de `AZF` hebben. Koppel de `UDR` aan de management server `subnet`.
    * Heb je nog verbinding? Waarom wel/niet?



## Inbound internet verkeer toestaan

> **Note:** Er is nu sprake van assymetrische routering. Verkeer komt binnen via de PIP, maar gaat langs de AZF naar buiten. De `AZF` doet [automatisch SNAT](https://docs.microsoft.com/en-us/azure/firewall/snat-private-range) voor destination IPs buiten RFC1918.

Om de assymetrische routering te repareren, moet de inbound verkeer via de firewall lopen. We gaan dus via de firewall RDP verkeer NATten naar de management server.

1. Maak een NAT rule collection op de `AZF` aan voor inbound RDP of SSH (Windows of Linux) richting de management server.
1. Verwijder de publieke IP van de management server.
1. Controleer of inbound verkeer werkt. Gebruik hiervoor de externe IP van de `AZF`.
1. Controleer de nu gebruikte externe IP.

Optioneel: configureer een [DNS record](https://docs.microsoft.com/en-us/azure/virtual-network/public-ip-addresses#dns-hostname-resolution) op de `public IP` van de firewall. Dan hoef je geen IP te onthouden.
