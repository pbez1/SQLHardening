set nocount on

declare 
	@ad_hoc_distribution		smallint,
	@auto_close_status			smallint,
	@batch_no					bigint,
	@builtin_groups				smallint,
	@builtin_groups_txt			nvarchar(60),
	@class						tinyint,
	@clr						smallint,
	@clr_permissions			smallint,
	@clr_permissions_txt		sysname,
	@cmdshell					smallint,
	@cross_ownership			smallint,
	@dbname						sysname,
	@def_trace_enabled			smallint,
	@def_trace_running			smallint,
	@dt							datetime,
	@err_num					int,
	@fetch_stat					int,			-- We save @@FETCH_STATUS in this var so we can reiterate without fetching again if error occurs.,
	@guest_connection			varchar(255),
	@ins_batch_no				bigint, 
	@ins_db_list_id				bigint, 
	@ins_instance_id 			bigint, 
	@ins_results				varchar(255),
	@ins_sec_hardening_tests_id	bigint, 
	@insert_str					varchar(max),	-- Returns the Insert statement to the calling program.
	@instance					sysname,
	@instance_id				bigint,
	@kr_connect					char(1),
	@kr_disabled				smallint,
	@kr_exists					smallint,
	@kr_exists_txt				varchar(128),
	@log_batch					bigint,
	@msg						varchar(max),
	@print						bit = 1,
	@public_permissions			smallint,
	@public_permissions_txt		nvarchar(60),
	@public_role				smallint,
	@public_role_txt			nvarchar(60),
	@remote_access				smallint,
	@remote_admin				smallint,
	@rpt_proc					varchar(128),
	@sa_disabled				smallint,
	@sa_exists					smallint,
	@sa_exists_txt				varchar(128),
	@scan_startup_apps			smallint,
	@sec_hardening_tests_id		bigint,
	@sql						nvarchar(max),
	@state_desc					nvarchar(60),
	@tmp						sysname,
	@trustworthy_name			varchar(128),
	@trustworthy_status			varchar(255),
	@unrecognized_test			bigint,
	@version					int,
	@win_local_groups			smallint,
	@win_local_groups_txt		nvarchar(60)

-- Initialize variables
if object_id('tempdb..#inserts') is not null
	drop table #inserts

create table #inserts (
	batch_no					bigint not null,
	instance_id					bigint not null,
	db_list_id					bigint null,
	sec_hardening_tests_id		bigint not null,
	results						varchar(255) null
	)

if object_id('tempdb..#sec_hardening_tests') is not null
	drop table #sec_hardening_tests

create table #sec_hardening_tests (
	sec_hardening_tests_id	bigint not null
	)

if object_id('tempdb..#db_list') is not null
	drop table #db_list

create table #db_list (
	db_list_id		bigint			not null,
	dbname			nvarchar(128)	not null
	)

--!InsertHardeningTests!>

--!InsertDatabaseList!>

-- Initialize variables required for error handling.
set @batch_no = 0--!batch_no!>
set @unrecognized_test = 0--!Unrecognized_Result!>
set @instance_id = 0--!instance_id!>
set @instance = '<!instance!>'

-- Get the first test id
select @sec_hardening_tests_id = min(sht.sec_hardening_tests_id) from #sec_hardening_tests sht	

while @sec_hardening_tests_id is not null begin
	begin try
		if @sec_hardening_tests_id = 1 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- SA Exists -- SA should not exists.  It should be overwritten with the name "Kylo Ren".  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Initialize variables
			set @sa_exists_txt = null
		
			select @sa_exists_txt = name from sys.sql_logins where lower(name) = 'sa'

			if @sa_exists_txt is not null and @sa_exists_txt <> '' 
				set @sa_exists = 1
			else
				set @sa_exists = 0

			-- Record the output in the sec_hardening_results table.
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @sa_exists)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @sa_exists as sa_exists
			end
		
		else if @sec_hardening_tests_id = 2 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- SA Disabled -- SA should be disabled if it exists, though it should have been overwrittend with the name "Kylo Ren".  (1 = Enabled; 0 = Disabled; NULL = NA)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Initialize variables
			set @sa_disabled = null
			set @sa_exists_txt = null
		
			select @sa_exists_txt = name from sys.sql_logins where lower(name) = 'sa'

			-- If SA doesn't exist, there's no point in checking whether it's disabled or not.  If SA doesn't exist then is_disabled = NULL.
			if @sa_exists_txt is not null and @sa_exists_txt <> '' begin
				-- Get the "is_disabled" status.
				select @sa_disabled = is_disabled from sys.sql_logins where lower(name) = 'sa'
				end

			-- Record the output in the sec_hardening_results table.
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @sa_disabled)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @sa_disabled as sa_exists
			end

		else if @sec_hardening_tests_id = 3 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Kylo Ren Exists -- The Kylo Ren account should exist.  (1 = Exists; 0 = Doesn't Exist)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Initialize variables
			set @kr_exists_txt = null
			set @kr_exists = null
		
			-- See if Kylo Ren exists.
			select @kr_exists_txt = name from sys.sql_logins where lower(name)='kylo ren'

			if @kr_exists_txt is not null and @kr_exists_txt <> ''
				set @kr_exists = 1
			else
				set @kr_exists = 0

			-- Record the output in the sec_hardening_results table.
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @kr_exists)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, cast(@kr_exists as varchar(10)) as sa_exists
			end

		else if @sec_hardening_tests_id = 4 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Kylo Ren Login Disabled -- The Kylo Ren login permission should be disabled.  (1 = Enabled; 0 = Disabled; NULL = NA)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Initialize variables
			set @kr_exists_txt = null
			set @kr_disabled = null

			-- See if Kylo Ren exists.
			select @kr_exists_txt = name from sys.sql_logins where lower(name)='kylo ren'

			-- If Kylo Ren doesn't exist, there's no point in checking whether it's disabled or not.  If Kylo Ren doesn't exist then @kr_disabled = NULL.
			if @kr_exists_txt is not null and @kr_exists_txt <> '' begin
				-- Get Kylo Ren disabled status.
				select @kr_disabled = is_disabled from sys.sql_logins where lower(name)='kylo ren'
				end

			-- Record the output in the sec_hardening_results table.
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @kr_disabled)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @kr_disabled as sa_exists
			end

		else if @sec_hardening_tests_id = 5 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Kylo Ren Connection -- The Kylo Ren connection permission should be Granted or Null.  (G = Grant; D = Deny; NULL = NA)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Initialize variables
			set @kr_exists_txt = null
			set @kr_connect = null

			-- See if Kylo Ren exists.
			select @kr_exists_txt = name from sys.sql_logins where lower(name)='kylo ren'

			-- If Kylo Ren doesn't exist, there's no point in checking whether it can connect or not.  If Kylo Ren doesn't exist then @kr_connect = NULL.
			if @kr_exists_txt is not null and @kr_exists_txt <> '' begin
				-- Get Kylo Ren connection status.
				select @kr_connect = sp2.state 
				from 
					sys.server_principals sp 
					inner join sys.server_permissions sp2 on sp.principal_id = sp2.grantee_principal_id 
				where 
					lower(name)='kylo ren'
					and sp2.type = 'COSQ'
				end

			-- Record the output in the sec_hardening_results table.
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @kr_connect)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @kr_connect as sa_exists
			end


	----------------------------------------------------------------------------------------------------------
	-- Configurations (from sys.configurations)
	----------------------------------------------------------------------------------------------------------

		else if @sec_hardening_tests_id = 6 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- xp_cmdshell -- The "xp_cmdshell" configuration should be disabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- xp_cmdshell: Checks to see if "xp_cmdshell" is enabled.  It should be disabled.
			set @cmdshell = 0

			select @cmdshell = cast(value as smallint) from master.sys.configurations where name = 'xp_cmdshell'

			-- Record the output in the sec_hardening_results table.
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @cmdshell)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @cmdshell as sa_exists
			end

		else if @sec_hardening_tests_id = 7 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- CLR Support -- Support for Common Language Runtime (CLR) should be disabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "clr" is enabled.  It should be disabled.
			set @clr = 0

			select @clr = cast(value as smallint) from master.sys.configurations where name = 'clr enabled'
	
			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @clr)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @clr as sa_exists
			end

		else if @sec_hardening_tests_id = 8 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Remote Access
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "remote access" is enabled.  It should be disabled.
			set @remote_access = 0

			select @remote_access = cast(value as smallint) from master.sys.configurations where name = 'remote access'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @remote_access)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @remote_access as sa_exists
			end

		else if @sec_hardening_tests_id = 9 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Remote Admins Connection -- The "Remove Admins Connection" configuration should be disabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "remote admin connections" is enabled.  It should be disabled.
			set @remote_admin = 0

			select @remote_admin = cast(value as smallint) from master.sys.configurations where name = 'remote admin connections'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @remote_admin)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @remote_admin as sa_exists
			end

		else if @sec_hardening_tests_id = 10 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Scan for startup procs -- The "Scan for startup procs" configuration should be disabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "scan for startup procs" is enabled.  It should be disabled.
			set @scan_startup_apps = 0

			select @scan_startup_apps = cast(value as smallint) from master.sys.configurations where name = 'scan for startup procs'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @scan_startup_apps)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @scan_startup_apps as sa_exists
			end

		else if @sec_hardening_tests_id = 12 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Default Trace Enabled -- The default trace should be enabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if the default trace is enabled.  It should be enabled.
			set @def_trace_enabled = 0

			select @def_trace_enabled = cast(value as smallint) from master.sys.configurations where name = 'default trace enabled'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @def_trace_enabled)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @def_trace_enabled as sa_exists
			end

		else if @sec_hardening_tests_id = 13 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Default Trace Running
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "scan for startup procs" is enabled.  It should be disabled.
			set @def_trace_running = 0

			select @def_trace_running = cast(value_in_use as smallint) from master.sys.configurations where name = 'default trace enabled'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @def_trace_running)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @def_trace_running as sa_exists
			end

		else if @sec_hardening_tests_id = 16 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Ad Hoc Distributed Queries -- Ad Hoc Distributed Queries should be disabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "scan for startup procs" is enabled.  It should be disabled.
			set @ad_hoc_distribution = 0

			select @ad_hoc_distribution = cast(value_in_use as smallint) from master.sys.configurations where name = 'Ad Hoc Distributed Queries'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @ad_hoc_distribution)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @ad_hoc_distribution as sa_exists
			end

		else if @sec_hardening_tests_id = 17 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Cross DB Ownership Chaining -- Cross DB Ownership Chaining should be disabled.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------
	
			-- Checks to see if "scan for startup procs" is enabled.  It should be disabled.
			set @cross_ownership = 0

			select @cross_ownership = cast(value_in_use as smallint) from master.sys.configurations where name = 'cross db ownership chaining'

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @cross_ownership)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @cross_ownership as sa_exists
			end

		else if @sec_hardening_tests_id = 11 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Guest User Connection -- The "Guest User Connection" permission to all databases should be revoked.  (1 = Not Revoked; 0 = Revoked)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			-- Create a temporary table to hold the database information we collect.
			if object_id('tempdb..#instance_dbs') is not null
				drop table #instance_dbs

			create table #instance_dbs (
				instance_id	bigint,
				instance	sysname,
				dbname		sysname, 
				state_desc	nvarchar(60), 
				connection	smallint
				)

			-- Get a list of databases from the instance.
			insert into #instance_dbs (instance_id, instance, dbname, state_desc) (
				select @instance_id, @instance, name, state_desc
				from master.sys.databases where lower(name) not in ('master', 'msdb', 'tempdb', 'model', 'distribution')
				)
					
			-- Get the first database name for the instance.
			set @tmp = ''
			select @dbname = dbname, @state_desc = state_desc 
			from #instance_dbs rd
			where dbname = (select min(dbname) dbname from #instance_dbs)

			-- As long as we've got a valid database name check the guest connection permissions.
			while @dbname <> @tmp begin
				if upper(@state_desc) = 'ONLINE' begin
					set @class = null

					set @sql = N'
						select @out_val = class from [' + @dbname + '].sys.database_permissions where grantee_principal_id = user_id(''guest'') and state = ''G'' and type = ''CO'''
					exec sp_executesql @sql, N'@out_val tinyint out', @out_val = @class out

					if @class is null
						set @guest_connection = 0
					else
						set @guest_connection = 1

					-- Save the guest connection status for this database.
					update #instance_dbs set connection = @guest_connection where dbname = @dbname
					end
				else
					-- Set the connection status to null to signal the database was unavailable.
					update #instance_dbs set connection = null where dbname = @dbname

				-- Get the next database name for the instance.
				set @tmp = @dbname
				select @dbname = case when dbname = @dbname then null else dbname end, @state_desc = state_desc 
				from #instance_dbs rd
				where dbname = (select min(dbname) dbname from #instance_dbs where dbname > @dbname)
				end		-- @dbname is not null

			-- Add the guest permissions to the sec_hardening_results database
			insert into #inserts (batch_no, instance_id, db_list_id, sec_hardening_tests_id, results) (
				select
					@batch_no,	 -- batch_no - bigint
					rd.instance_id,	 -- instance_id - bigint
					dl.db_list_id,
					@sec_hardening_tests_id,	 -- sec_hardening_tests_id - bigint
					rd.connection
				from
					#instance_dbs rd
					left outer join #db_list dl on dl.dbname = rd.dbname
				)

			if object_id('tempdb..#instance_dbs') is not null
				drop table #instance_dbs
			end

		else if @sec_hardening_tests_id = 14 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Audit Level -- Should be "All".  (Possible Audit Level values: None = 0; Success = 1; Failure = 2; All = 3.)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			set @sql =	N'
				declare @ValueOut int;
				exec master..xp_instance_regread
					@rootkey = ''HKEY_LOCAL_MACHINE'',
					@key = ''Software\Microsoft\MSSQLServer\MSSQLServer'',
					@value_name = ''AuditLevel'',
					@value = @ValueOut output;
				insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
					(select ' + convert(varchar(30), @batch_no) + ', ' + convert(varchar(30), @instance_id) + ', ' + convert(varchar(30), @sec_hardening_tests_id) + ', @ValueOut)'
			exec(@sql)
			end


		else if @sec_hardening_tests_id = 15 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Hidden Instance -- SQL Server instances should be hidden.  (1 = Hidden; 0 = Not Hidden)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			set @sql =	N'
				declare @ValueOut int;
				exec master..xp_instance_regread
					@rootkey = ''HKEY_LOCAL_MACHINE'',
					@key = ''SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib'',
					@value_name = ''HideInstance'',
					@value = @ValueOut output;
				insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
					(select ' + convert(varchar(30), @batch_no) + ', ' + convert(varchar(30), @instance_id) + ', ' + convert(varchar(30), @sec_hardening_tests_id) + ', @ValueOut)'
			exec(@sql)
			end


		else if @sec_hardening_tests_id = 18 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Trustworthy -- Trustworthy should be off.  (1 = On; 0 = Off)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			select top 1 @trustworthy_name = name from master.sys.databases where is_trustworthy_on = 1 and name <> 'msdb'

			if @trustworthy_name is null
				set @trustworthy_status = 0
			else
				set @trustworthy_status = 1

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @trustworthy_status)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @trustworthy_status as sa_exists
			end


		else if @sec_hardening_tests_id = 19 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Auto_close -- Auto Close should be off.  (1 = On; 0 = Off)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			-- The following is only valid for versions 2012 and higher
			-- select @version = dbo.uf_version_major(ih.version)
			-- from instances i inner join dbo.instance_history ih on ih.instance_id = i.instance_id
			-- where ih.is_current = 1 and i.instance_id = @instance_id

			set @version = 0--!InstanceVersion!>

			if @version >= 11 begin
				-- This is executed as dynamic SQL to avoid parsing errors in servers with versions less than 11.
				set @sql = N'select @auto_close_o = cast(is_auto_close_on as smallint) from master.sys.databases where containment <> 0'
				exec sp_executesql @sql, N'@auto_close_o smallint out', @auto_close_o = @auto_close_status out
				end
			else
				set @auto_close_status = null

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @auto_close_status)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @auto_close_status as sa_exists
			end

		else if @sec_hardening_tests_id = 20 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- PUBLIC Role Permissions -- PUBLIC role is allowed only default permissions. These are: View Any Database; Connect (to endpoints).  All others are not default permissions.  (0 = Correct; 1 = Incorrect)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			select top 1 @public_permissions_txt = state_desc
			from master.sys.server_permissions 
			where 
				(grantee_principal_id = suser_sid(N'public') and state_desc like 'grant%') 
				and not (state_desc = 'GRANT' and [permission_name] = 'VIEW ANY DATABASE' and class_desc = 'SERVER') 
				and not (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 2) 
				and not (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 3) 
				and not (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 4) 
				and not (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and class_desc = 'ENDPOINT' and major_id = 5)

			if @public_permissions_txt is null
				set @public_permissions = 0
			else
				set @public_permissions = 1

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @public_permissions)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @public_permissions as sa_exists
			end


		else if @sec_hardening_tests_id = 21 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Built-in Groups Are Logins -- Built-in Groups should not be SQL logins.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			--select @builtin_groups_txt = class_desc 
			--from sys.server_principals pr inner join sys.server_permissions pe on pr.principal_id = pe.grantee_principal_id 
			--where pr.name like 'builtin%'

			-- Replaces the above code to include 
			select @builtin_groups_txt = class_desc
			from sys.server_principals pr inner join sys.server_permissions pe on pr.principal_id = pe.grantee_principal_id
			where
				(lower(pr.name) like 'builtin%' or lower(pr.name) like 'built-in%')
				and pe.type = 'COSQ'	-- CONNECT SQL
				and pe.state <> 'D'		-- DENY permission

			if @builtin_groups_txt is null
				set @builtin_groups = 0
			else
				set @builtin_groups = 1

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @builtin_groups)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @builtin_groups as sa_exists
			end


		else if @sec_hardening_tests_id = 22 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- Windows Local Groups Are Logins -- Windows local groups should not be SQL logins.  (1 = Enabled; 0 = Disabled)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			select top 1 @win_local_groups_txt = class_desc
			from 
				master.sys.server_principals pr 
				inner join master.sys.server_permissions pe ON pr.[principal_id] = pe.[grantee_principal_id]
			where 
				pr.[type_desc] = 'WINDOWS_GROUP'
				and pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%'

			if @win_local_groups_txt is null
				set @win_local_groups = 0
			else
				set @win_local_groups = 1

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @win_local_groups)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @win_local_groups as sa_exists
			end


		else if @sec_hardening_tests_id = 23 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- PUBLIC Has Access to SQL Agent Proxies -- The PUBLIC role should not be granted access to sql agent proxies  (1 = Granted; 0 = Not Granted)
			--------------------------------------------------------------------------------------------------------------------------------------------------

			select top 1 @public_role_txt = type_desc
			from 
				msdb.dbo.sysproxylogin spl 
				inner join msdb.sys.database_principals dp on dp.sid = spl.sid 
				inner join msdb.dbo.sysproxies sp on sp.proxy_id = spl.proxy_id 
			where 
				principal_id = user_id('public')

			if @public_role_txt is null
				set @public_role = 0
			else
				set @public_role = 1

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @public_role)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @public_role as sa_exists
			end


		else if @sec_hardening_tests_id = 24 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- SQL Maintenance Log Count --  The number of SQL Server maintenance logs should be 12.
			--------------------------------------------------------------------------------------------------------------------------------------------------

			set @sql =	N'
				declare @ValueOut int;
				exec master..xp_instance_regread
					@rootkey = ''HKEY_LOCAL_MACHINE'',
					@key = ''Software\Microsoft\MSSQLServer\MSSQLServer'',
					@value_name = ''NumErrorLogs'',
					@value = @ValueOut output;
				insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
					(select ' + convert(varchar(30), @batch_no) + ', ' + convert(varchar(30), @instance_id) + ', ' + convert(varchar(30), @sec_hardening_tests_id) + ', @ValueOut)'
			exec(@sql)
			end


		else if @sec_hardening_tests_id = 25 begin
			--------------------------------------------------------------------------------------------------------------------------------------------------
			-- CLR Assembly Permissions
			--------------------------------------------------------------------------------------------------------------------------------------------------

			select @clr_permissions_txt = name from sys.assemblies where is_user_defined = 1

			if @clr_permissions_txt is null
				set @clr_permissions = 0
			else
				set @clr_permissions = 1

			insert into #inserts (batch_no, instance_id, sec_hardening_tests_id, results)
			values (@batch_no, @instance_id, @sec_hardening_tests_id, @clr_permissions)
			-- select @batch_no as batch_no, @instance_id as instance_id, 0 as db_list_id, @sec_hardening_tests_id as sec_hardening_tests_id, @clr_permissions as sa_exists
			end

		end try

	begin catch
		set @err_num = Error_number()
		set @msg = Error_message()

		select @msg as message
		end catch

	-- Get the next test id
	select
		@sec_hardening_tests_id = min(sht.sec_hardening_tests_id)
	from #sec_hardening_tests sht
	where
		sht.sec_hardening_tests_id > @sec_hardening_tests_id
	end		-- while @sec_hardening_tests_id is not null


----------------------------------------------------------------------------------------------------------
-- Construct the INSERT INTO statements
----------------------------------------------------------------------------------------------------------

set @insert_str = ''
set @dt = getdate()

declare ins_cur cursor fast_forward for
	select 		
		batch_no,
		instance_id,
		db_list_id,
		sec_hardening_tests_id,
		results
	from #inserts

open ins_cur

fetch next from ins_cur into @ins_batch_no, @ins_instance_id, @ins_db_list_id, @ins_sec_hardening_tests_id, @ins_results
set @fetch_stat = @@FETCH_STATUS
while @fetch_stat = 0 begin
	select 'insert into sec_hardening_results (batch_no, instance_id, db_list_id, sec_hardening_tests_id, results, create_dt) values (' + 
		-- convert(varchar(20), @ins_batch_no) + ', ' + convert(varchar(20), @ins_instance_id)  + ', ' + isnull(convert(varchar(20), @ins_db_list_id), 'null')  + ', ' + isnull(convert(varchar(20), @ins_sec_hardening_tests_id), 'null')  + ', ''' + isnull(@ins_results, 'null')  + ''', ''' + convert(varchar(30), @dt, 121) + ''')' as insert_string
		convert(varchar(20), @ins_batch_no) + ', ' + convert(varchar(20), @ins_instance_id)  + ', ' + isnull(convert(varchar(20), @ins_db_list_id), -1)  + ', ' + isnull(convert(varchar(20), @ins_sec_hardening_tests_id), -1)  + ', ''' + isnull(@ins_results, 'null')  + ''', ''' + convert(varchar(30), @dt, 121) + ''')' as insert_string

	fetch next from ins_cur into @ins_batch_no, @ins_instance_id, @ins_db_list_id, @ins_sec_hardening_tests_id, @ins_results
	set @fetch_stat = @@FETCH_STATUS
	end

-- Close and dispose of the cursor
close ins_cur
deallocate ins_cur


----------------------------------------------------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------------------------------------------------

-- Remove the temporary tables.
if object_id('tempdb..#inserts') is not null
	drop table #inserts

if object_id('tempdb..#sec_hardening_tests') is not null
	drop table #sec_hardening_tests

if object_id('tempdb..#db_list') is not null
	drop table #db_list

set nocount off
