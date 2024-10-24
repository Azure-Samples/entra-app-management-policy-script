[CmdletBinding()]
param()

$MSGraph_Environments = Get-MgEnvironment

$API_Endpoint_Default = "https://graph.microsoft.com/"
$API_Version = "beta"
$API_URI_Policies = "/policies"
$API_URI_Tenant_Policy = "/defaultAppManagementPolicy"
$API_URI_App_Policies = "/appManagementPolicies"
$Current_Environment = "Global"

function Get-AppRestrictionNames {
    return @(
        @{
            Name = "Application"
            Type = "applicationRestrictions"
        }
        @{
            Name = "Service Principal"
            Type = "servicePrincipalRestrictions"
        }
    )
}

function Get-RestrictionNames {
    return @{
        "passwordCredentials" = @(
            "passwordAddition"
            "passwordLifetime"
            "symmetricKeyAddition"
            "symmetricKeyLifetime"
            "customPasswordAddition"
        )
        "keyCredentials" = @(
            "asymmetricKeyLifetime"
        )
    }
}

function ConvertTo-JsonString {
    param (
        $Object
    )

    if ($null -eq $Object) {
        return "NULL"
    }

    if (($Object -is [array]) -and (0 -eq $Object.Count)) {
        return "[]"
    }

    $Json = $Object | ConvertTo-Json -Depth 99

    if ($null -eq $Json) {
        return "[]"
    }

    return $Json
}

function Write-LogObject {
    param (
        $Object
    )
    
    Write-Host (ConvertTo-JsonString $Object)
}

function Write-DebugObject {
    param (
        $Object
    )
    
    Write-Debug (ConvertTo-JsonString $Object)
}

function Start-Login {
    param (
        [string]$Environment = "Global",
        [string]$TenantId = "common"    
    )

    # set env for current session
    $Current_Environment = $Environment;

    Write-Debug "Connecting to MS Graph using params: `
        -NoWelcome `
        -Scopes `"Policy.Read.All Policy.ReadWrite.ApplicationConfiguration`" `
        -Environment $Current_Environment `
        -TenantId $TenantId"

    Connect-MgGraph `
        -NoWelcome `
        -Scopes "Policy.Read.All Policy.ReadWrite.ApplicationConfiguration" `
        -Environment $Current_Environment `
        -TenantId $TenantId
}

function Start-Logout {
    Disconnect-MgGraph
}

function Get-APIEndpoint {
    $Environment = $MSGraph_Environments | Where-Object { $_.Name -eq $Current_Environment }

    if ($null -ne $Environment) {
        return $Environment.GraphEndpoint + "/"
    }

    return $API_Endpoint_Default
}

function Get-TenantApplicationManagementPolicy {
    $Tenant_Policy_URL = (Get-APIEndpoint) + $API_Version + $API_URI_Policies + $API_URI_Tenant_Policy

    Write-Debug "GET $Tenant_Policy_URL"

    Write-Progress "Getting tenant policy."
    $Tenant_Policy = Invoke-MGGraphRequest -Method GET -URI $Tenant_Policy_URL

    if ($null -eq $Tenant_Policy) {
        throw "Failed to get Tenant policy."
    }

    return $Tenant_Policy
}

function Get-CustomApplicationManagementPolicies {
    $App_Policies_URL = (Get-APIEndpoint) + $API_Version + $API_URI_Policies + $API_URI_App_Policies

    Write-Debug "GET $App_Policies_URL"

    Write-Progress "Getting all Custom application management policies."
    $App_Policies_Response = Invoke-MGGraphRequest -Method GET -URI $App_Policies_URL

    if (($null -eq $App_Policies_Response) -or ($null -eq $App_Policies_Response.Value)) {
        throw "Failed to list 'Custom' policies"
    }

    if (0 -eq $App_Policies_Response.Value.Count) {
        Write-Host "There are no 'Custom' policies in the tenant. Exiting."
        return @() # return empty array
    }

    return $App_Policies_Response.Value
}

function Get-CustomApplicationManagementPolicy {
    param (
        $Id
    )

    $App_Policy_URL = (Get-APIEndpoint) + $API_Version + $API_URI_Policies + $API_URI_App_Policies + "/" + $Id

    Write-Debug "GET $App_Policy_URL"

    Write-Progress "Getting all Custom application management policies."
    $App_Policy = Invoke-MGGraphRequest -Method GET -URI $App_Policy_URL

    if ($null -eq $App_Policy) {
        throw "Failed to get 'Custom' policiy with id $Id"
    }

    Write-Host "Found 'Custom' policy:"
    Write-LogObject $App_Policy

    return $App_Policy
}

function Update-ApplicationManagementPolicy {
    param (
        $PolicyType,
        $Policy,
        $WhatIf = $true
    )

    if ("Tenant" -eq $PolicyType) {
        $API_URI_Policy = $API_URI_Tenant_Policy
    } else {
        $API_URI_Policy = "$API_URI_App_Policies/" + $Policy.id
    }
    
    $Policy_URL = (Get-APIEndpoint) + $API_Version + $API_URI_Policies + $API_URI_Policy
    $Body = $Policy | ConvertTo-Json -Depth 99

    Write-Debug "PATCH $Policy_URL"
    Write-Debug "Body: $Body" 

    if ($false -eq $WhatIf) {
        Write-Progress "Updating '$PolicyType' policy."

        Invoke-MGGraphRequest -Method Patch -URI $Policy_URL -Body $Body

        if ("Tenant" -eq $PolicyType) {
            $PolicyUpdated = Get-TenantApplicationManagementPolicy
        } else {
            $PolicyUpdated = Get-CustomApplicationManagementPolicy $Policy.id
        }

        Write-Host ("Successfully updated the '$PolicyType' policy. '" + $Policy.displayName + " (" + $Policy.id + ")'")
        
    } else {
        Write-Warning "What-If mode is ON. updated policy is logged here"

        $PolicyUpdated = $Policy | Select-Object -Property *

        Write-Host ("Updated '$PolicyType' policy. '" + $Policy.displayName + " (" + $Policy.id + ")'")
    }

    Write-LogObject $PolicyUpdated

    return $PolicyUpdated
}

function Set-RestrictionState {
    param (
        $PolicyType,
        $RestrictionTypeName,
        $PolicyRestrictionType,
        $State
    )
    
    if ($null -eq $PolicyRestrictionType) {
        Write-Debug "No '$RestrictionTypeName' restriction defined on '$PolicyType' policy."
        return
    }

    #  State cannot be null, convert to enabled if being set to null
    if ($null -eq $State) {
        $State = "enabled"
    }

    Write-Debug "'$RestrictionTypeName' restriction is set on '$PolicyType' policy."

    $PreviousState = $PolicyRestrictionType.state

    # If state not set on policy restriction, set to new state
    if ($null -eq $PreviousState) {
        $PolicyRestrictionType | Add-Member -Force -NotePropertyName state -NotePropertyValue $State

        Write-Debug "Changed '$RestrictionTypeName' restriction state from '$PreviousState' to '$State' on '$PolicyType' policy."
        return
    }

    Write-Debug "Retaining '$RestrictionTypeName' restriction state '$PreviousState' on '$PolicyType' policy."
}

function Invoke-CheckRestrictionType {
    param (
        $PolicyType,
        $RestrictionTypeName,
        $PolicyRestrictionType,
        $TenantPolicyRestrictionType = $null
    )

    if ($null -eq $TenantPolicyRestrictionType) {
        if ($null -eq $PolicyRestrictionType) {
            return
        }

        # Clone the restriction type 
        $PolicyRestrictionTypeUpdated = $PolicyRestrictionType | Select-Object -Property *

        # If state not set on App Policy restriction, set to enabled
        Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionTypeUpdated
        return $PolicyRestrictionTypeUpdated
    }

    if ($null -eq $PolicyRestrictionType) {
        #  If App Policy doesn't have restriction type, shallow clone from Tenant Policy
        #  and set state to disabled
        Write-Debug "'$RestrictionTypeName' restriction missing on '$PolicyType' policy. Cloning it from 'Tenant' policy with 'disabled' state"

        # clone restriction type from Tenant policy and clear out state
        $PolicyRestrictionTypeUpdated = $TenantPolicyRestrictionType | Select-Object -ExcludeProperty state

        # set state as disabled on cloned custom policy restriction type
        Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionTypeUpdated "disabled"
        return $PolicyRestrictionTypeUpdated
    }

    # Clone the restriction type 
    $PolicyRestrictionTypeUpdated = $PolicyRestrictionType | Select-Object -Property *

    # If state not set on App Policy restriction, set to enabled
    Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionTypeUpdated
    return $PolicyRestrictionTypeUpdated
}

function Invoke-CheckRestrictions {
    param (
        $PolicyType,
        $RestrictionName,
        $PolicyRestrictions,
        $TenantPolicyRestrictions = $null
    )

    $RestrictionNames = Get-RestrictionNames

    $PolicyRestrictionsUpdated = [System.Collections.ArrayList]::new()

    if ($null -eq $TenantPolicyRestrictions) {
        if ($null -eq $PolicyRestrictions) {
            Write-Debug "No '$RestrictionName' restrictions defined on '$PolicyType' policy."
            return
        }

        Write-Debug "Checking '$RestrictionName' restrictions on '$PolicyType' policy."

        foreach ($RestrictionTypeName in $RestrictionNames.$RestrictionName) {
            $PolicyRestrictionType = $PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }

             $RestrictionTypeUpdated = Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType

            # If RestrictionType is not null add it to the list
            if ($null -ne $RestrictionTypeUpdated) {
                [void]$PolicyRestrictionsUpdated.Add($RestrictionTypeUpdated)
            }
        }

        Write-Debug ("Returning " + $PolicyRestrictionsUpdated.Count + "'$RestrictionName' restrictions for '$PolicyType' policy.")
        Write-DebugObject @($PolicyRestrictionsUpdated)

        return $PolicyRestrictionsUpdated
    }

    # If App Policy doesn't have the restrictions, clone from Tenant Policy (excluding state)
    if ($null -eq $PolicyRestrictions) {
        $PolicyRestrictions = @()
    }

    Write-Debug "Checking '$RestrictionName' restrictions on '$PolicyType' policy."

    # Create empty list of updated restrictions
    foreach ($RestrictionTypeName in $RestrictionNames.$RestrictionName) {
        $PolicyRestrictionType = $PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }
        $TenantPolicyRestrictionType = $TenantPolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionTypeName }
        
        $RestrictionTypeUpdated = Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType $TenantPolicyRestrictionType 

        # If RestrictionType is not null add it to the list
        if ($null -ne $RestrictionTypeUpdated) {
            [void]$PolicyRestrictionsUpdated.Add($RestrictionTypeUpdated)
        }
    }

    Write-Debug ("Returning " + $PolicyRestrictionsUpdated.Count + "'$RestrictionName' restrictions for '$PolicyType' policy.")
    Write-DebugObject @($PolicyRestrictionsUpdated)

    return $PolicyRestrictionsUpdated
}

function Invoke-CheckAppRestrictions {
    param (
        $PolicyType,
        $AppRestrictionsName,
        $PolicyAppRestrictions,
        $TenantPolicyAppRestrictions = $null
    )

    $RestrictionNames = Get-RestrictionNames

    $PolicyAppRestrictionsUpdated = @{}
    
    if ($null -eq $TenantPolicyAppRestrictions) {
        if ($null -eq $PolicyAppRestrictions) {
            Write-Debug "No '$AppRestrictionsName' app restrictions defined on '$PolicyType' policy."
            return
        }

        Write-Debug "Checking '$AppRestrictionsName' app restrictions on '$PolicyType' policy."

        foreach ($RestrictionName in $RestrictionNames.Keys) {
            $PolicyRestrictionsUpdated = Invoke-CheckRestrictions $PolicyType $RestrictionName $PolicyAppRestrictions.$RestrictionName

            if ($null -eq $PolicyRestrictionsUpdated) {
                $PolicyRestrictionsUpdated = @()
            }

            $PolicyAppRestrictionsUpdated.$RestrictionName = @($PolicyRestrictionsUpdated)
        }

        Write-Debug "Returning '$AppRestrictionsName' app restriction for '$PolicyType' policy."
        Write-DebugObject $PolicyAppRestrictionsUpdated

        return $PolicyAppRestrictionsUpdated
    }

    # If App Policy doesn't have the app restrictions, copy over from Tenant Policy
    if ($null -eq $PolicyAppRestrictions) {
        Write-Debug "No '$AppRestrictionsName' app restrictions defined on '$PolicyType' policy."

        $PolicyAppRestrictions = @{}
    }

    Write-Debug "Checking '$AppRestrictionsName' app restrictions on '$PolicyType' policy."

    foreach ($RestrictionName in $RestrictionNames.Keys) {
        $PolicyRestrictionsUpdated = Invoke-CheckRestrictions $PolicyType $RestrictionName $PolicyAppRestrictions.$RestrictionName $TenantPolicyAppRestrictions.$RestrictionName

        if ($null -eq $PolicyRestrictionsUpdated) {
            $PolicyRestrictionsUpdated = @()
        }

        $PolicyAppRestrictionsUpdated.$RestrictionName = @($PolicyRestrictionsUpdated)
    }

    Write-Debug "Returning '$AppRestrictionsName' app restriction for '$PolicyType' policy."
    Write-DebugObject $PolicyAppRestrictionsUpdated

    return $PolicyAppRestrictionsUpdated
}

function Invoke-CheckApplicationManagementPolicy {
    param (
        $PolicyType,
        $Policy,
        $TenantPolicy = $null
    )

    # Clone the policy object
    $PolicyUpdated = $Policy | Select-Object -Property *

    Write-Debug ("Checking '$PolicyType' Policy: '" + $Policy.displayName + " (" + $Policy.id + ")'")

    if ($null -eq $TenantPolicy) {
        $PolicyUpdated.applicationRestrictions = Invoke-CheckAppRestrictions $PolicyType "Application" $Policy.applicationRestrictions
        $PolicyUpdated.servicePrincipalRestrictions = Invoke-CheckAppRestrictions $PolicyType "Service Principal" $Policy.servicePrincipalRestrictions

        return $PolicyUpdated
    }

    # Custom restrictions in restservices (API) layer are populated from applicationRestrictions on om\workflows (DS) layer
    $PolicyUpdated.restrictions = Invoke-CheckAppRestrictions $PolicyType "Restrictions" $Policy.restrictions $TenantPolicy.applicationRestrictions

    return $PolicyUpdated
}

function Invoke-CheckApplicationManagementPolicies {
    param (
        $Tenant_Policy,
        $App_Policies,
        $WhatIf = $true
    )

    Write-Host ("'Tenant' policy: '" + $Tenant_Policy.displayName + "' (" + $Tenant_Policy.id + ")")
    Write-LogObject $Tenant_Policy

    $TenantPolicyUpdated = Invoke-CheckApplicationManagementPolicy "Tenant" $Tenant_Policy

    Update-ApplicationManagementPolicy "Tenant" $TenantPolicyUpdated $WhatIf

    foreach ($Policy in $App_Policies) {
        Write-Host ("'Custom' policy: '" + $Policy.displayName + "' (" + $Policy.id + ")")
        Write-LogObject $Policy
    
        $CustomPolicyUpdated = Invoke-CheckApplicationManagementPolicy "Custom" $Policy $Tenant_Policy

        Update-ApplicationManagementPolicy "Custom" $CustomPolicyUpdated $WhatIf
    }
}