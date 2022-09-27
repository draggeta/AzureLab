# Dag 7 - Private/service endpoints

De rekeningen vanuit Azure zijn niet mals. BY beseft dat alles in VMs draaien niet kosten efficient is. Ze willen `Azure Functions` (PaaS API webservers) gaan gebruiken voor hun API. Ook moet outbound internet verkeer standaard geblokkeerd gaan worden. Met de PII waar de verzekeraar mee te maken heeft, moet alles zo dicht mogelijk staan.

De huidige webservers, `AGW` en `ELB` zullen vervangen worden door de genoemde diensten.

![VPN gateway/virtual network gateway](./data/vpn_gateway.svg)

## Azure Functions

De migratie mag met downtime. Er hoeft geen langzame migratie plaats te van de webservers naar de `app services`.

Hoe zou de migratie met minimale downtime uitgevoerd kunnen worden?

> <details><summary>Migratie opties</summary>
>
> Er zijn veel opties. Het is op te lossen met DNS record aanpassingen, de `AGW` verkeer laten load balancen en door `traffic manager` en `Azure front door`. `NVAs` zijn ook nog een mogelijkheid.

</details>

### Verwijderen uitgefaseerde diensten

Verwijder de volgende resources:
* spoke A webserver en toebehoren
* spoke B webserver en toebehoren
* application gateway en toebehoren
* external load balancer en toebehoren

### Aanpassen firewall

Blokkeer alle outbound verkeer op de AZF, maar sta east-west verkeer toe. Zorg ervoor dat `kms.core.windows.net` nog steeds bereikbaar is op `http/tcp:1688`. Zonder de KMS regel, kunnen Windows VMs zich niet activeren.

### Azure functions uitrollen

> **NOTE:** Function apps zijn geen onderdeel van het examen. Het gaat in de opdracht om de service endpoints. `Function apps` hebben altijd een [`App Service Plan`](https://learn.microsoft.com/en-us/azure/app-service/overview-hosting-plans) en een storage account nodig. Een ASP is een server waar de function op draait. Elke `ASP` kan meerdere functions bevatten.

Rol twee [`function apps`](https://learn.microsoft.com/en-us/azure/azure-functions/functions-create-function-app-portal) uit, een in West Europe en een in North Europe.
* Basics
    * Publish: Code
    * Runtime stack: Python
    * Version: 3.9
    * Plan type: App service plan
    * SKU and size: Dev/Test > B1
* Monitoring
    * Enable Application Insights: No

Nadat de `functions` succesvol uitgerold zijn, gaan we de API deployen. Ga naar de `function app` > Deployment Center > Tabblad Settings.
1. Selecteer als source 'External Git'
2. Bij repository moet 'https://github.com/draggeta/AzureLabFunction.git' ingevuld worden
3. Bij Branch moet 'master' ingevuld worden
4. Klik op save
5. (Optioneel) Controleer bij tabblad Logs de deployment. Dit kan even duren. Bij status 'Success (Active)' is het gelukt.
6. Probeer de API op 'https://<fqdn>/api/info' en 'https://<fqdn>/api/health' (dit keer zonder '/' aan het eind)
7. Probeer ook de API vanuit de management server. Dit zou niet moeten lukken.

## Private endpoint

Het is niet mogelijk om vanuit de management server de API in Azure te benaderen. Het is wel gewenst, maar Security wil niet dat de management zone het internet op kan. De door Microsoft aangerade oplossing is om [`private endpoints`](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview) te gebruiken. Voor het lab wordt de 'West Europe' `function app` met een `private endpoint` gekoppeld aan de spoke A `VNET`.

### Uitrollen private endpoint

Ga naar de spoke A `function app` > Networking > `Private endpoints` en voeg een endpoint toe
* Integrate with private DNS zone: No

Wacht totdat de endpoint uitgerold is. Probeer vanaf de management server 'https://<fqdn>' of een van de API endpoints te bereiken. Resolve ook de DNS met:

```powershell
Resolve-DnsName <fqdn>
```

Wat gaat er mis?

> <details><summary>Private endpoints en DNS</summary>
>
> Je krijgt vooralsnog het externe IP-adres terug, waar je niet bij mag. De `private endpoint` heeft wel een interne IP, maar niks resolvet er nog naar. Om het werkende te krijgen, moet een [privatelink.* DNS zone](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration) worden aangemaakt specifiek voor de resource type en gekoppeld worden aan de VNET waar DNS resolvet wordt. Ook moet de `private endpoint` zijn DNS in deze zone registreren.
>
> Er gebeurt hierna iets 'magisch'. Intern is de DNS resolving als volgt: <function app name>.azurewebsites.net wordt aan AZF gevraagd > recursive query naar VNET > dit is een CNAME voor <function app name>.privatelink.azurewebsites.net > dit is een A record voor de endpoint IP.
>
> Extern is de resolving als volgt: <function app name>.azurewebsites.net wordt aan AZF gevraagd > recursive query naar resolver > dit is een CNAME voor <function app name>.privatelink.azurewebsites.net > CNAME voor andere FQDNs > A record voor externe IP function app.
>
> Resources zonder private endpoint hebben geen privatelink CNAME en zullen hierdoor altijd extern benaderd worden.

</details>

### Private DNS repareren.

We gaan de interne DNS zo inrichten dat vanuit intern er altijd een interne IP-adres terug gegeven wordt.
1. Maak een `private DNS zone` aan genaamd 'privatelink.azurewebsites.net'. 
1. Koppel de zone aan de hub VNET.
1. Ga naar de `private endpoint` > DNS configuration en klik op 'Add configuration'.
    * Selecteer de juiste Private DNS zone
    * Zone group mag op default blijven staan
    * Bedenk een zinnige configuration name
    * Klik op add

Test nadat de uitrol gelukt is, de DNS resolving en of de website bereikbaar is vanuit de management server. Test ook of de website vanuit extern te benaderen is.

> <details><summary>Private endpoints en app services/function apps</summary>
>
> `App services` en `function apps` zijn niet meer extern te benaderen wanneer een `private endpoint` gekoppeld wordt. Dit zijn de enige type resources waar dit het geval is. De API server moet echter wel vanuit het internet te benaderen zijn. Dit is op te lossen onder de `function app` > Networking > Access Restrictions (preview). Hier kan toegang vanuit het internet toegestaan worden.

</details>

Repareer de externe toegang tot de spoke A API. Iederen moet erbij kunnen.

## Service endpoint

[`Service endpoints`](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-service-endpoints-overview) hebben niet meer de voorkeur, maar ze kunnen nog wel gebruikt worden. `Service endpoints` voegen een directe route over de Microsoft backbone toe richting bepaalde PaaS diensten. Het verkeer gaat niet over het internet en apparaten die gebruik hiervan maken hoeven geen internet verbinding te hebben. Een nadeel is dat alleen apparaten die in een subnet met een `service endpoint` zitten, gebruik kunnen maken van deze `service endpoints`. Andere subnetten en vanuit on-prem kunnen niet een willekeurige `service endpoint` gebruiken.
