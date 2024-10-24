Import-Module $PSScriptRoot\AppManagementPolicies.psm1 -Force
Import-Module $PSScriptRoot\TestsHelper.psm1 -Force

BeforeDiscovery {
    $AppRestrictionNames = Get-AppRestrictionNames

    $RestrictionNames = Get-RestrictionNames

    $CheckRestrictionsTestCases = $RestrictionNames.Keys | ForEach-Object {
        @{
            Name = $_
            RestrictionTypes = $RestrictionNames.$_
        }
    }

    # Write-LogObject $CheckRestrictionsTestCases
}

Describe "ApplicationManagementPolicies" {

    Describe "Set-RestrictionState" {

        BeforeEach {
            Mock -ModuleName AppManagementPolicies Add-Member -Verifiable -MockWith {
                $InputObject.$NotePropertyName = $NotePropertyValue # mock with implementation similar to real one
            }
        }

        Describe "PolicyRestrictionType is null" {

            It "Should return without setting state" {
                Set-RestrictionState "Test" "TestRestriction"

                Should -Invoke -ModuleName AppManagementPolicies -CommandName Add-Member -Exactly 0
            }
        }

        Describe "PolicyRestrictionType is not null but state is already set" {

            It "Should not change the state to enabled" {
                $TestRestrictionType = @{
                    restrictionType = "testRestriction";
                    restrictForAppsCreatedAfterDateTime = "testdatestring";
                    state = "disabled"
                }

                Set-RestrictionState "Test" "TestRestriction" $TestRestrictionType

                Should -Invoke -ModuleName AppManagementPolicies -CommandName Add-Member -Exactly 0

                $TestRestrictionType.state | Should -Be "disabled"
            }
        }

        Describe "PolicyRestrictionType is not null and state is not set" {

            It "Should set the state as enabled" {
                $TestRestrictionType = @{
                    restrictionType = "testRestriction";
                    restrictForAppsCreatedAfterDateTime = "testdatestring";
                }

                Set-RestrictionState "Test" "TestRestriction" $TestRestrictionType

                Should -Invoke -ModuleName AppManagementPolicies -CommandName Add-Member -Exactly 1 `
                    -ParameterFilter { ($NotePropertyName -eq "state") -and ($NotePropertyValue -eq "enabled")}

                $TestRestrictionType.state | Should -Be "enabled"
            }
        }
    }

    Describe "Invoke-CheckRestrictionType" {

        BeforeEach {
            Mock -ModuleName AppManagementPolicies Set-RestrictionState -Verifiable -MockWith {
                param(
                    $PolicyType,
                    $RestrictionTypeName,
                    $PolicyRestrictionType,
                    $State
                )

                Set-RestrictionState $PolicyType $RestrictionTypeName $PolicyRestrictionType $State
            }
        }

        Describe "TenantPolicyRestrictionType is null" {

            Describe "PolicyRestrictionType is null" {

                It "Should set state 'enabled' on policy restriction type" {
                    $PolicyRestrictionTypeUpdated = Invoke-CheckRestrictionType "Test" "TestRestrictionType" $null

                    Should -Invoke -ModuleName AppManagementPolicies -CommandName Set-RestrictionState -Exactly 0

                    $PolicyRestrictionTypeUpdated | Should -Be $null
                }
            }

            Describe "PolicyRestrictionType is not null" {

                Describe "Should change state on PolicyRestrictionType" -ForEach @(
                    @{ existing = $null; new = "enabled" }
                    @{ existing = "enabled"; new = "enabled" }
                    @{ existing = "disabled"; new = "disabled" }
                 ) {

                    It ("to '" + $_.new + "' if it was previously '" + ($_.existing ?? "null or not set") + "'") {
                        $Test_PolicyRestrictionType = @{
                            restrictionType = "testRestriction"
                            state = $_.existing
                            restrictForAppsCreatedAfterDateTime = "testdatestring"
                        }

                        $PolicyRestrictionTypeUpdated = Invoke-CheckRestrictionType "Test" "TestRestrictionType" $Test_PolicyRestrictionType

                        $PolicyRestrictionTypeUpdated | Should -Not -Be $null

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Set-RestrictionState -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Test") -and `
                                ($RestrictionTypeName -eq "TestRestrictionType") -and `
                                ($PolicyRestrictionType -eq $PolicyRestrictionTypeUpdated) `
                            }

                        $PolicyRestrictionTypeUpdated.state | Should -Be $_.new
                        $Test_PolicyRestrictionType.state | Should -Be $_.existing
                    }
                }
            }

        } 

        Describe "TenantPolicyRestrictionType is not null" {

            BeforeEach {
                $Test_TenantPolicyRestrictionType = @{
                    restrictionType = "testRestriction";
                    restrictForAppsCreatedAfterDateTime = "testdatestring";
                }
            }
            
            Describe "PolicyRestrictionType is null" {

                Describe "Should return a clone of TenantPolicyRestrictionType with state set" -ForEach @(
                    @{ existing = $null; new = "disabled" }
                    @{ existing = "enabled"; new = "disabled" }
                    @{ existing = "disabled"; new = "disabled" }
                 ) {

                    It ("to '" + $_.new + "' if TenantPolicyRestrictionType state was '" + ($_.existing ?? "null or not set") + "'") {
                        $Test_TenantPolicyRestrictionType.state = $_.existing

                        $Test_PolicyRestrictionType = $null
                        
                        $PolicyRestrictionTypeUpdated = Invoke-CheckRestrictionType "Test" "TestRestrictionType" $Test_PolicyRestrictionType $Test_TenantPolicyRestrictionType

                        $PolicyRestrictionTypeUpdated | Should -Not -Be $null

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Set-RestrictionState -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Test") -and `
                                ($RestrictionTypeName -eq "TestRestrictionType") -and `
                                ($PolicyRestrictionType -eq $PolicyRestrictionTypeUpdated) `
                            }

                        $PolicyRestrictionTypeUpdated.state | Should -Be $_.new
                        $Test_TenantPolicyRestrictionType.state | Should -Be $_.existing
                    }

                }
            }

            Describe "PolicyRestrictionType is not null" {

                Describe "Should change state on PolicyRestrictionType" -ForEach @(
                    @{ existing = $null; new = "enabled" }
                    @{ existing = "enabled"; new = "enabled" }
                    @{ existing = "disabled"; new = "disabled" }
                 ) {

                    It ("to '" + $_.new + "' if it was previously '" + ($_.existing ?? "null or not set") + "'") {
                        $Test_PolicyRestrictionType = @{
                            restrictionType = "testRestriction"
                            state = $_.existing
                            restrictForAppsCreatedAfterDateTime = "testdatestring"
                        }

                        $Test_TenantPolicyRestrictionType.state = $_.existing
                        
                        $PolicyRestrictionType = Invoke-CheckRestrictionType "Test" "TestRestrictionType" $Test_PolicyRestrictionType $Test_TenantPolicyRestrictionType

                        $PolicyRestrictionTypeUpdated = Invoke-CheckRestrictionType "Test" "TestRestrictionType" $Test_PolicyRestrictionType

                        $PolicyRestrictionTypeUpdated | Should -Not -Be $null

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Set-RestrictionState -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Test") -and `
                                ($RestrictionTypeName -eq "TestRestrictionType") -and `
                                ($PolicyRestrictionType -eq $PolicyRestrictionTypeUpdated) `
                            }

                        $PolicyRestrictionTypeUpdated.state | Should -Be $_.new
                        $Test_PolicyRestrictionType.state | Should -Be $_.existing
                        $Test_TenantPolicyRestrictionType.state | Should -Be $_.existing
                    }
                }
            }
        } 
    }

    Describe "Invoke-CheckRestrictions" -ForEach $CheckRestrictionsTestCases {

        Describe $_.Name {

            BeforeAll {
                 # Save -ForEach variables because of nested -ForEach loop below
                $TestRestrictionName = $_.Name
                $TestRestrictionTypes = $_.RestrictionTypes
            }
            
            BeforeEach {
                
                Mock -ModuleName AppManagementPolicies Invoke-CheckRestrictionType -Verifiable -MockWith {
                    param (
                        $PolicyType,
                        $RestrictionTypeName,
                        $PolicyRestrictionType,
                        $TenantPolicyRestrictionType = $null
                    )

                    Invoke-CheckRestrictionType $PolicyType $RestrictionTypeName $PolicyRestrictionType $TenantPolicyRestrictionType
                }
            }

            Describe "TenantPolicyRestrictions is null" {

                Describe "PolicyRestrictions is null" {

                    It "Should not call Invoke-CheckRestrictionType" {
                        Invoke-CheckRestrictions "Tenant" $_.Name $null $null

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Exactly 0
                    }

                }

                Describe "PolicyRestrictions is not null" {

                    It "Should call Invoke-CheckRestrictionType for each restrictionType" {
                        $Test_PolicyRestrictions = New-Restrictions $_.Name # Use existing restriction state as null

                        $PolicyRestrictionsUpdated = Invoke-CheckRestrictions "Tenant" $_.Name $Test_PolicyRestrictions $null

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Exactly $_.RestrictionTypes.Count
                        
                        foreach ($RestrictionType in $_.RestrictionTypes) {
                            $Test_PolicyRestrictionType = $Test_PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionType }
                            $PolicyRestrictionTypeUpdated = $PolicyRestrictionsUpdated | Where-Object { $_.restrictionType -eq $RestrictionType }

                            Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Times 1 `
                                -ParameterFilter { `
                                    ($PolicyType -eq "Tenant") -and `
                                    ($RestrictionTypeName -eq $RestrictionType) -and `
                                    ($PolicyRestrictionType -eq $Test_PolicyRestrictionType) `
                                }

                            $PolicyRestrictionTypeUpdated.state | Should -Be "enabled" # updated restriction should have state enabled
                            $Test_PolicyRestrictionType.state | Should -Be $null # Should not change existing state
                        }
                    }

                }

            }

            Describe "TenantPolicyRestrictions is not null" {

                BeforeEach {
                    [array]$Test_TenantPolicyRestrictions = New-Restrictions $TestRestrictionName "enabled" # Use existing state as enabled
                }

                Describe "PolicyRestrictions is null" {

                    It "Should call Invoke-CheckRestrictionType for each restrictionType" {
                        $PolicyRestrictionsUpdated = Invoke-CheckRestrictions "Custom" $TestRestrictionName $null $Test_TenantPolicyRestrictions

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Exactly $_.RestrictionTypes.Count

                        $PolicyRestrictionsUpdated | Should -Not -Be $null

                        foreach ($RestrictionType in $_.RestrictionTypes) {
                            $PolicyRestrictionTypeUpdated = $PolicyRestrictionsUpdated | Where-Object { $_.restrictionType -eq $RestrictionType }
                            $Test_TenantPolicyRestrictionType = $Test_TenantPolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionType }

                            Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Times 1 `
                                -ParameterFilter { `
                                    ($PolicyType -eq "Custom") -and `
                                    ($RestrictionTypeName -eq $RestrictionType) -and `
                                    ($PolicyRestrictionType -eq $null) -and `
                                    ($TenantPolicyRestrictionType -eq $Test_TenantPolicyRestrictionType) `
                                }

                            $PolicyRestrictionTypeUpdated.state | Should -Be "disabled" # restriction state should be set as enabled
                            $Test_TenantPolicyRestrictionType.state | Should -Be "enabled" # Tenant restriction state should not change
                        }
                    }
                }

                Describe "PolicyRestrictions is not null" -ForEach $_.RestrictionTypes {

                    Describe ("Custom PolicyRestrictions only have '" + $_ + "' restriction type") {
                    
                        BeforeEach {
                            $Test_PolicyRestrictions = @(
                                @{
                                    restrictionType = $_
                                    restrictForAppsCreatedAfterDateTime = "testdatestring"
                                }
                            )
                        }

                        It "Should call Invoke-CheckRestrictionType for each restrictionType" {
                        
                            $Test_PolicyRestrictionsUpdated = Invoke-CheckRestrictions "Custom" $TestRestrictionName $Test_PolicyRestrictions $Test_TenantPolicyRestrictions

                            Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Exactly $TestRestrictionTypes.Count

                            $Test_PolicyRestrictionsUpdated | Should -Not -Be $null
                            $Test_PolicyRestrictions.Count | Should -Be $Test_PolicyRestrictions.Count
                            $Test_PolicyRestrictionsUpdated.Count | Should -Be $Test_TenantPolicyRestrictions.Count

                            foreach ($RestrictionType in $_.RestrictionTypes) {
                                $Test_PolicyRestrictionType = $Test_PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionType }
                                $Test_TenantPolicyRestrictionType = $Test_TenantPolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionType }
                                $Test_PolicyRestrictionTypeUpdated = $Test_PolicyRestrictionsUpdated | Where-Object { $_.restrictionType -eq $RestrictionType }

                                Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictionType -Times 1 `
                                    -ParameterFilter { `
                                        ($PolicyType -eq "Custom") -and `
                                        ($RestrictionTypeName -eq $RestrictionType) -and `
                                        ($PolicyRestrictionType -eq $Test_PolicyRestrictionType) -and `
                                        ($TenantPolicyRestrictionType -eq $Test_TenantPolicyRestrictionType) `
                                    }
                                
                                if ($null -ne $Test_PolicyRestrictionType) {
                                    $Test_PolicyRestrictionType.state | Should -Be "enabled"
                                }

                                if ($null -ne $Test_PolicyRestrictionTypeUpdated) {
                                    $Test_PolicyRestrictionTypeUpdated.state | Should -Be "disabled"
                                }
                            }
                        }

                    }

                }

            }

        }

    }

    Describe "Invoke-CheckAppRestrictions" {

        BeforeEach {
            $RestrictionNames = Get-RestrictionNames

            $Test_Tenant_Policy = New-TestTenantPolicy

            Mock -ModuleName AppManagementPolicies Invoke-CheckRestrictions -Verifiable -MockWith {
                param (
                    $PolicyType,
                    $RestrictionName,
                    $PolicyRestrictions,
                    $TenantPolicyRestrictions = $null
                )

                Invoke-CheckRestrictions $PolicyType $RestrictionName $PolicyRestrictions $TenantPolicyRestrictions
            }
        }

        Describe "TenantPolicyAppRestrictions is null" -ForEach $AppRestrictionNames {

            Describe $_.Name {

                BeforeEach {
                    $AppRestrictionsType = $_.Type
                }
    
                Describe "AppPolicyRestrictions is null" {

                    It "Should not call Invoke-CheckRestrictions" {
                        Invoke-CheckAppRestrictions "Tenant" $_.Name $null

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly 0
                    }
                }

                Describe "AppPolicyRestrictions is not null" {

                    It ("Should call Invoke-CheckRestrictions " + $RestrictionNames.Keys.Count + " times") {
                        $Test_PolicyAppRestrictions = $Test_Tenant_Policy.$AppRestrictionsType

                        $PolicyAppRestrictionsUpdated = Invoke-CheckAppRestrictions "Tenant" $_.Name $Test_PolicyAppRestrictions

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly $RestrictionNames.Keys.Count

                        $PolicyAppRestrictionsUpdated | Should -Not -Be $null
                        $PolicyAppRestrictionsUpdated.Count | Should -Be $Test_PolicyAppRestrictions.Count

                        foreach ($RestrictionNameKey in $RestrictionNames.Keys) {
                            $Test_PolicyRestrictions = $Test_PolicyAppRestrictions.$RestrictionNameKey
                            $PolicyRestrictionsUpdated = $PolicyAppRestrictionsUpdated.$RestrictionNameKey

                            Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly 1 `
                                -ParameterFilter { `
                                    ($PolicyType -eq "Tenant") -and `
                                    ($RestrictionName -eq $RestrictionNameKey) -and`
                                    ($PolicyRestrictions.Count -eq $Test_PolicyRestrictions.Count) `
                                }

                            foreach ($RestrictionType in $PolicyRestrictionsUpdated) {
                                $ExistingRestriction = $Test_PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionType }

                                if ($null -eq $ExistingRestriction) {
                                    continue                                    
                                }

                                if ($null -eq $ExistingRestriction.state) {
                                    $RestrictionType.state | Should -Be "enabled"
                                } else {
                                    $RestrictionType.state | Should -Be $ExistingRestriction.state
                                }
                            }

                        }
                    }
                }
            }
        }

        Describe "TenantPolicyAppRestrictions is not null" {

            BeforeEach {
                # Custom policy restrictions only populates from applicationRestrictions
                $Test_TenantPolicyAppRestrictions = $Test_Tenant_Policy.applicationRestrictions
            }

            Describe "AppPolicyRestrictions is null" {

                It ("Should call Invoke-CheckRestrictions " + $RestrictionNames.Keys.Count + " times") {
                    $PolicyAppRestrictionsUpdated = Invoke-CheckAppRestrictions "Custom" "Restrictions" $null $Test_TenantPolicyAppRestrictions

                    Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly $RestrictionNames.Keys.Count

                    $PolicyAppRestrictionsUpdated | Should -Not -Be $null
                    $PolicyAppRestrictionsUpdated.Count | Should -Be $Test_TenantPolicyAppRestrictions.Count

                    foreach ($RestrictionNameKey in $RestrictionNames.Keys) {
                        $PolicyRestrictionsUpdated = $PolicyAppRestrictionsUpdated.$RestrictionNameKey
                        $Test_TenantPolicyRestrictions = $Test_TenantPolicyAppRestrictions.$RestrictionNameKey

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Custom") -and `
                                ($RestrictionName -eq $RestrictionNameKey) -and `
                                ($PolicyRestrictions -eq $null) -and `
                                ($TenantPolicyRestrictions.Count -eq $Test_TenantPolicyRestrictions.Count) `
                            }

                        foreach ($RestrictionType in $PolicyRestrictionsUpdated) {
                            $RestrictionType.state | Should -Be "disabled"
                        }

                        foreach ($RestrictionType in $Test_TenantPolicyRestrictions) {
                            $RestrictionType.state | Should -Be $null
                        }

                    }
                }
            }

            Describe "AppPolicyRestrictions is not null" {

                It ("Should call Invoke-CheckRestrictions " + $RestrictionNames.Keys.Count + " times") {
                    $Test_Custom_Policy = New-TestCustomPolicy

                    $Test_PolicyAppRestrictions = $Test_Custom_Policy.restrictions;

                    # Write-Host ""Restrictions" app restrictions. Count: " $Test_PolicyAppRestrictions.Keys.Count $Test_TenantPolicyAppRestrictions.Keys.Count
                    # Write-LogObject $Test_PolicyAppRestrictions
                    # Write-LogObject $Test_TenantPolicyAppRestrictions

                    $PolicyAppRestrictionsUpdated = Invoke-CheckAppRestrictions "Custom" "Restrictions" $Test_PolicyAppRestrictions $Test_TenantPolicyAppRestrictions

                    $PolicyAppRestrictionsUpdated | Should -Not -Be $null

                    Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly $RestrictionNames.Keys.Count

                    foreach ($RestrictionNameKey in $RestrictionNames.Keys) {
                        [array]$Test_PolicyRestrictions = $Test_PolicyAppRestrictions.$RestrictionNameKey
                        [array]$Test_TenantPolicyRestrictions = $Test_TenantPolicyAppRestrictions.$RestrictionNameKey
                        [array]$PolicyRestrictionsUpdated = $PolicyAppRestrictionsUpdated.$RestrictionNameKey

                        # Write-Host "Test - $RestrictionNameKey"
                        # Write-LogObject $Test_PolicyRestrictions
                        # Write-LogObject $Test_TenantPolicyRestrictions
                        # Write-LogObject $PolicyRestrictionsUpdated
    
                        # PS is weird, empty array is equal to $null
                        if ($null -ne $PolicyRestrictionsUpdated) {
                            $PolicyRestrictionsUpdated.Count | Should -Be $Test_TenantPolicyRestrictions.Count
                        }

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckRestrictions -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Custom") -and `
                                ($RestrictionName -eq $RestrictionNameKey) -and `
                                ($PolicyRestrictions.Count -eq $Test_PolicyRestrictions.Count) `
                                # ($TenantPolicyAppRestrictions.Count -eq $Test_TenantPolicyRestrictions.Count) ` # because empty arrays are $null
                            }

                        foreach ($RestrictionType in $PolicyRestrictionsUpdated) {
                            $ExistingRestriction = $Test_PolicyRestrictions | Where-Object { $_.restrictionType -eq $RestrictionType.restrictionType }
                            
                            if ($null -eq $ExistingRestriction) {
                                $RestrictionType.state | Should -Be "disabled"
                                continue
                            }
                            
                            if ($null -eq $ExistingRestriction.state) {
                                $RestrictionType.state | Should -Be "enabled"
                            } else {
                                $RestrictionType.state | Should -Be $RestrictionType.state
                            }
                        }

                    }
                }
            }
        }

    }

    Describe "Invoke-CheckApplicationManagementPolicy" {

        BeforeEach {
            $AppRestrictionNames = Get-AppRestrictionNames

            $AppRestrictionNameKeys = $AppRestrictionNames | ForEach-Object {
                return $_.Type
            }

            $Test_Tenant_Policy = New-TestTenantPolicy

            Mock -ModuleName AppManagementPolicies Invoke-CheckAppRestrictions -Verifiable {}
        }

        Describe "TenantPolicy is null" {

            BeforeEach {
                Mock -ModuleName AppManagementPolicies Invoke-CheckAppRestrictions -Verifiable `
                    -ParameterFilter {
                        $PolicyType -eq "Tenant"
                    } `
                    -MockWith {
                        param (
                            $PolicyType,
                            $AppRestrictionsName,
                            $PolicyAppRestrictions,
                            $TenantPolicyAppRestrictions = $null
                        )
                    
                        return $PolicyAppRestrictions
                    }
            }

            It ("Should call Invoke-CheckAppRestrictions " + $AppRestrictionNames.Count + " times, for each app restriction") {

                $TenantPolicyUpdated = Invoke-CheckApplicationManagementPolicy "Tenant" $Test_Tenant_Policy

                Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckAppRestrictions -Exactly $AppRestrictionNames.Count

                $TenantPolicyUpdated | Should -Not -Be $null

                foreach ($Key in $TenantPolicyUpdated.PSObject.Properties.Name) {
                    # Write-Host "Key: $Key"

                    if ($AppRestrictionNameKeys -Contains $Key) {
                        $AppRestriction = $AppRestrictionNames | Where-Object { $_.Type -eq $Key }
                        $AppRestrictionType = $AppRestriction.Type

                        $Test_TenantAppRestrictions = $Test_Tenant_Policy.$AppRestrictionType
                        $AppRestrictionUpdated = $TenantPolicyUpdated.$AppRestrictionType

                        $AppRestrictionUpdated | Should -Not -Be $null
                        $AppRestrictionUpdated.Keys.Count | Should -Be $Test_TenantAppRestrictions.Keys.Count

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckAppRestrictions -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Tenant") -and `
                                ($AppRestrictionsName -eq $AppRestriction.Name) -and `
                                ($PolicyAppRestrictions -eq $Test_Tenant_Policy.$AppRestrictionType) -and `
                                ($TenantPolicyAppRestrictions -eq $null) `
                            }
    
                        continue
                    }

                    # Write-Host $Key $TenantPolicyUpdated.$Key $Test_Tenant_Policy.$Key
                    $TenantPolicyUpdated.$Key | Should -Be $Test_Tenant_Policy.$Key
                }
            }

        }

        Describe "TenantPolicy is not null" {

            BeforeEach {
                Mock -ModuleName AppManagementPolicies Invoke-CheckAppRestrictions -Verifiable `
                    -ParameterFilter {
                        $PolicyType -eq "Custom"
                    } `
                    -MockWith {
                        param (
                            $PolicyType,
                            $AppRestrictionsName,
                            $PolicyAppRestrictions,
                            $TenantPolicyAppRestrictions = $null
                        )
                    
                        return $PolicyAppRestrictions
                    }
            }

            It ("Should call Invoke-CheckAppRestrictions " + $AppRestrictionNames.Count + " times, for each app restriction with TenantPolicyAppRestrictions") {

                $Test_Custom_Policy = New-TestCustomPolicy

                $CustomPolicyUpdated = Invoke-CheckApplicationManagementPolicy "Custom" $Test_Custom_Policy $Test_Tenant_Policy

                $CustomPolicyUpdated | Should -Not -Be $null

                foreach ($Key in $CustomPolicyUpdated.PSObject.Properties.Name) {
                    # Write-Host "Key: $Key"

                    if ("restrictions" -eq $Key) {
                        $Test_TenantAppRestrictions = $Test_Tenant_Policy.applicationRestrictions
                        $AppRestrictionUpdated = $CustomPolicyUpdated.restrictions

                        $AppRestrictionUpdated | Should -Not -Be $null
                        $AppRestrictionUpdated.Keys.Count | Should -Be $Test_TenantAppRestrictions.Keys.Count

                        Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckAppRestrictions -Exactly 1 `
                            -ParameterFilter { `
                                ($PolicyType -eq "Custom") -and `
                                ($AppRestrictionsName -eq "Restrictions") -and `
                                ($PolicyAppRestrictions -eq $Test_Custom_Policy.restrictions) -and `
                                ($TenantPolicyAppRestrictions -eq $Test_Tenant_Policy.applicationRestrictions) `
                            }
    
                        continue
                    }

                    # Write-Host $Key $CustomPolicyUpdated.$Key $Test_Custom_Policy.$Key
                    $CustomPolicyUpdated.$Key | Should -Be $Test_Custom_Policy.$Key
                }

            }

        }
    }

    Describe "Invoke-CheckApplicationManagementPolicies" {

        BeforeEach {
            $Test_Tenant_Policy = New-TestTenantPolicy
            
            $Test_Custom_Policy_1 = New-TestCustomPolicy
            $Test_Custom_Policy_2 = New-TestCustomPolicy

            $Test_Custom_Policies = @(
                $Test_Custom_Policy_1
                $Test_Custom_Policy_2
            )

            Mock -ModuleName AppManagementPolicies Invoke-CheckApplicationManagementPolicy -Verifiable `
                -ParameterFilter { `
                    $PolicyType -eq "Tenant" `
                } `
                -MockWith { `
                    return $Test_Tenant_Policy `
                }

            Mock -ModuleName AppManagementPolicies Update-ApplicationManagementPolicy -Verifiable `
                -ParameterFilter { `
                    $PolicyType -eq "Tenant" `
                } `
                -MockWith { `
                    return $Test_Tenant_Policy `
                }

            Mock -ModuleName AppManagementPolicies Invoke-CheckApplicationManagementPolicy -Verifiable {}

            Mock -ModuleName AppManagementPolicies Update-ApplicationManagementPolicy -Verifiable {}
        }

        It "Should call Invoke-CheckApplicationManagementPolicy once for Tenant Policy" {

            Invoke-CheckApplicationManagementPolicies $Test_Tenant_Policy $Test_Custom_Policies

            Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckApplicationManagementPolicy -Exactly 1 `
                -ParameterFilter { `
                    ($PolicyType -eq "Tenant") -and `
                    ($Policy -eq $Test_Tenant_Policy) -and `
                    ($TenantPolicy -eq $null) `
                }

            Should -Invoke -ModuleName AppManagementPolicies -CommandName Update-ApplicationManagementPolicy -Exactly 1 `
                -ParameterFilter { `
                    ($PolicyType -eq "Tenant") -and `
                    ($Policy -eq $Test_Tenant_Policy) `
                }
        }

        It "Should call Invoke-CheckApplicationManagementPolicy once for each Custom Policy" {
            Mock -ModuleName AppManagementPolicies Invoke-CheckApplicationManagementPolicy -Verifiable `
                -ParameterFilter { `
                    ($PolicyType -eq "Custom") -and `
                    ($Policy -eq $Test_Custom_Policy_1) `
                } `
                -MockWith { `
                    return $Test_Custom_Policy_1 `
                }

            Mock -ModuleName AppManagementPolicies Invoke-CheckApplicationManagementPolicy -Verifiable `
                -ParameterFilter { `
                    ($PolicyType -eq "Custom") -and `
                    ($Policy -eq $Test_Custom_Policy_2) `
                } `
                -MockWith { `
                    return $Test_Custom_Policy_2 `
                }

            Mock -ModuleName AppManagementPolicies Update-ApplicationManagementPolicy -Verifiable {} `
                -ParameterFilter { `
                    ($PolicyType -eq "Custom") `
                }

            Invoke-CheckApplicationManagementPolicies $Test_Tenant_Policy $Test_Custom_Policies

            foreach ($Custom_Policy in $Test_Custom_Policies) {
                Should -Invoke -ModuleName AppManagementPolicies -CommandName Invoke-CheckApplicationManagementPolicy -Exactly 1 `
                    -ParameterFilter { `
                        ($PolicyType -eq "Custom") -and `
                        ($Policy -eq $Custom_Policy) -and `
                        ($TenantPolicy -eq $Test_Tenant_Policy) `
                    }

                Should -Invoke -ModuleName AppManagementPolicies -CommandName Update-ApplicationManagementPolicy -Exactly 1 `
                    -ParameterFilter { `
                        ($PolicyType -eq "Custom") -and `
                        ($Policy -eq $Custom_Policy) `
                    }
            }
        }
    }
}
