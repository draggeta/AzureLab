# Lab exercises

* [Inleiding](#inleiding)
* [Vereisten](#vereisten)
* [Code Samples](#code-samples)
* [Navigatie door de portal](#navigatie-door-de-portal)
* [Voorbereiding](#voorbereiding)
* [Lab checkpoints](#lab-checkpoints)

## Introduction

You are a network engineer/architect working for BY, a new health insurance tech company. As it's a startup, BY cannot waste money on capital right now. Their goal is to lower long term costs by using Machine Learning to identify users at risk of complications that can be treated in early stages but become more difficult to provide care for as the disease progresses.

As the company's lead network engineer, you need to design a network that allows the company to immediately start developing their solutions. The design should be the bare minimum of what they need right now, but should allow for scaling and future changes.

## Lab requirements

For these labs, `contributor` or `owner` rights on the subscription is needed. Some parts won't work well if the requirements aren't met. Below is a list of examples:
* `Auto-shutdown` of VMs.
* Not all `Network Watcher` functionality is available.
* Setting up `diagnostic settings` or `flow logs`.
* Creating `resource groups` might fail.

## Code Samples

The lab gives a lot of code samples to run. Most of them are for diagnostic purposes.

For Windows, most of the samples are meant to be run in `PowerShell` (Windows and Core). The Linux code samples work in at least `Bash`.

Windows has an SSH client built-in since Windows 10/Windows Server 2016. From a terminal, run the below commands to SSH into a device:

```powershell
ssh <username>@<ip/fqdn>
ssh admin@10.0.0.1
```

## Navigating around the portal

The [Azure portal](https://learn.microsoft.com/en-us/azure/azure-portal/azure-portal-overview) is the tool to get to know [Azure Resource Management](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview). The Portal has a lot of options and settings. While clicking through the portal works, it's often faster and easier to use the search bar up top to find what you need.

## Preparation

### Naming convention

A good name can tell a lot about a resource. For this reason, it is a good idea to think about your [naming convention](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming). Microsoft has a lot of documentation with regards to what to think about when moving to Azure.

Before starting the labs, try to think of some good naming conventions for your resources. This way, you'll be able to test the conventions while labbing instead of when you need to do something in production.

Keep the following points in mind while developing the conventions:
* `Resource groups` must be unique per subscription per region.
* Resource names must be unique per type per resource group.
* Some resource names must be globally unique. In most of these cases, the name is a part of the resource [FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name "Fully Qualified Domain Name")).
* Windows VM names can contain a maximum of 15 characters (NETBIOS limitation).
* Some resources have [stricter requirements](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)

### Resources and resource groups

[`Resource groups`](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#what-is-a-resource-group) assist with the organization and grouping of resources. Doing this correctly is a boon for operations. On the flip side, mashing everything into one `RG` or splitting every single resource into their own group will make day-to-day operations more difficult.

Having a good idea of what to group together makes the following operations easier:
* Removing resources.
* Setting permissions.
* Categorizing resources.

BY expects that you have a strategy on how to use the `resource groups`.

### Regions

The lab assumes that most resources will be deployed in `West Europe`. The secondary location for resources is `North Europe`. The regions are arbitrarily chosen. The important part is that the chosen regions are used consistently.

### IP ranges

BY's decided to use the 10.128.0.0/14 range for their cloud deployment. They two production VNETs and one management VNET. Each virtual network should use a /16 as their address space.

### Virtual networks

The division of superscopes/address spaces per [`VNETs`](a "virtual networks").

| Virtual Network | scope | 
| --- | --: |
| Hub | 10.128.0.0/16 |
| Spoke A | 10.129.0.0/16 |
| Spoke B | 10.130.0.0/16 |

### Subnets

For lab purposes, we'll keep the subnet prefixes simple. A /24 will be used for all subnets.

## Lab checkpoints

Each lab exercise contains a 'tf' folder. This folder contains [Terraform](https://www.terraform.io/) files that can deploy the end state of the exercise.

Use the deployment for the following reasons:
1. To save cost by removing your lab and programmatically deploying the environment for later exercises
1. You want to see a correct solution
1. When you messed up the lab and want to start over from a clean slate.

Deploying the templates can be performed in the [Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/overview).

> **NOTE:** The credentials for all devices deployed by Terraform are: `adminuser`/`AzureLabs10IT!`.

> **NOTE:** The TF deployment uses some tricks to limit inbound SSH/RDP to your local public IP. When using the Cloud Shell to deploy the resources, the template will use the public IP of the Cloud Shell container. In these cases, ACLs may have to be edited to allow traffic from your device. 

```bash
# (optional) az account set --name "<subscription name>"
git clone https://github.com/draggeta/AzureLab.git
terraform -chdir=AzureLab/ex<number>/tf init
terraform -chdir=AzureLab/ex<number>/tf apply
rm -rf AzureLab/
```
