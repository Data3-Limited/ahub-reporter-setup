#Requires -PSEdition Core
#Requires -Version 7.3

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [string] $FunctionAppName,

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
            [ValidateSet("Azure")]
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
    $date = (Get-Date -Format yyyyMMddHHmmss)
    $log = if ($env:TEMP) { "$($env:TEMP)/transcript_$($date).txt" } else { "$($env:TMPDIR)/transcript_$($date).txt" }
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
        Write-Host "`r`n Data#3 Azure Hybrid Use Benefit Reporter App Configuration" -ForegroundColor Cyan

        Write-Host "`r`n This script will enable the Data#3 Azure Hybrid Use Benefit Reporter App (D3AHUB)" -ForegroundColor White

        Write-Host "`r`n During the execution of this script, you will be prompted to enter the appropriate credentials for:" -ForegroundColor White 
        Write-Host " - Azure related tasks."

        Write-Host "`r`n PLEASE NOTE:" -ForegroundColor White
        Write-Host " - This script MUST been run after the D3AHUB Managed Application has been deployed into your Azure Tenant." -ForegroundColor White
        Write-Host " - You will only be asked to log in once. Your login will be cached for the duration of the session." -ForegroundColor White
        
        Write-Host "`r`n The Script will configure the following:" -ForegroundColor White
        Write-Host " - Enable Management Groups if not already enabled." -ForegroundColor White
        Write-Host " - Assigned the following role(s) to the D3HUB Managed Indentity on the specified scope:" -ForegroundColor White
        Write-Host "   Role: Reader - Scope: 'Tenant Root Management Group'"

        $result = Get-InputOption -Message "Do you want to continue?" -YesOption "Continue" -NoOption "Exit"

        #region Managed Identity
        switch ($result)
        {
            $true
            {
                Clear-Host
                Write-Host "`r`n Checking the Managed Identity Service Principal ....." -ForegroundColor Yellow

                # Log into Azure
                Write-Host "`r`n Logging into Azure ..... "
                Connect-Account -ContextName "Azure" -TenantName $TenantName -SubscriptionId $SubscriptionId
                $context = Get-AzContext

                # Checking if Management Groups are enabled
                Write-Host "`r`n Checking if Management Groups are enabled ....."  -ForegroundColor Yellow
                $mgs = Get-AzManagementGroup -ErrorAction SilentlyContinue

                if (!$mgs)
                {
                    Write-Host " Management Groups are not enabled. Enabling.... "
                    $mg = New-AzManagementGroup -GroupId "temp_$((new-guid).ToString().substring(0,5))" -DisplayName Temp -ParentId "/providers/Microsoft.Management/managementGroups/$($context.Tenant.Id)"
                    $mg | Remove-AzManagementGroup
                    Write-Host " Management Groups are now enabled. Proceeding with configuration."  -ForegroundColor Green
                }
                else { Write-Host " Management Groups are already enabled. Proceeding with configuration." -ForegroundColor Green }
                #endregion

                # Common Variables
                $functionApp    = Get-AzFunctionApp | Where-Object Name -eq $FunctionAppName -ErrorAction SilentlyContinue
                $spn            = Get-AzADServicePrincipal -ObjectId $functionApp.IdentityPrincipalId -ErrorAction SilentlyContinue

                if (!$functionApp)  { throw " Function App '$($FunctionAppName)' does not exist in the '$($context.Subscription.Name)' subscription" }
                if (!$spn)          { throw " Service Principal for Function App '$($FunctionAppName)' does not exist" }

                Write-Host "`r`n Checking Role Assignments ....."  -ForegroundColor Yellow

                $roleAssignments = @(
                    @{ Role = "Reader"; Scope = "/providers/Microsoft.Management/managementGroups/$($context.Tenant.Id)" }
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
    { Write-Host "`r`n Exiting script ....." -ForegroundColor Yellow }
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

    Write-Host "`r`n Finished!`r`n" -ForegroundColor Cyan
}
