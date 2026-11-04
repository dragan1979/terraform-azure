# Production-Grade Multi-Layer Azure Infrastructure

This repository contains modular, production-ready Terraform code and Azure DevOps pipelines designed to deploy a decoupled cloud architecture on Microsoft Azure. It isolates foundational networking, compute (AKS), and secrets management (Azure Key Vault) into distinct state layers while leveraging OIDC authentication, binary plan artifacts, and automated security scanning.

---

## Architecture Overview

The infrastructure is split into three decoupled operational layers. Instead of sharing a monolithic state file or using hard state coupling via `terraform_remote_state`, each layer operates independently and queries live infrastructure metadata via Azure Resource Manager (ARM) data sources (`data "azurerm_*"`).

```text
┌─────────────────────────────────────────────────────────────┐
│                       Azure Subscription                    │
│                                                             │
│   Layer 01: Network                                         │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Resource Group: vnet-rg                             │   │
│   │ ├── Virtual Network (infra-vnet)                    │   │
│   │ ├── Subnets (snet-aks-nodes, snet-db, etc.)         │   │
│   │ ├── NAT Gateway & Public IP                         │   │
│   │ └── Network Security Groups (NSGs)                  │   │
│   └──────────────────────────┬──────────────────────────┘   │
│                              │ Discovered via ARM Data Sources
│                              ▼                              │
│   Layer 02: AKS Compute                                     │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Resource Group: aks-resource-group                  │   │
│   │ ├── Managed Kubernetes Cluster (retail-store-aks)   │   │
│   │ ├── Node Pool: Standard_E2s_v3 (italynorth)         │   │
│   │ └── OIDC Issuer & Azure Workload Identity           │   │
│   └──────────────────────────┬──────────────────────────┘   │
│                              │ Discovered via ARM Data Sources
│                              ▼                              │
│   Layer 03: Security & Secrets                              │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Resource Group: vault-rg                            │   │
│   │ ├── Azure Key Vault (kv-hub-*)                      │   │
│   │ ├── Private Endpoint & Private DNS Zone             │   │
│   │ └── VNet Link for Private Resolution                │   │
│   └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```text
.
├── .gitignore                      # Excludes .terraform/, state files, and runtime plans
├── README.md                       # Repository documentation
├── azure-pipelines.yml             # Orchestration pipeline (lint, validate, security, multi-stage deploy)
├── provider.tf                     # Root AzureRM provider configurations
├── root.tf                         # Root Terraform metadata
├── variables.tf                    # Shared root variables
├── environments/                   # Environment-specific configuration files
│   ├── dev.tfvars                 
│   ├── staging.tfvars              
│   └── prod.tfvars                
├── layers/                         # Decoupled deployment layers (isolated states)
│   ├── 01-network/                 # Virtual Network, subnets, NAT Gateway, NSGs
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   ├── 02-aks/                     # AKS Cluster & Workload Identity
│   │   ├── data.tf                 # Queries 01-network subnets dynamically from ARM
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── variables.tf
│   │   └── versions.tf
│   └── 03-vault/                   # Key Vault & Private Endpoint integrations
│       ├── data.tf                 # Queries 01-network VNet and PE subnet from ARM
│       ├── main.tf
│       ├── variables.tf
│       └── versions.tf
├── modules/                        # Reusable Terraform child modules
│   ├── aks/                        # AKS managed cluster definition
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── keyvault/                   # Key Vault and Private Endpoint module
│   │   ├── main.tf
│   │   └── variables.tf
│   └── vnet/                       # VNet, subnet CIDRs, and route tables module
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
└── templates/                      # Reusable Azure DevOps pipeline job templates
    └── terraform-deploy.yaml       # Standardized Plan & Apply job definitions
```

---

## Key Architectural Decisions

### 1. Isolated State & Blast Radius Containment
* Each layer writes to a distinct blob key in the backend storage account (`dev-network.tfstate`, `dev-aks.tfstate`, `dev-vault.tfstate`).
* A modification or syntax error in compute or security cannot taint or destroy foundational network infrastructure.

### 2. Loose Coupling via ARM Data Sources
* Layers do not read remote state files directly (`terraform_remote_state` is avoided).
* Dependent layers query Azure directly using `data "azurerm_*"` blocks against consistent resource names. This allows teams to enforce granular RBAC on state files while allowing cross-layer discovery.

### 3. Regional Quota & Compute Optimization (`italynorth`)
* Deployments target Azure region **`italynorth`** to operate within subscription vCPU quotas.
* AKS nodes use **`Standard_E2s_v3`** (Memory-Optimized: 2 vCPUs, 16 GB RAM per node).
* Running a 2-node cluster uses **4 vCPUs total**

### 4. Zero-Secret CI/CD with OIDC
* Authentication between Azure DevOps and Azure uses federated OpenID Connect (`ARM_USE_OIDC=true`).
* No client secrets, passwords, or certificates are stored in pipeline service connections, eliminating credential leakage and certificate rotation outages.

### 5. Plan-then-Apply Invariance
* The pipeline generates a compiled binary plan artifact (`${layer}.tfplan`) during the speculative plan phase.
* The apply step consumes that exact binary artifact directly (`terraform apply ${layer}.tfplan`). No variable files are passed at apply time, guaranteeing that only the reviewed and audited plan is executed.

---

## Prerequisites

1. **Tools:**
   * [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) ($\ge$ v1.9.8)
   * [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) ($\ge$ v2.60.0)
   * [kubectl](https://kubernetes.io/docs/tasks/tools/) and [Helm](https://helm.sh/docs/intro/install/) (for post-provisioning cluster access)
2. **Azure Backend:**
   * A pre-existing Azure Storage Account dedicated to remote state (e.g., storage account `123456909090` in resource group `sa` with container `tfstate`).
3. **Azure DevOps:**
   * An active Azure DevOps Service Connection configured with Workload Identity Federation (OIDC) targeting your Azure subscription.

---

## CI/CD Pipeline Execution (`azure-pipelines.yml`)

The pipeline runs across four major phases:

1. **Validation & Quality Gate:**
   * Runs `terraform fmt -check -recursive` across the entire repository.
   * Runs `terraform validate` on each decoupled layer.
   * Runs a **Trivy** container scan targeting Terraform misconfigurations and outputs a SARIF compliance report.
2. **Layer 1: Network Foundation:**
   * Runs speculative plan, uploads `tfplan-network-dev` artifact, and applies the VNet, Subnets, and NAT Gateway.
3. **Layer 2: AKS Compute (Depends on Layer 1):**
   * Initiates only after Layer 1 applies successfully.
   * Discovers the created subnets via ARM API data sources and provisions the Kubernetes cluster.
4. **Layer 3: Key Vault & Secrets (Depends on Layer 2):**
   * Configures Key Vault, Private Endpoints, and Private DNS resolution.

---

## Local Development & Manual Deployment

When deploying locally without Azure DevOps, apply the layers sequentially from the repository root:

### 1. Authenticate to Azure
```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"
```

### 2. Deploy Layer 1 (Network)
```bash
cd layers/01-network
terraform init \
  -backend-config="resource_group_name=sa" \
  -backend-config="storage_account_name=123456909090" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev-network.tfstate"

terraform plan -var-file="../../environments/dev.tfvars" -out=network.tfplan
terraform apply network.tfplan
```

### 3. Deploy Layer 2 (AKS Compute)
```bash
cd ../02-aks
terraform init \
  -backend-config="resource_group_name=sa" \
  -backend-config="storage_account_name=123456909090" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev-aks.tfstate"

terraform plan -var-file="../../environments/dev.tfvars" -out=aks.tfplan
terraform apply aks.tfplan
```

### 4. Deploy Layer 3 (Key Vault)
```bash
cd ../03-vault
terraform init \
  -backend-config="resource_group_name=sa" \
  -backend-config="storage_account_name=123456909090" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev-vault.tfstate"

terraform plan -var-file="../../environments/dev.tfvars" -out=vault.tfplan
terraform apply vault.tfplan
```

---

## Infrastructure Teardown & Automation Cleanup

Because of parent-child resource locks in Azure (such as NICs attached to Private Endpoints and subnets attached to AKS), destroying resources must follow reverse dependency order:

1. **Destroy Layer 3:** `cd layers/03-vault && terraform destroy -var-file="../../environments/dev.tfvars"`
2. **Destroy Layer 2:** `cd layers/02-aks && terraform destroy -var-file="../../environments/dev.tfvars"`
3. **Destroy Layer 1:** `cd layers/01-network && terraform destroy -var-file="../../environments/dev.tfvars"`

---
