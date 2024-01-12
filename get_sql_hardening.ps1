#Requires -Version 5.1
#Requires -Module @{ModuleName = "SqlHardening"; ModuleVersion = "1.0.5"}

Import-Module DsiUtils
Import-Module SqlHardening -Force

$LogObj = [PSCustomObject]@{
    BatchNo = -1
    BatchDesc = 'Retrieve SQL Hardening'
    Print = 0
    }
    
$SysParms = @{
    DSIServer = !$global:DSI_Server
    DSIDatabase = 'DSI'
    OLog = $LogObj
    }

try {
    # This is the SQL script that will perform the tests.
    $SQLTestScript = $global:ModulePath + '\SQLHardening\TestScripts\sql_hardening_tests.sql'

    # This is the PowerShell function that runs the sql hardening script defined in $SQLTestScript.
    Get-HardeningResults @SysParms -SQLTestScript $SQLTestScript -Verbose
    }
catch {
    throw $_
    }
