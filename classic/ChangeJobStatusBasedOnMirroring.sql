USE [SomeNonMirroredDB]
GO
IF OBJECT_ID('ChangeJobStatusBasedOnMirroring', 'P') IS NOT NULL DROP PROCEDURE ChangeJobStatusBasedOnMirroring
GO
/*
--Sample usage:
EXEC ChangeJobStatusBasedOnMirroring @DBName = 'DB_to_use_as_primary_indicator'
*/
CREATE PROCEDURE ChangeJobStatusBasedOnMirroring
	@DBName SYSNAME = NULL
AS
SET NOCOUNT ON;
DECLARE @NeedToEnableJobs BIT;
IF DB_ID(ISNULL(@DBName, DB_NAME())) IS NULL
BEGIN
	RAISERROR(N'Provided @DBName is invalid: %s', 16,1,@DBName);
	RETURN;
END

IF EXISTS ( 
    SELECT
		d.name, dbm.*
    FROM 
		sys.databases d
	INNER JOIN
		sys.database_mirroring dbm
	ON
		d.database_id = dbm.database_id
    WHERE 
		dbm.mirroring_role_desc <> 'PRINCIPAL'
    AND dbm.database_id = DB_ID(ISNULL(@DBName, DB_NAME()))
)
	--Not Primary Server
	SET @NeedToEnableJobs = 0
ELSE IF EXISTS ( 
    SELECT
		d.name, dbm.*
    FROM 
		sys.databases d
	INNER JOIN
		sys.database_mirroring dbm
	ON
		d.database_id = dbm.database_id
    WHERE 
		dbm.mirroring_role_desc = 'PRINCIPAL'
    AND dbm.database_id = DB_ID(ISNULL(@DBName, DB_NAME()))
)
	--Yes Primary Server
	SET @NeedToEnableJobs = 1
ELSE
BEGIN
	--Not in a HADR session
	RAISERROR(N'Provided @DBName is not member in a Database Mirroring session: %s', 16,1,@DBName);
	RETURN;
END

DECLARE @CurrJob NVARCHAR(500)
DECLARE JobsToUpdate CURSOR
READ_ONLY FORWARD_ONLY
FOR
select name
from msdb..sysjobs
where name in
(
'Job name 1',
'Job name 2',
'Job name 3',
'Job name 4',
'Job name 5'
)
and [enabled] <> @NeedToEnableJobs

OPEN JobsToUpdate
FETCH NEXT FROM JobsToUpdate INTO @CurrJob

WHILE @@FETCH_STATUS = 0
BEGIN
	RAISERROR(N'Changing job status for %s', 0, 1, @CurrJob) WITH LOG;

	EXEC msdb.dbo.sp_update_job @job_name=@CurrJob, @enabled=@NeedToEnableJobs

	FETCH NEXT FROM JobsToUpdate INTO @CurrJob
END

CLOSE JobsToUpdate
DEALLOCATE JobsToUpdate
GO
