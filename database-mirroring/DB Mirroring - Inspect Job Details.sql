
SELECT
  j.job_id
, job_name		 = j.name
, category_name		 = jc.name
, job_enabled		 = j.enabled
, active_schedules_count = (
		SELECT COUNT(*) 
		FROM msdb..sysjobschedules AS jsch 
		INNER JOIN msdb..sysschedules AS sch 
		ON jsch.schedule_id = sch.schedule_id 
		WHERE jsch.job_id = j.job_id 
		AND sch.enabled = 1)
, js.step_id
, js.step_name
, step_subsystem	 = js.subsystem
, js.database_name
, ag.mirroring_role_desc
, ag.mirroring_state_desc
, ag.mirroring_witness_state_desc
FROM msdb..sysjobs AS j
INNER JOIN msdb..syscategories AS jc ON j.category_id=jc.category_id
INNER JOIN msdb..sysjobsteps AS js ON j.job_id=js.job_id
LEFT JOIN (
select  databaselist.[name] as databasename, dbm.mirroring_role_desc, dbm.mirroring_state_desc, dbm.mirroring_witness_state_desc
from    sys.databases databaselist
INNER JOIN sys.database_mirroring dbm ON databaselist.database_id = dbm.database_id
WHERE dbm.mirroring_role_desc IS NOT NULL
) AS ag
ON (js.database_name = ag.databasename)
ORDER BY job_name, js.step_id