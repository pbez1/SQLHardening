# SQLHardening

## Table of Contents
[Overveiw](#overveiw)<br>
[Operation](#operation)<br>
- [Installation](#installation)<br>
- [Configuration](#configuration)<br>
- [Entry Point](#entry-point)<br>
- [Note on Execution](#note-on-execution)<br>

[Theory of Operation](#theory-of-operation)<br>
- [The T-SQL Script](#the-t-sql-script)<br>
- [Create A New Test](#create-a-new-test)<br>
- [Create An Exemption](#create-an-exemption)<br>
- [Create An Implicit Exemption](#create-an-implicit-exemption)<br>

[Functions](#functions)<br>
- [Get-HardeningResults](#get-hardeningresults)<br>

[SQLHardening JSON File](#sqlhardening-json-file)<br>

[Top](#sqlhardening)
___
## Overveiw
This module collects information from a list of SQL Servers and verifies whether the settings on the individual SQL Servers meet Pacificsource security requirements.  (Note: The SQLHardening module is a subsystem of the DSI inventory system and will not function as a stand-alone application.)

SQL Server configuration settings include many that have implications with respect to security.  Because these settings are configurable and can change from time to time, periodic checks to assure they still comply with the published standard is a prudent thing to do.

This module provides a framework for running a selected battery of tests against the various active SQL Servers to assure compliance.

[Top](#sqlhardening)
___
## Operation
### Installation:
The SQLHardening module is available in the local DBA PowerShell repository and must be installed on the server from which the tests will be run.  The following PowerShell script can be used to install the module onto the local computer:
``` PowerShell
Install-Module SQLHardening -Repository PSRepl -Scope AllUsers -Force
```

NOTE:
This module requires the present of the "DSIUtils" module on the same computer.  DSIUtils is also available in the local DBA PowerShell repository and may be installed on the local system with the following command:
``` PowerShell
Install-Module DSIUtils -Repository PSRepl -Scope AllUsers -Force
```
---

[Top](#sqlhardening)
___
### Configuration:
The tests peformed by SQL Hardening are maintained in a T-SQL script file.  The location of that file must be defined in the "SQLHardening.json" file in the "SqlTestsPath" element.

Here is an example of a typical "SQLHardening.json" file:
``` JSON
{
    "MinVerDsiUtils"        : "1.0.5",
    "SqlTestsFolder"        : "TestScripts",
    "HardeningTestsFile"    : "sql_hardening_tests.sql",
    ".SqlCmdParms"          : [
                             "AbortOnError=True",
                             "TrustServerCertificate=True"
                            ]
}
```

[Top](#sqlhardening)
___
### Entry Point:
The entry point of the module is the function "Get-HardeningResults", and it accepts the following paramters:
- DSIServer<br>
    This is the name of the SQL Server instance hosting the DSI database.  This parameter is optional and defaults to "spf-sv-delldb"

- DSIDatabase<br>
    This is the name of the database hosting the DSI objects.  This parameter is optional and defaults to "DSI".  (It's included in the event the DSI database is renamed.)

- OLog<br>
    This is an object used to configure logging and is comprised of three sub parameters:<br>
    1) BatchNo:
        - -1 = Start a new log batch.
        -  0 = Don't start a new log batch.
        - >0 = Use the existing batch with this batch number.
    2) BatchDesc:
        - This is the description the batch will be referenced by.
    3) Print:
        - 1 = Print the logged output to standard out (usually the screen).
        - 0 = Do not print the logged output.</pre>

- SQLTestScript<br>
    This is a UNC path describing the location of the T-SQL test script.  This path MUST INCLUDE THE TEST SCRIPT FILENAME.

[Top](#sqlhardening)
___
### Note on Execution:
If the SQL Hardening process is initiated from a system that does not support an integrated PowerShell interpreter such as Tidal Workload Automation, the entry point function must be called from a PowerShell executable file.  Below is an example of a very simple script/file that would accomplish that:
``` PowerShell
Import-Module DSIUtils
Import-Module SQLHardening

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
   
try {
    $SQLTestScript = '\\sdc-dbaesmaqa\c$\Program Files\WindowsPowerShell\Modules\SQLHardening\1.0.6\TestScripts\sql_hardening_tests.sql'

    Get-HardeningResults @SysParms -SQLTestScript $SQLTestScript -Verbose
    }
catch {
    throw $_
    }
```


[Top](#sqlhardening)
___
## Theory of Operation
The SQLHardening module is a subsystem of the DSI inventory system and as such cannot be run as a stand-along application without the DSI system begin present.

Since the module requires a list of target SQL Servers to process, it retrieves that list from the DSI database.  This list is then used to retrieve a list of databases for each SQL Server instance as well.

Once this preliminary information has been gathered, each SQL Server instance is tested, the test results returned and then stored.

The part of the module responsible for testing and collecting the results of the tests is a T-SQL script contained in a file called "sql_hardening_test.sql".  This file's contents are read into memory and subsequently submitted to each SQL Server instance in turn for testing.

Within the T-SQL test script are "place holder" tokens of the form <!InsertHardeningTests!> which are replaced by SQL instance specific information for each server begin tested.  These place-holder tokens are used in lieu of the parameters that would be possible if this script was contained within a stored procedure.  Stored procedures, as the name implies, are stored in the database in which they're defined.  Since it's not practical to create a stored procedure containing the T-SQL test script for each server being tested, this "place holder" replacement technique allows the T-SQL test script to be uniquely "parameterized" for each SQL Server instance in the list.

Once the T-SQL test script's placeholders have been replaced with information specfic to that particular SQL instance being tested, the script is submitted to the SQL Server in question and executed.  The output of that T-SQL test script is then saved into the "sec_hardening_results" table in the DSI database.

The data written to the "sec_hardening_results" table is then available for analyis.


[Top](#sqlhardening)
___
### The T-SQL Script:
The T-SQL test script is constructed such that the code for each test is containted in its own section of the script.  That is to say, the code for each test does not rely on values that exist elsewhere in the script.  All variables and data retrievals necessary to perform the test are contained within that test's individual section.  This leads to duplication of code, to be sure, but it assures that changes made in one section of the script will not affect other sections.  Moreover, changes to security policy or SQL environments are easier to accommodate over time since adding new code and remove old code from the script can be accomplished relatively easily without introducing side effects or bugs.

The script works as follows:
1. "Place holder" tokens are replaced prior to submitting the script to SQL server.
2. Once submitted, the script populates the #sec_hardening_tests table with a list of tests queried from the "sec_hardening_tests" table in the DSI database.
3. The script then loops through these ID's one at a time
4. Within the loop is a large If..ElseIf..Else statement that effectively determines which test code section to execute based on the If..Else condition that matches the test ID.

Note that adding a new code section to the T-SQL test script requires that a new entry also be made in the "sec_hardening_test" table in the DSI database and their IDs must match.

#### Create A New Test:
A test can be created by executing the following stored procedure
``` SQL
exec dbo.up_sec_hardening_test_add
	@test_nm = '',             -- varchar(50)
	@accepted_values = '',     -- varchar(max)
	@test_desc = ''            -- varchar(max)
```

Where,
``` SQL
@test_nm            :	varchar(50)         (Required)
```
The name of the test to be added.  
``` SQL
@accepted_values    :	varchar(max)        (Required)
	The name of the database (if appropriate) to be exempted as specified in the
	db_list: table.  If this parameter is left null, the exemption will be 
	applied to the entire instance.

@test_desc          :	varchar(max)        (Required)
	The name of the test to be exempted as specified in the "sec_hardening_test"
	table.
```


[Top](#sqlhardening)
___
### Exemptions:
The DSI SQL Hardening subsystem supports the notion of test exemptions.  That is, all SQL Servers are required to conform to the rules governed by SQL hardening.  There are times, however, when those rules must be waived to facilitate certain necessary functionality.  When that happens, an exemption must be configured in the SQL Hardening subsystem.  

In addition, there are occasionally rules that depend upon the exemption status of other related rules.  For example, if the "sa" account is allowed to exist as an exemption (SA Exists), we would not want the "SA Disabled" test to fail even though "SA Disabled" is not specifically exempted itself.  The SQL Hardening System allows for rules to be implicitly related in such a way that if one rule is exempted, its related rules are exempted also.

#### Create An Exemption:
An exemption can be created by executing the following stored procedure:
``` SQL
exec dbo.up_sec_hardening_exempt_add
	@instance = null,  -- sysname
	@dbname = null,	   -- sysname
	@test_nm = '',	   -- varchar(50)
	@domain_nm = null, -- sysname
	@notes = ''        -- varchar(max)</pre>
```
Where,
``` SQL
@instance		:	sysname         (Required)
	This is the name of the instance to be exempted as specified in the "instances"
	table.  
@dbname			:	sysname         (Optional)
	The name of the database (if appropriate) to be exempted as specified in the
	db_list: table.  If this parameter is left null, the exemption will be 
	applied to the entire instance.
@test_nm		:	nvarchar(max)   (Required)
	The name of the test to be exempted as specified in the "sec_hardening_test"
	table.
@domain_nm		:	sysname         (Optional)
	The password associated with the login name.
@notes			:	varchar(max)    (Optional)
	A convenient place to annotate the exemption.  
```

#### Create An Implicit Exemption:
Currently, implicit exemptions must be create by manually editing the "sec_hardening_tests_related" table in the DSI database.

Two values must be supplied:
- exempt_id - This is the primary test ID.  Dependent tests will adopt the exemption status of this test.  Enter the test id of the primary test from the value in the "sec_hardening_test_id" column of the "sec_hardening_tests" table in the DSI database.
- dependent_id - This is the dependent test ID.  Dependent tests will adopt the exemption status of the test identified in the "exempt_id" column.  Enter the test id of the dependent test from the value in the "sec_hardening_test_id" column of the "sec_hardening_tests" table in the DSI database.

[Top](#sqlhardening)
___
## Functions:
### *Get-HardeningResults*
#### __Description__
This function initiates the the testing process that verifies whether or not PacificSource SQL Servers comply with the current SQL Hardening standards.

This function retrieves a list of servers from the DSK inventory system then executes a T-SQL script for each of them that performs the actual SQL Hardening tests.

The list of tests resides in the DSI table: "sec_hardening_tests"

#### __Parameter__
- DSIServer<br>
    This is the name of the SQL Server instance hosting the DSI database.

- DSIDatabase<br>
    This is the database name of the DSI database.

[Top](#sqlhardening)
___
## SQLHardening JSON File
The following configurtion items can be found in the PhaUtil.json file.<br>
Note: Elements preceded by a period "." are instantiated as global variables but without the prepended period in the variable name.  Otherwise, they are instantiated as local variables within the module.<br>
Example: .SqlCmdParms is instantiated as $global:SqlCmdParms.

|Variable                 | Description                                                                                                              |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------|
| MinVerDsiUtils          | This is the minimum version of the DsiUtils module that will support this SQLHardengin module                            |
| SqlTestsFolder          | This is the location of the T-SQL script file containing the tests to perform                                            |
| HardeningTestsFile      | This is the name of the SQL Hardening tests file.  (It is a T-SQL script file)                                           |
| .SqlCmdParms            | This is the SQL Server instance hosting the MDS database                                                                 |
|                         |                                                                                                                          |

[Top](#sqlhardening)
___
