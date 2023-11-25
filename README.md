# Data#3 Azure Hybrid Use Benefit Reporter App Configuration Script

## Overview

This PowerShell script is designed to configure the Data#3 Azure Hybrid Use Benefit (AHUB) Reporter App. The script enables the AHUB Managed Application by granting the System Assigned Identity for the App the Role `Reader` at the Tenant Root Management Group.

## Prerequisites

- **PowerShell Version:** Ensure that PowerShell Core is installed with a minimum version of 7.3.
- **Modules:** The script requires the following Azure modules:
  - `Az.Accounts` (Version 2.12.3)
  - `Az.Resources` (Version 6.7.0)

## Script Parameters

The script accepts the following parameters:

- **FunctionAppName:** The name of the Azure Function App associated with the AHUB Reporter App.
- **SubscriptionId:** The unique identifier for the Azure subscription.
- **TenantName:** The name of the Azure Active Directory (AD) tenant.

## Usage Instructions

1. **Execute the Script:**
   - Run the script in a PowerShell environment with the required permissions.
   - Make sure to meet the prerequisites mentioned above.

1. **Follow On-Screen Prompts:**
   - The script guides users through the AHUB Reporter App configuration.
   - Users will be prompted for Azure credentials.

1. **Script Outputs:**
   - The script logs outputs and results for reference.
   - A transcript file is generated and opened for review at the end of the execution.

1. **Enable Management Groups:**
   - The script checks if Management Groups are enabled.
   - If not, a temporary Management Group is created and deleted to enable Management Groups.

1. **Managed Identity Configuration:**
   - The script configures the Managed Identity for the AHUB Managed Application.
   - Assigns the "Reader" role to the Managed Identity for the specified scope.

## Important Notes

- **Pre-Deployment Requirement:**
  - This script must be executed after deploying the AHUB Managed Application into the Azure tenant.

- **Azure Login**
  - You will be prompted to log in only once. The login credentials are cached for the session duration.

## Script Output

Upon completion, the script provides detailed information about the executed tasks, including:

- Imported Azure context information.
- Current user account details.
- Current environment and tenant information.
- Current subscription details (if applicable).

## Logging

The script generates a transcript file (`transcript_<timestamp>.txt`) containing detailed logs. The log file is opened automatically for user review.

## Troubleshooting

In case of errors or issues, review the generated log file for more information. Ensure that prerequisites are met and that the script is executed with the required permissions.

## Disclaimer

Please review and understand the script before execution. The script involves configuring Azure resources, and it may have an impact on your Azure environment. Ensure that you have the necessary permissions and take appropriate precautions.

## Authors

- **Paul Towler (Data#3)** - *Release v1.0.0* - 16 November 2023
