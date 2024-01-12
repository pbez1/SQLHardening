function Set-TextNullToNull {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $global:DSI_Server 
        ,
        [Parameter (Mandatory=$true)]
        [string] $BatchNo
        )

    $sql = "
        update dbo.sec_hardening_results
        set results = null
        where results = 'null' and batch_no = $BatchNo
        
        update dbo.sec_hardening_results
        set db_list_id = null
        where db_list_id = -1 and batch_no = $BatchNo"

    try {
        Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database 'DSI' -Query $sql
        }
    catch {
        throw "$_"
        }
    }
