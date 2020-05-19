USE [msdb];

DECLARE @MasterControlJobName SYSNAME, @AlertName SYSNAME, @SpecialConfigurations XML;

SET @MasterControlJobName = N'AlwaysOn: Master Control Job'
SET @AlertName = N'AlwaysOn: Role Changes'

SET @SpecialConfigurations = N'<config>
<item type="job" enablewhen="secondary">Contoso %</item>
<item type="job" enablewhen="both">AdventureWorks Validation Checks</item>
<item type="step" enablewhen="secondary">Generate BI Report</item>
<item type="category" enablewhen="both">SQL Sentry Jobs</item>
<item type="category" enablewhen="both">Database Maintenance</item>
<item type="job" enablewhen="secondary" dbname="AdventureWorksDWH">SSIS AdventureWorksDWH Send Reports</item>
<item type="job" enablewhen="primary" dbname="WideWorldImportersLT">WideWorldImporters Delete Old Data</item>
<item type="job" enablewhen="never" dbname="audit">Do not run - %</item>
</config>'

DECLARE @ReturnCode INT, @CMD NVARCHAR(MAX), @saName SYSNAME

SELECT @saName = [name] FROM sys.server_principals WHERE sid = 0x01;

BEGIN TRANSACTION

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'AlwaysOn' AND category_class=1)
BEGIN
	PRINT N'Adding job category...'
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'AlwaysOn';
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
END;

IF EXISTS (SELECT * FROM msdb..sysjobs WHERE name = @MasterControlJobName)
BEGIN
	PRINT N'Deleting existing job...'
	EXEC msdb.dbo.sp_delete_job @job_name=@MasterControlJobName, @delete_unused_schedule=1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
END

SET @CMD = N'DECLARE @SpecialConfigurations XML;

SET @SpecialConfigurations = N''' + REPLACE(CONVERT(nvarchar(max), @SpecialConfigurations), '''', '''''')  + N'''

SET NOCOUNT ON;
DECLARE @JobDesiredState INT, @CurrentRole VARCHAR(10), @CurrJob NVARCHAR(500);

DECLARE JobsToUpdate CURSOR
READ_ONLY FORWARD_ONLY
FOR
SELECT job_name, role_desc, desired_state
FROM
(
SELECT j.job_id, j.name AS job_name, jc.name AS category_name, j.enabled
, MIN(ag.role_desc) AS role_desc
--, db.dbname AS database_name, ag.secondary_role_allow_connections
, desired_state =
 MAX(CASE WHEN Config.EnableWhen = ''never'' THEN 0
	WHEN DATABASEPROPERTYEX(db.dbname, ''Status'') = ''ONLINE'' AND Config.EnableWhen IN (''secondary'', ''both'') AND ag.role_desc = ''SECONDARY'' AND ag.secondary_role_allow_connections > 0 THEN 1
	WHEN DATABASEPROPERTYEX(db.dbname, ''Status'') = ''ONLINE'' AND ISNULL(Config.EnableWhen, ''primary'') <> ''secondary'' AND ag.role_desc = ''PRIMARY'' THEN 1
	ELSE 0
  END)
FROM msdb..sysjobs AS j
INNER JOIN msdb..syscategories AS jc ON j.category_id=jc.category_id
INNER JOIN msdb..sysjobsteps AS js ON j.job_id=js.job_id
LEFT JOIN
(
SELECT  
  ConfigType = x.value(''(@type)[1]'',''varchar(10)'')
, EnableWhen = x.value(''(@enablewhen)[1]'',''varchar(10)'')
, DBName = x.value(''(@dbname)[1]'',''sysname'')
, ItemName = x.value(''(text())[1]'',''nvarchar(4000)'')
FROM @SpecialConfigurations.nodes(''config/item'') AS T(x)
) AS Config
ON
   (Config.ConfigType = ''job'' AND j.name LIKE Config.ItemName)
OR (Config.ConfigType = ''category'' AND jc.name LIKE Config.ItemName)
OR (Config.ConfigType = ''step'' AND js.step_name LIKE Config.ItemName)
LEFT JOIN (
select  databaselist.[name] as databasename, secondary_role_allow_connections, ars.role_desc
from    sys.databases databaselist
inner join sys.availability_replicas ar ON databaselist.replica_id = ar.replica_id
inner join sys.dm_hadr_availability_replica_states ars ON ars.group_id = ar.group_id and ars.is_local = 1
) AS ag
ON (Config.DBName IS NULL AND js.database_name = ag.databasename) -- or command like ''%''+ag.databasename+''%''
OR (Config.DBName = ag.databasename)
CROSS APPLY
(VALUES(COALESCE(Config.DBName, ag.databasename, js.database_name))) AS db(dbname)
WHERE (Config.DBName IS NOT NULL OR ag.databasename IS NOT NULL) -- at least one combination found
group by j.job_id, j.name, jc.name, j.enabled
--, db.dbname, ag.secondary_role_allow_connections, ag.role_desc
) AS q
WHERE enabled <> desired_state
ORDER BY job_name

OPEN JobsToUpdate
FETCH NEXT FROM JobsToUpdate INTO @CurrJob, @CurrentRole, @JobDesiredState

WHILE @@FETCH_STATUS = 0
BEGIN
	RAISERROR(N''Job: "%s", New Status: "%d" (role: "%s")'', 0, 1, @CurrJob, @JobDesiredState, @CurrentRole) WITH LOG;

	--EXEC msdb.dbo.sp_update_job @job_name=@CurrJob, @enabled=@JobDesiredState

	FETCH NEXT FROM JobsToUpdate INTO @CurrJob, @CurrentRole, @JobDesiredState
END

CLOSE JobsToUpdate
DEALLOCATE JobsToUpdate'

IF @CMD IS NULL OR @CMD = N''
BEGIN
	RAISERROR(N'@CMD is empty!',16,1);
	GOTO QuitWithRollback;
END

PRINT N'Creating job...'
DECLARE @jobId UNIQUEIDENTIFIER
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=@MasterControlJobName, 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Author: Eitan Blumin | https://eitanblumin.com', 
		@category_name=N'AlwaysOn', 
		@owner_login_name=@saName, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

PRINT N'Adding job step...'
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'enable or disable jobs', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=@CMD, 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

PRINT N'Setting job schedules...'
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every_60min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=60, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20100101, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RunAsSQLAgentServiceStartSchedule', 
		@enabled=1, 
		@freq_type=64, 
		@freq_interval=0, 
		@freq_subday_type=0, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20100101, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION

BEGIN TRANSACTION

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'AlwaysOn' AND category_class=2)
BEGIN
	PRINT N'Adding alert category...'
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'ALERT', @type=N'NONE', @name=N'AlwaysOn';
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
END

IF EXISTS (SELECT * FROM msdb..sysalerts WHERE name = @AlertName)
BEGIN
	PRINT N'Deleting existing alert...'
	EXEC msdb.dbo.sp_delete_alert @name=@AlertName
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
END

PRINT CONCAT(N'Job Id: ', @jobId)
RAISERROR(N'Adding alert...',0,1) WITH NOWAIT;
EXEC msdb.dbo.sp_add_alert @name=@AlertName, 
   @enabled=1, 
   @message_id=1480,
   @severity=0,
   @delay_between_responses=0,
   @include_event_description_in=0,
   @job_id=@jobId;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave: