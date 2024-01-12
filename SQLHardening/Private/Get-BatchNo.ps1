function Get-BatchNo {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $global:DSI_Server 
        ,
        [Parameter (Mandatory=$false)]
        [switch] $ReadOnly
        )

    if ($ReadOnly) {
        $sql = "
            declare @batch_no bigint

            -- Get the next batch number
            select @batch_no = max(batch_no) from dbo.sec_hardening_batch shb

            -- Handle the case where there are no rows in the sec_hardending_batch table yet.
            if @batch_no is null
                set @batch_no = 1

            select sec_hardening_batch_id as id, @batch_no as batch_no from dbo.sec_hardening_batch shb where batch_no = @batch_no"
        }
    else {
        $sql = "
            declare @batch_no bigint

            -- Get the next batch number
            select @batch_no = max(batch_no) + 1 from dbo.sec_hardening_batch shb

            -- Handle the case where there are no rows in the sec_hardending_batch table yet.
            if @batch_no is null
                set @batch_no = 1

            insert into dbo.sec_hardening_batch (batch_no, test_dt)
            values (
                @batch_no,	-- batch_no - bigint
                GETDATE()	-- test_dt - datetime
                )

            select scope_identity() as id, @batch_no as batch_no"
        }

    try {
        Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database 'DSI' -Query $sql
        }
    catch {
        throw "$_"
        }
    }
