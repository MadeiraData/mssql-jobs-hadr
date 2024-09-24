USE [msdb];

DECLARE 
    @MasterControlJobName SYSNAME = N'AlwaysOn: Master Control Job',
    @AlertName SYSNAME = N'AlwaysOn: Role Changes',
    @SpecialConfigurations XML = N'
        <config>
            <item type="category" enablewhen="never">JobsToDisable</item>
            <item type="category" enablewhen="ignore">SQL Sentry Jobs</item>
            <item type="category" enablewhen="both">Database Maintenance</item>
            <item type="category" enablewhen="both">AlwaysOn</item>
            <item type="category" enablewhen="both">Mirroring</item>
            <item type="category" enablewhen="primary" dbname="ReportServer">Report Server</item>
        </config>';

DECLARE 
    @ReturnCode INT,
    @CMD NVARCHAR(MAX),
    @saName SYSNAME;

-- Fetch the SQL Server Agent account
SELECT @saName = [name] 
FROM sys.server_principals 
WHERE sid = 0x01;

BEGIN TRANSACTION;

-- Add job category if it doesn't exist
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = N'AlwaysOn' AND category_class = 1)
BEGIN
    PRINT N'Adding job category...';
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class = N'JOB', @type = N'LOCAL', @name = N'AlwaysOn';
    IF (@ReturnCode <> 0) GOTO QuitWithRollback;
END;

-- Delete the existing job if it exists
IF EXISTS (SELECT 1 FROM msdb..sysjobs WHERE name = @MasterControlJobName)
BEGIN
    PRINT N'Deleting existing job...';
    EXEC @ReturnCode = msdb.dbo.sp_delete_job @job_name = @MasterControlJobName, @delete_unused_schedule = 1;
    IF (@ReturnCode <> 0) GOTO QuitWithRollback;
END;

-- Define the T-SQL command for job execution
SET @CMD = N'SET NOCOUNT, ARITHABORT, XACT_ABORT, QUOTED_IDENTIFIER ON;
    DECLARE @WhatIf BIT = 0, @JobDesiredState INT, @CurrentRole VARCHAR(10), @CurrJob NVARCHAR(500);

    DECLARE JobsToUpdate CURSOR FORWARD_ONLY READ_ONLY FOR
    SELECT job_name, role_desc, desired_state
    FROM (
        -- Main query to determine the state of jobs
        SELECT j.name AS job_name, MIN(ag.role_desc) AS role_desc, 
               MAX(CASE 
                   WHEN Config.EnableWhen = ''never'' THEN 0
                   WHEN Config.EnableWhen = ''both'' THEN 1
                   WHEN DATABASEPROPERTYEX(db.dbname, ''Status'') = ''ONLINE'' 
                        AND Config.EnableWhen = ''secondary'' 
                        AND ag.role_desc = ''SECONDARY'' 
                        AND ag.secondary_role_allow_connections > 0 THEN 1
                   WHEN DATABASEPROPERTYEX(db.dbname, ''Status'') = ''ONLINE'' 
                        AND ISNULL(Config.EnableWhen, ''primary'') <> ''secondary'' 
                        AND ag.role_desc = ''PRIMARY'' THEN 1
                   ELSE 0
               END) AS desired_state
        FROM msdb..sysjobs AS j
        INNER JOIN msdb..syscategories AS jc ON j.category_id = jc.category_id
        LEFT JOIN msdb..sysjobsteps AS js ON j.job_id = js.job_id
        LEFT JOIN (
            SELECT x.value(''(@type)[1]'',''varchar(10)'') AS ConfigType,
                   x.value(''(@enablewhen)[1]'',''varchar(10)'') AS EnableWhen,
                   x.value(''(@dbname)[1]'',''sysname'') AS DBName,
                   x.value(''(text())[1]'',''nvarchar(4000)'') AS ItemName
            FROM @SpecialConfigurations.nodes(''config/item'') AS T(x)
        ) AS Config ON (Config.ConfigType = ''job'' AND j.name LIKE Config.ItemName)
                  OR (Config.ConfigType = ''category'' AND jc.name LIKE Config.ItemName)
                  OR (Config.ConfigType = ''step'' AND js.step_name LIKE Config.ItemName)
        LEFT JOIN (
            SELECT db.name AS databasename, ag.secondary_role_allow_connections, ars.role_desc
            FROM sys.databases db
            INNER JOIN sys.availability_replicas ar ON db.replica_id = ar.replica_id
            INNER JOIN sys.dm_hadr_availability_replica_states ars 
                ON ars.group_id = ar.group_id AND ars.is_local = 1
        ) AS ag ON (Config.DBName IS NULL AND js.database_name = ag.databasename)
                  OR (Config.DBName = ag.databasename)
        CROSS APPLY (VALUES(COALESCE(Config.DBName, ag.databasename, js.database_name))) AS db(dbname)
        WHERE (Config.DBName IS NOT NULL OR ag.databasename IS NOT NULL)
          AND (Config.EnableWhen IS NULL OR Config.EnableWhen <> ''ignore'')
        GROUP BY j.name
    ) AS q
    WHERE enabled <> desired_state
    ORDER BY job_name;

    -- Process the cursor for job updates
    OPEN JobsToUpdate;
    FETCH NEXT FROM JobsToUpdate INTO @CurrJob, @CurrentRole, @JobDesiredState;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        RAISERROR(N''Job: "%s", New Status: "%d" (role: "%s")'', 0, 1, @CurrJob, @JobDesiredState, @CurrentRole) WITH LOG;
        IF @WhatIf = 0 EXEC msdb.dbo.sp_update_job @job_name = @CurrJob, @enabled = @JobDesiredState;
        FETCH NEXT FROM JobsToUpdate INTO @CurrJob, @CurrentRole, @JobDesiredState;
    END;

    CLOSE JobsToUpdate;
    DEALLOCATE JobsToUpdate;';

-- Validate command before adding the job
IF @CMD IS NULL OR @CMD = N''
BEGIN
    RAISERROR(N'@CMD is empty!', 16, 1);
    GOTO QuitWithRollback;
END;

-- Create and configure the Master Control Job
PRINT N'Creating job...';
DECLARE @jobId UNIQUEIDENTIFIER;
EXEC @ReturnCode = msdb.dbo.sp_add_job 
    @job_name = @MasterControlJobName, 
    @enabled = 1, 
    @description = N'Source: https://madeiradata.github.io/mssql-jobs-hadr', 
    @category_name = N'AlwaysOn', 
    @owner_login_name = @saName, 
    @job_id = @jobId OUTPUT;
IF (@ReturnCode <> 0) GOTO QuitWithRollback;

-- Add the job step
PRINT N'Adding job step...';
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep 
    @job_id = @jobId, 
    @step_name = N'enable or disable jobs', 
    @subsystem = N'TSQL', 
    @command = @CMD, 
    @database_name = N'master';
IF (@ReturnCode <> 0) GOTO QuitWithRollback;

-- Set job schedule
PRINT N'Setting job schedules...';
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule 
    @job_id = @jobId, 
    @name = N'Every_60min', 
    @freq_type = 4, 
    @freq_subday_type = 4, 
    @freq_subday_interval = 60;
IF (@ReturnCode <> 0) GOTO QuitWithRollback;

-- Add alert category and alert
PRINT N'Adding alert...';
EXEC @ReturnCode = msdb.dbo.sp_add_alert 
    @name = @AlertName, 
    @message_id = 1480, 
    @severity = 0, 
    @job_id = @jobId;
IF (@ReturnCode <> 0) GOTO QuitWithRollback;

COMMIT TRANSACTION;
PRINT N'Job created and configured successfully.';
GOTO EndSave;

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;
    PRINT N'Job creation failed. Transaction rolled back.';

EndSave:
