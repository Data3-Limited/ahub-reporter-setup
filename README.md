# Azure Hybrid Use Benefit (AHUB) Reporter App Preparation Script

This script prepares your environment for the Data#3 Azure Hybrid Use Benefit Reporter App (D3AHUB). It automates the creation and configuration of an Entra ID Application Registration with a Service Principal used to deploy the D3AHUB App via Azure DevOps Pipeline.

> **IMPORTANT:**
>
> The Application Registration created by this script is granted a high level of permissions for the duration of **24 Hours**. This enables the application registration via a pipeline to perform necessary tasks, such as managing user identities, roles, and accessing directory data. It is essential to understand and review these permissions before running the script.

## Prerequisites

- PowerShell Core (v7.3)
- Azure PowerShell Module (Az) v2.12.3 for Az.Accounts and v6.7.0 for Az.Resources (Minimum)

## Usage

1. Execute the script using PowerShell Core with the required parameters.

   ```powershell
   ./Enable-D3Ahub.ps1 `
       -AppRegistrationName "<AppRegistrationName>" `
       -SubscriptionId "<SubscriptionId>" `
       -TenantName "<TenantName>"
   ```

   For example:

   ``` powershell
   ./Enable-D3Ahub.ps1 `
       -AppRegistrationName "D3-AHub-Reporter-App" `
       -SubscriptionId "ac6b5d5e-7a50-46f3-a49c-283610fe8c73" `
       -TenantName "contoso.onmicrosoft.com"
   ```

2. Follow the prompts to log in to Azure and Entra ID.

3. The script will perform the following actions:

   - Check if Management Groups are enabled and enable them if necessary.
   - Create or retrieve an Entra ID Application Registration and Service Principal.
   - Display the essential information about the created resources.
   - Applies API permissions and role assignments to the App Registration.

## Parameters

### AppRegistrationName

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

The name of the Entra ID Application Registration used by Azure DevOps (Data#3) to deploy the D3AHUB App via Pipeline

### SubscriptionId

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

The ID of the Azure subscription where the resources will be created.

### TenantName

![Parameter Setting](https://img.shields.io/badge/parameter-required-orange?style=flat-square)

The name of the Entra ID tenant.

## Functions

### `Connect-Account`

This function handles the authentication and connection to Azure and Entra ID. It supports both Azure and Entra ID contexts.

### `Get-InputOption`

A helper function to gather user input, allowing customisation of prompts.

## Logging

The script generates a transcript log file (`transcript_<timestamp>.txt`) in the temporary directory. The log contains detailed information about script execution, errors, and created resources.

## Cleanup

The script performs cleanup tasks, such as removing expired credentials and providing a summary of executed actions.

## Notes

- The script applies role assignments at the scope `/`. Management Groups need to be enabled to utilise this scope and ensure proper deployment.
- Generated credentials for the Entra ID Application Registration expire after 24 hours.
- API permissions and role assignments are required to allow the App Registration to create the App and assign the Management Identity for App, the neccessay permissions to operate.

## API Permissions

The script applies the following API permissions to the Entra ID Application Registration:

- `AppRoleAssignment.ReadWrite.All`: This permission is required to assign and manage app role assignments for the application.

- `Directory.Read.All`: This permission is necessary to read directory data, including users, groups, and other directory objects.

- `User.ManageIdentities.All`: This permission is required to manage user identities, including the creation of managed identities for the D3AHUB App.

- `RoleManagement.ReadWrite.Directory`: This permission is needed to read and write directory roles, allowing the assignment of roles to the managed identity for the D3AHUB App.

These permissions are essential for the proper functioning of the D3AHUB App and its integration with Microsoft Graph.

## Role Assignments

The script applies the following role assignments to the Entra ID Application Registration:

- `User Access Administrator`

   Scope: `/`

   Description: This assignment grants the application registration the ability to read all resources within an Azure Tenant.

- `Owner`

   Scope: `Designated Subscription`

   Description: This assignment gives the application registration owner-level access to the designated subscription. It ensures the Application Registration deploying the D3AHUB App has the necessary privileges to deploy and manage resources within the specified subscription.

These role assignments are crucial for the Application Registration to deploy and configure the D3AHUB App to perform its intended tasks effectively.

## Disclaimer

Please review and understand the script before execution. The script involves creating and configuring Azure resources, and it may have an impact on your Azure environment. Ensure that you have the necessary permissions and take appropriate precautions.

## Authors

- **Paul Towler (Data#3)** - *Release v1.0.0* - 16 November 2023
