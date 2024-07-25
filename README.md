# Terraform task
Reviewing the task and extracting the requirements, the following components shall be deployed:
- vNet
    - Resource group
    - vNet resource (name: ```spoke1```)
    - NSG for AKS
    - NSG for Postgres (Normally here would come an inbound rule to allow AKS but Private Endpoints don't support NSG/UDR directly and they need a policy. A better solution is below.)
    - Subnet for AKS (name: ```backend```)
    - Subnet for PostgreSQL (name: ```db```)
    - Private DNS zone for PostgreSQL and its link
- AKS
    - Resource group
    - Log Analytics Workspace (for logs)
    - User-assigned Identity
    - Role assignment for the MI to subnet with Network Contributor
    - AKS resource
        - Public cluster with Authorized IP access
        - 2 nodes - Standard_B2
        - Set basic Diagnostic settings
        - Activate Azure Monitoring
        - Azure CNI Overlay
        - 2 nodes base nodepool with autoscaling
    - Set diagnostic settings
    - This AKS deployment is minimalistic but there is a wide range of additional services and configuration options what I wrote about here: [Basic vs Enterprise-grade AKS](https://clidee.eu/2024/01/18/basic-vs-enterprise-grade-aks/)
- PostgreSQL flexible server
    - Resource Group
    - PostgreSQL resource
        - Minimal capacity
        - No public access but vNet integration
        - Attach to the PDNS
    - Firewall rule to allow AKS' whole subnet


# Simple solution
The Terraform files in the [simple-tf](./simple-tf/) folder compile the most simple Terraform setup. It is easy to read but it is hard to reuse in an enterprise environment. It is just fulfills the task but it isn't future-proof.

To deploy the resources follow these steps:
1. Install Terraform and Azure CLI binaries
1. Login to Azure with the Azure CLI
   ```
   az login
   ```
1. Clone this git repository with your favorite tool
1. Enter into the ```simple-tf``` folder
   ```
   cd simple-tf
   ```
1. Initialize Terraform
   ```
   terraform init
   ```
   terraform init
1. Plan the Terraform
   ```
   terraform plan
   ```
1. Apply with Terraform
   ```
   terraform apply
   # Enter the Database password when prompted for it
   # Enter your own public IP for AKS authorization in CIDR format like 1.2.3.4/32
   # Enter "yes" when prompted for approval
   ```
1. Check the resources on the Azure portal

## Clean-up
To remove all resources you shall destroy with terraform:
```
terraform destroy  # Enter "yes" when prompted
```

# Enterprise grade variant
Well due to short of time I couldn't finish the hands-on part. These are the planned modifications:
- The statefile would be saved in an Azure Storage Account (very-very independent from the deployment.)
- There would be a dedicated HUB deployment which includes:
  - Centralized Private DNS deployment in the HUB subscription.
- There would be a dedicated TF file for the landing zone which creates the vNet, its peering to HUB and the links to the PDNS zones.
- There would be a dedicated TF set for the applications:
  - All components would be transformed to modules.
  - All components would be organized into input arrays so we could use foreach function for as many deployment based on the inputs.
- I would use Terraform workspace for each Spoke deployment to separate their configs and states. In this way we can use the same TF templates for multiple Spokes. Or a Plan-B to use Terragrunt for this purpose.