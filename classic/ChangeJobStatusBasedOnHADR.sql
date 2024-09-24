USE [SomeNonHadrDB]
GO

-- Drop the procedure if it already exists
IF OBJECT_ID('ChangeJobStatusBasedOnHADR', 'P') IS NOT NULL 
    DROP PROCEDURE ChangeJobStatusBasedOnHADR
GO

/*
Source: https://madeiradata.github.io/mssql-jobs-hadr
--Sample usage:
EXEC ChangeJobStatusBasedOnHADR @DBName = 'DB_to_use_as_primary_indicator'
*/

CREATE PROCEDURE ChangeJobStatusBasedOnHADR
    @DBName SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NeedToEnableJobs BIT;

    -- Validate the provided database name
    IF DB_ID(ISNULL(@DBName, DB_NAME())) IS NULL
    BEGIN
        THROW 50000, N'Provided @DBName is invalid or does not exist.', 1;
    END

    -- Check if the database is in the 'SECONDARY' role
    IF EXISTS ( 
        SELECT 1
        FROM sys.databases d
        INNER JOIN sys.dm_hadr_availability_replica_states hars
            ON d.replica_id = hars.replica_id
        WHERE d.database_id = DB_ID(ISNULL(@DBName, DB_NAME()))
        AND hars.role_desc = 'SECONDARY'
    )
    BEGIN
        -- The database is on the secondary server
        SET @NeedToEnableJobs = 0;
    END
    -- Check if the database is in the 'PRIMARY' role
    ELSE IF EXISTS ( 
        SELECT 1
        FROM sys.databases d
        INNER JOIN sys.dm_hadr_availability_replica_states hars
            ON d.replica_id = hars.replica_id
        WHERE d.database_id = DB_ID(ISNULL(@DBName, DB_NAME()))
        AND hars.role_desc <> 'SECONDARY'
    )
    BEGIN
        -- The database is on the primary server
        SET @NeedToEnableJobs = 1;
    END
    ELSE
    BEGIN
        -- The database is not in an HADR session
        THROW 50001, N'The provided @DBName is not part of an Availability Group.', 1;
    END

    -- Declare a cursor to iterate through the jobs that need updating
    DECLARE @CurrJob NVARCHAR(500);
    DECLARE JobsToUpdate CURSOR READ_ONLY FORWARD_ONLY FOR
    SELECT name
    FROM msdb..sysjobs
    WHERE name IN ('Job name 1', 'Job name 2', 'Job name 3', 'Job name 4', 'Job name 5')
    AND [enabled] <> @NeedToEnableJobs;

    -- Open the cursor and process each job
    OPEN JobsToUpdate;
    FETCH NEXT FROM JobsToUpdate INTO @CurrJob;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Log the status change
        PRINT N'Changing job status for "' + @CurrJob + '"';

        -- Update the job's status
        EXEC msdb.dbo.sp_update_job @job_name = @CurrJob, @enabled = @NeedToEnableJobs;

        -- Fetch the next job
        FETCH NEXT FROM JobsToUpdate INTO @CurrJob;
    END

    -- Close and deallocate the cursor
    CLOSE JobsToUpdate;
    DEALLOCATE JobsToUpdate;
END
GO
