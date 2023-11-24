#Requires -PSEdition Core
#Requires -Version 7.3
<# #Requires -Modules @{ ModuleName="Az.Accounts"; ModuleVersion="2.12.3" }
#Requires -Modules @{ ModuleName="Az.Resources"; ModuleVersion="6.7.0" } #>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $AppRegistrationName,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$')]
    [String] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('(?=^.{1,253}$)(^(((?!-)[a-zA-Z0-9-]{1,63}(?<!-))|((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63})$)')]
    [String] $TenantName
)

begin
{
    #region Functions
    function Connect-Account
    {
        [CmdletBinding()]
        param 
        (
            [Parameter(Mandatory = $true)]
            [ValidateSet("Azure", "AzureAD")]
            [String] $ContextName,

            [Parameter(Mandatory = $true)]
            [String] $TenantName,

            [Parameter(Mandatory = $false)]
            [String] $SubscriptionId
        )

        $date = (Get-Date -Format yyyyMMdd)
        $contextEmpty = Join-Path $env:TEMP "empty.json"
        $result = @()

        if (-not (Test-Path $contextEmpty -ErrorAction SilentlyContinue))
        {
            '{
                "DefaultContextKey": "Default",
                "EnvironmentTable": {},
                "Contexts": {},
                "ExtendedProperties": {}
            }' | New-Item -Path $env:TEMP -Name "empty.json" | Out-Null
        }

        switch ($ContextName)
        {
            "AzureAD"
            {
                $contextFile = Join-Path $env:TEMP "context-azuread-$($tenantName)-$($date).json"
            }

            default
            {
                $contextFile = Join-Path $env:TEMP "context-azure-$($tenantName)-$($date).json"
            }
        }

        $environmentName = "AzureCloud"

        # Get your Tenant Id.
        $authEndPoint = (Get-AzEnvironment -Name $environmentName).ActiveDirectoryAuthority.TrimEnd('/') 
        $tenantId = (Invoke-RestMethod "$($authEndPoint)/$($TenantName)/.well-known/openid-configuration").issuer.TrimEnd('/').Split('/')[-1]

        if (-not (Test-Path  $contextFile -ErrorAction SilentlyContinue))
        {
            # No Azure Context file exists. Logging in....."
        }
        else
        {
            $context = (Import-AzContext $contextEmpty).Context
            Get-ChildItem $env:TEMP -Filter "Azure*.json" | Remove-Item -Force

            # Importing existing context
            $context = (Import-AzContext $contextFile).Context

            if ($SubscriptionId -and $context.Subscription.Id -ne $SubscriptionId)
            {
                $context = Set-AzContext -Tenant $tenantId -SubscriptionName $SubscriptionId
                Save-AzContext -Path $contextFile -Force
            }

            if ($environmentName -and $context.Environment.Name -ne $environmentName)
            {   
                $context.Environment = Get-AzEnvironment -Name $environmentName
                Save-AzContext -Path $contextFile -Force
            }

            # Validating
            switch ($SubscriptionId)
            {
                { $PSItem }
                { $validlogon = $null -ne (Get-AzSubscription -TenantId $tenantId -SubscriptionId $context.Subscription.Id -ErrorAction SilentlyContinue) }

                default
                { $validlogon = $null -ne (Get-AzSubscription -TenantId $tenantId -ErrorAction SilentlyContinue) }
            }

            if ($validlogon)
            {

                $result += "", " Imported Azure context:`t$($contextFile)"
                $result += "", " Current User Account is:`t$($context.Account.Id)"
                $result += " Current Environment is:`t$($context.Environment)"
                $result += " Current TenantId is:`t`t$($context.Tenant.Id)"

                if ($context.Subscription.Name)
                {
                    $result += " Current Subscription Name is:`t$($context.Subscription.Name)"
                    $result += " Current Subscription Id is:`t$($context.Subscription.Id)`r`n"
                }
            }
            else
            {
                # Getting Token
                $token = Get-AzCachedAccessToken
                if ($token)
                {
                    $validlogon = $true

                    $result += "", " Token is Valid!"
                    $result += "", " Current User Account is:`t$($context.Account.Id)"
                    $result += " Current Environment is:`t$($context.Environment)"
                    $result += " Current TenantId is:`t`t$($context.Tenant.Id)"

                    if ($context.Subscription.Name)
                    {
                        $result += " Current Subscription Name is:`t$($context.Subscription.Name)"
                        $result += " Current Subscription Id is:`t$($context.Subscription.Id) `r`n"
                    }
                }
            }
        }

        if (-not $validlogon)
        {
            $context = $null

            if ($tenantId -and !$SubscriptionId -and $environmentName)
            { 
                $null = Connect-AzAccount -TenantId $tenantId -Environment $environmentName
                Save-AzContext -Path $contextFile -Force
            }
            
            if ($tenantId -and $SubscriptionId -and $environmentName)
            { 
                $null = Connect-AzAccount -TenantId $tenantId -Subscription $SubscriptionId -Environment $environmentName
                Save-AzContext -Path $contextFile -Force 
            }

            $context = (Import-AzContext -Path $contextFile).Context

            if ($context)
            {
                $result += "", " SUCCESS! Logged with '$($environmentName)' successfully!"
                $result += "", " Context saved to:`t`t$($contextFile)"
                $result += " Current User Account is:`t$($context.Account.Id)"
                $result += " Current Environment is:`t$($context.Environment)"
                $result += " Current TenantId is:`t`t$($context.Tenant.Id)"
                if ($context.Subscription.Name)
                {
                    $result += " Current Subscription Name is:`t$($context.Subscription.Name)"
                    $result += " Current Subscription Id is:`t$($context.Subscription.Id)`r`n"
                }
            }
            else
            {
                $result += "", " ERROR! Login for '$($environmentName)' failed, please retry."
            }
        }

        return $result
    }

    function Get-InputOption
    {   
        param
        (
            [Parameter(Mandatory=$true)]
            [string]$Message,

            [Parameter(Mandatory=$false)]
            [string]$YesOption = $null,

            [Parameter(Mandatory=$false)]
            [string]$NoOption = $null,

            [Parameter(Mandatory=$false)]
            [ValidateSet("Red","Green","Yellow","Blue","Magenta","Cyan","White","DarkRed","DarkGreen","DarkYellow","DarkBlue","DarkMagenta","DarkCyan","Gray","DarkGray")]
            [string]$Colour = "Yellow",

            [Parameter(Mandatory=$false)]
            [switch]$AnyKey = $false
        )

        switch ($AnyKey)
        {
            $true 
            { 
                Write-Host "`r`n $($Message) (Press any key to continue):" -ForegroundColor $Colour -NoNewline
                $readhost = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                Start-Sleep -Seconds 2
            }
            
            default
            {
                Write-Host "`r`n $($Message) (Default is No) (y/n): " -ForegroundColor $Colour -NoNewline;
                $readhost = Read-Host

                switch ($ReadHost.ToUpper())
                { 
                    Y {Write-Host " Yes, $($YesOption)" -ForegroundColor Green; $result = $true} 
                    Default {Write-Host " No, $($NoOption)" -ForegroundColor Red; $result = $false} 
                }

                Start-Sleep -Seconds 2
                return $result
            }   
        }
    }
    #endregion

    #region Variables
    $date1Day = (Get-Date).AddDays(1)
    $date = (Get-Date -Format yyyyMMddHHmmss)
    $log = if ($env:TEMP) { "$($env:TEMP)/transcript_$($date).txt" } else { "$($env:TMPDIR)/transcript_$($date).txt" }
    $appCreate = $false
    $spnCreate = $false
    Start-Transcript -Path $log -NoClobber | Out-Null
    #endregion
    
    #region Environment
    Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true
    $null = Update-AzConfig -DisplayBreakingChangeWarning $false
    $ErrorActionPreference = "Stop"
    #endregion
}

process
{
    try
    {
        Clear-Host
        Write-Host "`r`n Data#3 Azure Hybrid Use Benefit Reporter App Preparation" -ForegroundColor Cyan

        Write-Host "`r`n This script will prepare your environment for the Data#3 Azure Hybrid Use Benefit Reporter App (D3AHUB)" -ForegroundColor White

        Write-Host "`r`n During the execution of this script, you will be prompted to enter the appropriate credentials for:" -ForegroundColor White 
        Write-Host " - Azure related tasks."
        Write-Host " - Azure AD related tasks."

        Write-Host "`r`n PLEASE NOTE: You will only be asked to log in once. Your login will be cached for the duration of the session." -ForegroundColor White
        Write-Host " If you have multiple accounts for each type of task, please log in with the appropriate account when prompted." -ForegroundColor White

        Write-Host "`r`n The Script will create and configure the following:" -ForegroundColor White
        Write-Host "`r`n AD Application Registration with a Service Principal" -ForegroundColor White
        Write-Host " - The application registration will be named '$($AppRegistrationName)'"
        Write-Host " - The credentials for application registration the will expire 1 day after creation."
        Write-Host "`r`n Data#3 will use the application registration to deploy the D3AHUB App into your Azure Tenant." -ForegroundColor White
        Write-Host "`r`n The application registration will have the following API permissions:" -ForegroundColor White
        Write-Host " - Microsoft Graph - AppRoleAssignment.ReadWrite.All (Application). This is required to assign API permissions to a Managed Identity for the D3AHUB App."
        Write-Host " - Microsoft Graph - Directory.Read.All (Application). This permission is necessary to read directory data, including users, groups, and other directory objects."
        Write-Host " - Microsoft Graph - RoleManagement.ReadWrite.Directory (Application). This is required to assign Roles to the Managed Identity for the D3AHUB App."
        Write-Host " - Microsoft Graph - User.ManageIdentities.All (Application). This is required to create the Managed Identity for the D3AHUB App."
        Write-Host "`r`n Additionally, the application registration will be assigned the following role(s) on the specified scope:" -ForegroundColor White
        Write-Host " - Role: User Access Administrator - Scope: '/'"
        Write-Host " - Role: Owner - Scope: Designated Subscription"

        $result = Get-InputOption -Message "Do you want to continue?" -YesOption "Continue" -NoOption "Exit"

        #region Prerequisites
        switch ($result)
        {
            $true
            {
                Clear-Host
                Write-Host "`r`n Checking if Management Groups are enabled ....." -ForegroundColor Yellow

                # Log into Azure
                Write-Host "`r`n Logging into Azure ..... "
                Connect-Account -ContextName "Azure" -TenantName $TenantName -SubscriptionId $SubscriptionId
                $contextAzure = Get-AzContext

                # Checking if Management Groups are enabled
                $mgs = Get-AzManagementGroup -ErrorAction SilentlyContinue

                if (!$mgs)
                {
                    Write-Host " Management Groups are not enabled. Enabling.... " -ForegroundColor Yellow
                    $mg = New-AzManagementGroup -GroupId "temp_$((new-guid).ToString().substring(0,5))" -DisplayName Temp -ParentId "/providers/Microsoft.Management/managementGroups/$($contextAzure.Tenant.Id)"
                    $mg | Remove-AzManagementGroup
                }

                Write-Host " Management Groups are enabled. Proceeding with deployment." -ForegroundColor Green
            }

            default { Write-Host "`r`n Exiting script ....."; exit -1 }
        }

        $result = Get-InputOption -Message "Do you want to continue and create the App Registration?" -YesOption "Create the App Registration" -NoOption "Exit"

        #region App Registrations
        switch ($result)
        {
            $true
            {
                Clear-Host
                Write-Host "`r`n Checking App Registrations & Service Principals ....." -ForegroundColor Yellow

                # Log into Azure AD
                Write-Host "`r`n Logging into AzureAD ..... "
                Connect-Account -ContextName "AzureAD" -TenantName $TenantName

                # Common Variables
                $application    = Get-AzADApplication -DisplayName $AppRegistrationName -ErrorAction SilentlyContinue
                $spn            = Get-AzADServicePrincipal -DisplayName $AppRegistrationName -ErrorAction SilentlyContinue

                if (!$application)  { $application = New-AzADApplication -DisplayName $AppRegistrationName -Description "App Registration for the Data#3 AHUB Reporter Tool" -Homepage "https://localhost" -ReplyUrls "https://localhost" -IdentifierUris "https://$($TenantName)/$($AppRegistrationName)"; $appCreate = $true }
                if (!$spn)          { $spn = New-AzADServicePrincipal -ApplicationId ($application | Select-Object -ExpandProperty AppId); $spnCreate = $true }
                $creds = New-AzADAppCredential -ApplicationId $application.AppId -EndDate $date1Day

                # Loop to check if Service Principal exists if its just been created.
                $count = 0
                do
                { 
                    $test = Get-AzADServicePrincipal -ObjectId $spn.Id -ErrorAction SilentlyContinue
                    if (!$test -and $count -eq 0) { 
                        Write-Host " Waiting for Service Principal '$($spn.DisplayName)' to register in Azure AD "
                    }
                    Start-Sleep -Seconds 1
                    $count++
                }
                until ($test)

                Write-Host "`r`n $(if ($appCreate) { "Created App Registration" } else { "Got App Registration" })" -ForegroundColor Green
                Write-Host " Display Name: `t$($application.DisplayName)"
                Write-Host " Client ID: `t$($application.AppId)"
                Write-Host " Secret: `t$($creds.SecretText) (Expires $($creds.EndDateTime))"
                Write-Host "`r`n $(if ($spnCreate) { "Created Service Principal" } else { "Got Service Principal" })" -ForegroundColor Green
                Write-Host " Display Name: `t$($spn.DisplayName)"
                Write-Host " Object ID: `t$($spn.Id)"
                Write-Host "`r`n Tenant and Subscription Information:" -ForegroundColor Yellow
                Write-Host " Tenant Id: `t`t$($contextAzure.Tenant.Id)"
                Write-Host " Subscription Name: `t$($contextAzure.Subscription.Name)"
                Write-Host " Subscription Id: `t$($contextAzure.Subscription.Id)"

                Get-InputOption -Message "STOP: Please record this information and pass to Data#3" -Colour Red -AnyKey
            }

            default { Write-Host "`r`n Exiting script ....."; exit -1 }
        }
        #endregion

        $result = Get-InputOption -Message "`r`n Do you want to apply API Permissions to the App Registration?" -YesOption "Apply API Permissions" -NoOption "Exit"

        #region API Permissions
        switch ($result)
        {
            $true
            {
                # Common Variables
                $msGraph        = Get-AzADServicePrincipal -DisplayName "Microsoft Graph"
                $msGraphUri     = ("https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignedTo" -f $msGraph.Id)
                $spnUri         = ("https://graph.microsoft.com/v1.0/servicePrincipals/{0}/appRoleAssignments" -f $spn.id)

                $roleIds = @{
                    "Application.Read.All"                  = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30" # Application
                    "Application.ReadWrite.All"             = "bdfbf15f-ee85-4955-8675-146e8e5296b5" # Application
                    "AppRoleAssignment.ReadWrite.All"       = "06b708a9-e830-4db3-a914-8e69da51d44f" # Application
                    "Directory.Read.All"                    = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Application
                    "Directory.ReadWrite.All"               = "19dbc75e-c2e2-444c-a770-ec69d8559fc7" # Application
                    "Group.ReadWrite.All"                   = "62a82d76-70ea-41e2-9197-370581804d09" # Application
                    "GroupMember.ReadWrite.All"             = "dbaae8cf-10b5-4b86-a4a1-f871c94c6695" # Application
                    "RoleManagement.ReadWrite.Directory"    = "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8" # Application
                    "User.ManageIdentities.All"             = "c529cfca-c91b-489c-af2b-d92990b66ce6" # Application
                    "User.Read"                             = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # Delegated
                }

                $roles = @( "AppRoleAssignment.ReadWrite.All", "Directory.Read.All", "User.ManageIdentities.All", "RoleManagement.ReadWrite.Directory" )

                Clear-Host
                Write-Host "`r`n Checking API Permissions on App Registration ....."  -ForegroundColor Yellow

                # API Permissions
                $count = 0
                $existing = $null
                foreach ($appRole in $roles)
                {
                    # Get existing Admin Consents
                    $existing = ((Invoke-AzRestMethod -Uri $spnUri -Method GET).Content | ConvertFrom-Json).Value

                    if ($roleIds[$appRole] -notin $existing.appRoleId)
                    { 
                        # Grant Admin Consent
                        $body = @{
                            principalId = $spn.id
                            resourceId  = $msGraph.Id
                            appRoleId   = $roleIds[$appRole]
                        }

                        $null = Invoke-AzRestMethod -Uri $msGraphUri -Method POST -Payload $($body | ConvertTo-Json)
                        Write-Host " Granted Admin Consent for '$($application.DisplayName)' to '$($msGraph.DisplayName)' for '$($appRole)'" -ForegroundColor Green
                    }
                    else
                    { Write-Host " Admin Consent already exists for '$($application.DisplayName)' on '$($msGraph.DisplayName)' for '$($appRole)'" -ForegroundColor Green }

                    $count++
                }
            }

            default
            { Write-Host "`r`n Exiting script ....."; exit -1 }
        }
        #endregion

        $result = Get-InputOption -Message "Do you want to apply Role Assignments to the App Registration?" -YesOption "Apply Role Assignments" -NoOption "Exit"

        #region Role Assignments
        switch ($result)
        {
            $true
            {
                Clear-Host
                Write-Host "`r`n Checking Role Assignments ....."  -ForegroundColor Yellow

                # Log into Azure AD
                Write-Host "`r`n Logging into Azure ..... "
                Connect-Account -ContextName "Azure" -TenantName $TenantName -SubscriptionId $SubscriptionId
                $contextAzure = Get-AzContext

                # Common Variables
                $roleAssignments = @(
                    @{ Role = "User Access Administrator"; Scope = "/" }
                    @{ Role = "Owner"; Scope = "/subscriptions/$($contextAzure.Subscription.Id)" }
                )

                $roleDetails = @() 
                foreach ($item in $roleAssignments)
                {
                    $roleAssigned = $false
                    $role = Get-AzRoleAssignment -ObjectId $spn.Id -Scope $item.Scope -RoleDefinitionName $item.Role 

                    if (!$role) 
                    { $role = New-AzRoleAssignment -ObjectId $spn.Id -Scope $item.Scope -RoleDefinitionName $item.Role; $roleAssigned = $true } 

                    $roleDetails += @{ role = $role; key = $item.Key }
                    Write-Host " Service Principal '$($spn.DisplayName)' $(if ($roleAssigned) { "has been" } else { "is already" }) assigned to '$($item.Scope)' with Role '$($role.RoleDefinitionName)'" -ForegroundColor Green
                }
            }

            default
            { Write-Host "`r`n Exiting script ....."; exit -1 }
        }
        #endregion
    }

    catch
    {
        if ($_.Exception.Message)
        {
            throw  "$($_.Exception.Message)"
        }
        else
        {
            throw  "$($_.Exception)"
        }
    }
    finally
    {
        #region Clean up
        Clear-Host
        Write-Host "`r`n Cleaning Up ..... " -ForegroundColor Yellow
        # Log into Azure AD
        Write-Host "`r`n Logging into AzureAD ..... "
        Connect-Account -ContextName "AzureAD" -TenantName $TenantName

        # Removing secrets
        $dateNow = Get-Date
        $keyId = $creds.KeyId
        $secrets = Get-AzADAppCredential -ApplicationId $application.AppId
        if ($secrets)
        {
            Write-Host "`r`n Removing any exhausted Credentials from App Registration $($application.DisplayName) ..... "
            # Loop through each secret
            $flag = $false
            foreach ($secret in $secrets)
            {
                $endDate = (Get-Date $secret.EndDateTime).ToLocalTime() # Time is set to UTC on App Registration 
                # Check if the secret has expired or equals the secret we created
                if ((Get-Date $endDate) -lt $dateNow -and $secret.KeyId -ne $keyId)
                {
                    # Secret has expired or equals the secret we created, delete it
                    $null = Remove-AzADAppCredential -ApplicationId $application.AppId -KeyId $secret.KeyId
                    Write-Host " Removed Secret $($secret.KeyId) from App Registration $($application.DisplayName)" -ForegroundColor Green
                    $flag = $true
                }
            }
        }

        if (!$flag)
        { Write-Host " Nothing to clean" -ForegroundColor Green }

        Write-Host "`r`n Exiting Script!`r`n" -ForegroundColor Yellow
        #endregion
    }
}

end
{
    Stop-Transcript | Out-Null
    switch ($env:TMPDIR)
    {
        {$env:TMPDIR}
        {   open -a textedit $log   }
            
        default
        {   Notepad $log   }
    }

    Write-Host "`r`n Finished!`r`n" 
}
