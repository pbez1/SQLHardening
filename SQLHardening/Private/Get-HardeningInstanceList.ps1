function Get-HardeningInstanceList {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $global:DSI_Server
        )

    # Get the unrecognized test ID from dbo.v_sec_hardening_tests.
    $sql = "
        select instance_id, instance
        from dbo.instances
        where 
            (retrieve_data = 1 and enabled = 1) 	-- Monitored instances
            or
            (retrieve_data = 0 and is_static = 1 and enabled = 1)	-- Unmonitored instances"

    try {
        Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database 'DSI' -Query $sql
        }
    catch{
        throw "$_"
        }
    }
            
