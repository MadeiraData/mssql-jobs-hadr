
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
, ag.ag_name
, ag_current_role	 = ag.role_desc
, ag.secondary_role_allow_connections
FROM msdb..sysjobs AS j
INNER JOIN msdb..syscategories AS jc ON j.category_id=jc.category_id
INNER JOIN msdb..sysjobsteps AS js ON j.job_id=js.job_id
LEFT JOIN (
select  databaselist.[name] as databasename, ag.name AS ag_name, ar.replica_server_name, secondary_role_allow_connections, ars.role_desc
from    sys.databases databaselist
inner join sys.availability_replicas ar ON databaselist.replica_id = ar.replica_id
inner join sys.dm_hadr_availability_replica_states ars ON ars.group_id = ar.group_id and ars.is_local = 1
inner join sys.availability_groups ag ON ar.group_id = ag.group_id
) AS ag
ON (js.database_name = ag.databasename)
ORDER BY job_name, js.step_id