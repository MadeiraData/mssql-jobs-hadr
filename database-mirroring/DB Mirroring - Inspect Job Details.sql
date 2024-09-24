WITH ActiveSchedules AS (
    SELECT 
        jsch.job_id, 
        COUNT(*) AS active_schedules_count
    FROM msdb..sysjobschedules AS jsch
    INNER JOIN msdb..sysschedules AS sch 
        ON jsch.schedule_id = sch.schedule_id 
    WHERE sch.enabled = 1
    GROUP BY jsch.job_id
),
MirroringInfo AS (
    SELECT 
        databaselist.[name] AS databasename, 
        dbm.mirroring_role_desc, 
        dbm.mirroring_state_desc, 
        dbm.mirroring_witness_state_desc
    FROM sys.databases AS databaselist
    INNER JOIN sys.database_mirroring AS dbm 
        ON databaselist.database_id = dbm.database_id
    WHERE dbm.mirroring_role_desc IS NOT NULL
)
SELECT 
    j.job_id,
    j.name AS job_name,
    jc.name AS category_name,
    j.enabled AS job_enabled,
    ISNULL(a.active_schedules_count, 0) AS active_schedules_count,
    js.step_id,
    js.step_name,
    js.subsystem AS step_subsystem,
    js.database_name,
    ag.mirroring_role_desc,
    ag.mirroring_state_desc,
    ag.mirroring_witness_state_desc
FROM msdb..sysjobs AS j
INNER JOIN msdb..syscategories AS jc 
    ON j.category_id = jc.category_id
INNER JOIN msdb..sysjobsteps AS js 
    ON j.job_id = js.job_id
LEFT JOIN ActiveSchedules AS a 
    ON j.job_id = a.job_id
LEFT JOIN MirroringInfo AS ag 
    ON js.database_name = ag.databasename
ORDER BY job_name, js.step_id;
