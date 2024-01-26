<#
.Synopsis
This function initiates the SQL hardening testing process.

.Description
This function initiates the the testing process that verifies whether or not PacificSource SQL Servers comply with the current
SQL Hardening standards.

This function retrieves a list of servers from the DSK inventory system then executes a T-SQL script for each of them that performs
the actual SQL Hardening tests.

The list of tests resides in the DSI table: "sec_hardening_tests"

.Parameter DSIServer
This is the name of the SQL Server instance hosting the DSI database.

.Parameter DSIDatabase
This is the database name of the DSI database.

.Parameter OLog
This is is a PSCustomObject that facilitates use of the DSI execution logging capability and contains the following members:
    BatchNo - Specifies the batch number (-1 = create new batch; 0 = ignore logging; > 0 = use this as the batch number to log to.)
    BatchDesc = 'Retrieve SQL Hardening' - This describes the purpose of the batch.
    Print = 0 = Determines whether the logged message will also be printed to the standard-out stream.

NOTE: THIS PARARMETER IS PROVIDED FOR FUTURE USE.  IT IS NOT USED CURRENTLY.

.Parameter SQLTestScript
This is the full path to the file containing the T-SQL Test script mentioned in the description above.

.Example
.
Get-HardeningResults `
    -ProtectionGroup "DynDB1" `
    -DestServer "sdc-sqldw2"

This will bring the destination volumes for the protection group "DynDB1" and destination server "sdc-sqldw2" back online.

.Example
.
$LogObj = [PSCustomObject]@{
    BatchNo = -1
    BatchDesc = 'Retrieve SQL Hardening'
    Print = 0
    }
    
$SysParms = @{
    DSIServer = 'spf-sv-delldb'
    DSIDatabase = 'DSI'
    OLog = $LogObj
    }

$SQLTestScript = 'c:\SQLHardening\sql_hardening_tests.sql'
Get-HardeningResults @SysParms -SQLTestScript $SQLTestScript -Verbose

This will write test results for all of the currently enabled SQL Server instances into the "sec_hardening_results" table.
It will use the T-SQL Test script file located in the "c:\SQLHardening" folder with the file name "sql_hardening_tests.sql".
Because DSI execution logging is not yet implemented in this function, the $OLog parameter will be ignored.
#>
function Get-HardeningResults {
    [cmdletbinding()]

    param(
        [Parameter (Mandatory=$false)]
        [string] $DSIServer = $DSI_Server
        ,
        [Parameter (Mandatory=$false)]
        [string] $DSIDatabase = $DSI_Database
        ,
        [Parameter (Mandatory=$false)]
        [PSCustomObject] $OLog
        ,
        [Parameter (Mandatory=$true)]
        [string] $SQLTestScript 
        )
        
    # Set some global variables in case the caller passed in something different than was read from the JSON file.
    $global:DSI_Server = $DSIServer
    $global:DSI_Database = $DSIDatabase

    # Get some needed data from DSI.
    $batch_data = Get-BatchNo                           #Creates a new SQL hardening test batch and returns the batch_no and batch_id.
    $batch_no = $batch_data.batch_no
    $unrecognized_test_id = Get-UnrecognizedTestID
    $hardening_test_ids = Get-HardeningTestIDs
    $instance_list = Get-HardeningInstanceList

    # Save a list of the test ID's that will be used for this batch.  This list is necessary to idnetify the list of tests
    # that were used on any given date and is used when reviewing past test batches.
    try {Save-BatchTestSet -BatchNo $batch_no}
    catch {throw "$_"}

    # Call the SQL Hardening test script for each instance of SQL Server to be tested.
    foreach ($id in $instance_list) {
        $instance_id = $id.instance_id
        $instance_nm = $id.instance
        Write-Output "Instance: $instance_nm ($instance_id)"
        
        $db_list = Get-DatabaseListAsInsert -TargetServer $instance_id
        try {
            $instance_version = Get-VersionFromSource -TargetServer $instance_nm

            # Get the SQL Hardening test script from the file system and replace the value tokens with the values retrieved from DSI.
            $sql = Get-Content -Path $SQLTestScript -Raw
                # $newstreamreader = New-Object System.IO.StreamReader($SQLTestScript)
                # $sql = $newstreamreader.ReadToEnd()
                # $newstreamreader.Dispose()

            # Replace the variable tokens with the information from DSI
            $sql = $sql -replace "0--!instance_id!>", $instance_id
            $sql = $sql -replace "<!instance!>", $instance_nm
            $sql = $sql -replace "0--!Unrecognized_Result!>", $unrecognized_test_id
            $sql = $sql -replace "--!InsertHardeningTests!>", $hardening_test_ids
            $sql = $sql -replace "--!InsertDatabaseList!>", $db_list
            $sql = $sql -replace "0--!InstanceVersion!>", $instance_version
            $sql = $sql -replace "0--!batch_no!>", $batch_no

            $insert_out = Invoke-Sqlcmd @sql_parms -ServerInstance $instance_nm -Database "master" -Query $sql

            # Consolodate the $insert_out array from each SQL Server into a single string to avoid multiple calls to Invoke_Sqlcmd
            # to insert the test data.
            [string] $insert_str = ''
            foreach($ins_str in $insert_out) {
                $insert_str += $ins_str.insert_string + "`n"
                }
            
            #Submit the insert string to DSI for inserting into the "sec_hardening_results" table.
            Invoke-Sqlcmd @sql_parms -ServerInstance $DSIServer -Database "dsi" -Query $insert_str
            }
        catch {
            Write-Output "Error processing database: $instance_nm : $_"
            }
        }

    Set-TextNullToNull -BatchNo $batch_no
    }
