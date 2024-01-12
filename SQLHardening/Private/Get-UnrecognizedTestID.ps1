function Get-UnrecognizedTestID {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $global:DSI_Server 
        )

    # Get the unrecognized test ID from dbo.v_sec_hardening_tests.
    $sql = "select sec_hardening_tests_id from dbo.v_sec_hardening_tests sht where test_nm = 'Unrecognized Result'"
    try {
        (Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database 'DSI' -Query $sql).sec_hardening_tests_id
        }
    catch{
        throw "$_"
        }
    }
