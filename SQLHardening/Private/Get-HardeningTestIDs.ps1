function Get-HardeningTestIDs {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $global:DSI_Server
        )

    # Get the unrecognized test ID from dbo.v_sec_hardening_tests.
    $sql = "
        select
            'insert into #sec_hardening_tests (sec_hardening_tests_id) values (' + convert(varchar(20), sec_hardening_tests_id) + ')' as str
        from dbo.sec_hardening_tests sht
        where sht.retire_dt is null"

    try {
        $insert_out = Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database 'DSI' -Query $sql

        [string] $insert_str = ''
        foreach($ins_str in $insert_out) {
            $insert_str += $ins_str.str + "`n"
            }

        $insert_str
        }
    catch{
        throw "$_"
        }
    }
 