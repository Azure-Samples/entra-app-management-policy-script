function New-GuidString {
    $Guid = New-Guid

    return $Guid.Guid
}
function New-RestrictionType {
    param (
        $RestrictionTypeName,
        $State = $null
    )

    $RestrictionType = @{
        restrictionType = $RestrictionTypeName
        restrictForAppsCreatedAfterDateTime = Get-Date -Format "O"
    }

    if ($RestrictionTypeName.EndsWith("Lifetime")) {
        $RestrictionType.maxLifetime = "P1D"
    }

    if ($RestrictionTypeName -eq "asymmetricKeyLifetime") {
        $RestrictionType.certificateBasedApplicationConfigurationIds = @((New-GuidString), (New-GuidString))
    }

    if ($null -ne $State) {
        $RestrictionType.state = $State
    }

    return $RestrictionType
}

function New-Restrictions {
    param (
        $RestrictionName,
        $State = $null
    )

    $RestrictionNames = Get-RestrictionNames
    $RestrictionTypes = $RestrictionNames.$RestrictionName

    return @($RestrictionTypes | ForEach-Object {
        return New-RestrictionType $_ $State
    })
}

function New-TestTenantPolicy {
    return @{
        id = New-GuidString
        displayName = 'Default app management tenant policy'
        description = 'Default tenant policy that enforces app management restrictions on applications and service principals. To apply policy to targeted resources, create a new policy under appManagementPolicies collection.'
        isEnabled = $true
        applicationRestrictions = @{
            passwordCredentials = New-Restrictions "passwordCredentials"
            keyCredentials = New-Restrictions "keyCredentials"
        }
        servicePrincipalRestrictions = @{
            passwordCredentials = @(
                (New-RestrictionType "passwordAddition" "enabled")
                (New-RestrictionType "passwordAddition" "disabled")
            )
            keyCredentials = @()
        }
    }
}

function New-TestCustomPolicy {
    $Id = New-GuidString

    return @{
        id = $Id
        displayName = 'Test Custom Policy ' + $Id
        description = 'Test description'
        isEnabled = $true
        restrictions = @{
            passwordCredentials = @(
                (New-RestrictionType "passwordAddition" "enabled")
                (New-RestrictionType "symmetricKeyLifetime" "disabled")
            )
            keyCredentials = @(
                (New-RestrictionType "asymmetricKeyLifetime")
            )
        }
    }
}