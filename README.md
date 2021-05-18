# LAB opdrachten

## Inleiding

Je werkt voor BY, een nieuwe verzekeraar. BY heeft geen eigen hardware en is in de startup fase niet van plan om uitgaven te doen aan kapitaal. Daarom beginnen ze direct in de cloud. Jij werkt voor een afdeling die zelf hun eigen infrastructuur gaat regelen in Azure.

## Navigatie door de portal

De [Azure portal](https://docs.microsoft.com/en-us/azure/azure-portal/azure-portal-overview) is de tool om [Azure Resource Management](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/overview) te leren kennen. Er zijn veel opties en instellingen. Gebruik de zoekbalk bovenin voor het vinden van items. Je kan alles vinden door te klikken, maar zoeken is vaak sneller als je niet precies weet waar iets te vinden is.

## Voorbereiding

### Naamgeving
De [naamgeving is van belang](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming). Je kan met een goede naamgeving veel informatie in een oogopslag zichtbaar maken

Bedenk van tevoren een zinnige naamgeving voor je resources. Wat wil je erin verwerkt hebben?
* `resource groups` zijn uniek per subscription per regio
* resources moeten een unieke naam in een resource group hebben
* bepaalde resources moeten een globaal unieke naam hebben (de naam is ook onderdeel van de DNS record)
* Windows VM namen mogen maximaal 15 tekens lang zijn
* [bepaalde resources hebben strengere eisen dan anderen](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)

### Resources en Resource Groups

[`Resource groups`](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#what-is-a-resource-group) helpen met het groeperen van uitgerolde diensten. Goed nadenken over wat bij elkaar in een groep hoort is van belang. Het maakt de volgende zaken makkelijker:
* opschonen van resources
* uitdelen van rechten
* categoriseren van resources

BY verwacht dat de `resource groups` zinnig zijn ingedeeld.

### IP ranges

Elke afdeling heeft een /14 toegewezen gekregen. Hieruit worden drie `Virtual Networks` met een /16 grootte uitgerold.

| naam | supernet |
| --- | --- |
| Rene | 10.112.0.0/14 |
| Rob | 10.124.0.0/14 |
| Ruud | 10.136.0.0/14 |
| Tamim | 10.148.0.0/14 |

### Virtual Networks

Hieronder een verdeling van de superscope naar `Virtual Networks`.

| Virtual Network | scope | 
| --- | --: |
| Core | 1<sup>ste</sup> /16 |
| Spoke A | 2<sup>e</sup> /16 |
| Spoke B | 3<sup>e</sup> /16 |

### Subnets

Elke subnet is /24 groot. Dit houdt het simpel.
