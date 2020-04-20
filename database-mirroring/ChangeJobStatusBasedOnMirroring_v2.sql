DECLARE @SpecialConfigurations XML;

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

SET NOCOUNT ON;
DECLARE @JobDesiredState INT, @CurrentRole VARCHAR(10), @CurrJob NVARCHAR(500);

DECLARE JobsToUpdate CURSOR
READ_ONLY FORWARD_ONLY
FOR
SELECT job_name, role_desc, desired_state
FROM
(
SELECT j.job_id, j.name AS job_name, jc.name AS category_name, j.enabled
, MAX(ag.role_desc) AS role_desc
, desired_state =
 MAX(CASE WHEN Config.EnableWhen = 'never' THEN 0
	WHEN DATABASEPROPERTYEX(db.dbname, 'Status') = 'ONLINE' AND Config.EnableWhen IN ('secondary', 'both') AND ag.role_desc <> 'PRINCIPLE' THEN 1
	WHEN DATABASEPROPERTYEX(db.dbname, 'Status') = 'ONLINE' AND ISNULL(Config.EnableWhen, 'primary') <> 'secondary' AND ag.role_desc = 'PRINCIPLE' THEN 1
	ELSE 0
  END)
FROM msdb..sysjobs AS j
INNER JOIN msdb..syscategories AS jc ON j.category_id=jc.category_id
INNER JOIN msdb..sysjobsteps AS js ON j.job_id=js.job_id
LEFT JOIN
(
SELECT  
  ConfigType = x.value('(@type)[1]','varchar(10)')
, EnableWhen = x.value('(@enablewhen)[1]','varchar(10)')
, DBName = x.value('(@dbname)[1]','sysname')
, ItemName = x.value('(text())[1]','nvarchar(4000)')
FROM @SpecialConfigurations.nodes('config/item') AS T(x)
) AS Config
ON
   (Config.ConfigType = 'job' AND j.name LIKE Config.ItemName)
OR (Config.ConfigType = 'category' AND jc.name LIKE Config.ItemName)
OR (Config.ConfigType = 'step' AND js.step_name LIKE Config.ItemName)
LEFT JOIN (
SELECT d.[name] AS databasename, dbm.mirroring_role_desc AS role_desc
FROM sys.databases d
INNER JOIN sys.database_mirroring dbm ON d.database_id = dbm.database_id
WHERE dbm.mirroring_role_desc IS NOT NULL
) AS ag
ON (Config.DBName IS NULL AND js.database_name = ag.databasename) -- or command like '%'+ag.databasename+'%'
OR (Config.DBName = ag.databasename)
CROSS APPLY
(VALUES(COALESCE(Config.DBName, ag.databasename, js.database_name))) AS db(dbname)
WHERE (Config.DBName IS NOT NULL OR ag.databasename IS NOT NULL) -- at least one combination found
group by j.job_id, j.name, jc.name, j.enabled
--, ag.role_desc
) AS q
WHERE enabled <> desired_state
ORDER BY job_name

OPEN JobsToUpdate
FETCH NEXT FROM JobsToUpdate INTO @CurrJob, @CurrentRole, @JobDesiredState

WHILE @@FETCH_STATUS = 0
BEGIN
	RAISERROR(N'Job: "%s", New Status: "%d" (role: "%s")', 0, 1, @CurrJob, @JobDesiredState, @CurrentRole) WITH LOG;

	--EXEC msdb.dbo.sp_update_job @job_name=@CurrJob, @enabled=@JobDesiredState

	FETCH NEXT FROM JobsToUpdate INTO @CurrJob, @CurrentRole, @JobDesiredState
END

CLOSE JobsToUpdate
DEALLOCATE JobsToUpdate