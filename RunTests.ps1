# PowerShell Unit Test framework - Pester (https://pester.dev/)
Import-Module Pester

# Set Root Location
$RootFolder = $PSScriptRoot
Set-Location $RootFolder

# Create Pester configuration.
$PesterConfiguration = @{
    Filter = @{
        # Tag = 'Only' # Add -Tag 'Only' to only run a subset of Describe or It blocks
    }
    Should = @{
        ErrorAction = 'Continue'
    }
    Output = @{
        Verbosity = 'Detailed'
    }
    CodeCoverage = @{
        Enabled = $false
        # Enabled = $true
        Path = 'AppManagementPolicies.psm1' # All functional code is in this module
        OutputFormat = 'JaCoCo'
        OutputEncoding = 'UTF8'
        OutputPath = "$RootFolder\Pester-Coverage.xml"
    }
    TestResult = @{
        Enabled = $false
        # Enabled = $true
        OutputPath = "$RootFolder\Pester-Test.xml"
        OutputFormat = 'NUnitXml'
        OutputEncoding = 'UTF8'
    }
}

$Config = New-PesterConfiguration -Hashtable $PesterConfiguration

# Invoke pester with the configuration hashtable
Invoke-Pester -Configuration $Config