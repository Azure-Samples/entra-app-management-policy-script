[CmdletBinding()]
param(
    [Parameter(
        HelpMessage="Environment to connect to as listed in `Get-MgEnvironment`. Default: Global"
    )]
    [string]$Environment = "Global",
    [Parameter(
        HelpMessage="Environment to connect to as listed in `Get-MgEnvironment`. Default: None"
    )]
    [string]$TenantId = "common",
    [Parameter(
        HelpMessage="-WhatIf=true will run the script in a what-if mode and only log the updated policies `
         without actually updating them in Entra ID. Run with -WhatIf=false to update the policies. Default: True"
    )]
    [bool]$WhatIf = $true
)

Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force

$SecondBeforeScriptResumes = 20

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode in ON"
    Write-Warning "The script was run with no parameters or with '-WhatIf `$true`'."
    Write-Warning "The script will not update the application management policies in Entra ID but will log the updated policies."
    Write-Warning "To update the policies in Entra ID, re-run the script with What-If mode off using param '-WhatIf `$false`'."

    Start-Sleep 5
} else {
    Write-Warning "What-If mode is OFF."
    Write-Warning "The script was run with '-WhatIf `$false`'."
    Write-Warning "The script will update application management policies in Entra ID."
    Write-Warning "Stop the script (using Control + C) to cancel if this was not intentional..."

    $SecondsRemaining = $SecondBeforeScriptResumes
    
    while ($SecondsRemaining -gt 0) {
        Write-Progress "Are you sure you want to continue?" -Status "Time remaining before script resumes:" -SecondsRemaining $SecondsRemaining
        Start-Sleep 1
        
        $SecondsRemaining -= 1
    }
}

# Login to MS Graph interactively
# Use Global Admin creds at prompt
Start-Login -Environment $Environment -TenantId $TenantId

# Get Tenant Application Management Policy
$Tenant_Policy = Get-TenantApplicationManagementPolicy
Write-Host "Found 'Tenant' policy"

# Get Custom Application Management Policies
$App_Policies = Get-CustomApplicationManagementPolicies
Write-Host "Found" $App_Policies.Count "'Custom' policies"

# Check Tenant Application Management Policy and
# update application management policies accordingly
Invoke-CheckApplicationManagementPolicies $Tenant_Policy $App_Policies $WhatIf

Start-Logout

if ($true -eq $WhatIf) {
    Write-Warning "What-If mode is ON"
    Write-Warning "The script was run with no parameters or with '-WhatIf `$true`'."
    Write-Warning "No application management policies were updated in Entra ID."
} else {
    Write-Warning "What-If mode is OFF."
    Write-Warning "The script was run with '-WhatIf `$false`'."
    Write-Warning "Operation complete! Please check the policies via logs or MS Graph API to make sure everything looks OK."
    Write-Warning "Please review logs to investigate and report any errors in execution. Please report all issues to Entra ID team."
}