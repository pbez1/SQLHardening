function Save-BatchTestSet {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $global:DSI_Server 
        ,
        [Parameter (Mandatory=$true)]
        [int64] $BatchNo
        )

    $sql = "
        declare 
            @msg    varchar(max),
            @batch_id   bigint

        select @batch_id = shb.sec_hardening_batch_id from dbo.sec_hardening_batch shb where shb.batch_no = $BatchNo

        if @batch_id is not null and @batch_id > 0 begin
            begin try
                insert into dbo.sec_hardening_batch_tests (sec_hardening_batch_id, sec_hardening_tests_id) 
                (select @batch_id, sec_hardening_tests_id from dbo.sec_hardening_tests sht where sht.retire_dt is null)
                end try
            begin catch
                set @msg = 'Error inserting the batch test ID''s for the new batch: ' + convert(varchar(50), $BatchNo) + '.  Process aborted.'
                raiserror(@msg, 11, 1)
                end catch
            end 
        else begin
            set @msg = 'Error retrieving the `"sec_hardening_batch_id`" for the new batch: ' + convert(varchar(50), $BatchNo) + '.  Process aborted.'
            raiserror(@msg, 11, 1)
            end"

    try {
        Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database 'DSI' -Query $sql
        }
    catch {
        throw "$_"
        }
    }
