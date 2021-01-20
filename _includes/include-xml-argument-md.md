`[ SET @SpecialConfigurations = N'xml_value' ]` is an **optional** XML parameter that can contain special configurations that specify when certain jobs should be enabled or disabled, based on a database role.

`xml_value` must be a valid XML expression. This XML parameter can contain a **list of job names**, **job step names** or a **list of job category names**, for which **special use cases** need to be applied. 
Specifically, where the jobs should run.

The XML should have the following structure:

```
<config>
<item type="job | step | category" enablewhen="primary | secondary | both | never | ignore" [ dbname="database_name" ] >item name qualifier</item>
[ ... ]
</config>
```

`type` is an attribute determining the configuration item type. Possible values:

|Value|Description|  
|-----------|-----------------|  
|job|Item represents a job name.|  
|step|Item represents a job step name.|  
|category|Item represents a job category name.|

`enablewhen` is an attribute determining when the relevant job(s) should be enabled.

|Value|Description|  
|-----------|-----------------|  
|primary|Enable when on **Primary only** (this is also the **default**).|  
|secondary|Enable when on **Secondary only**.|  
|both|Enable when on **both Primary and Secondary**.|
|never|**Never** enable (if you want certain jobs to always remain disabled).|
|ignore|**Ignore** the jobs entirely (don't disable or enable automatically).|

`dbname` is an optional attribute used for explicitely setting which database should be checked.

This attribute can be useful for several possible scenarios:

- For job steps that do not have a database context, such as SSIS, Powershell, or CmdExec steps.
- For job steps configured with a database context other than the one actually relevant for the HADR check. For example, Report Server subscription jobs are automatically configured with the `master` database context, even though they're actually dependent on the `ReportServer` database. If you include this `ReportServer` database in an HADR solution, you're gonna have a problem. But if you add an item with `dbname="ReportServer"` for all jobs in the `Report Server` category, you'll be just fine, as they'd be automatically enabled/disabled as needed.

`item name qualifier` is the name of the relevant item (job/step/category). This value is used in a **LIKE** operator, and therefore supports **LIKE** pattern wildcards such as `%`, `_`, etc. Please see the [**LIKE** operator documentation](https://docs.microsoft.com/en-us/sql/t-sql/language-elements/like-transact-sql#arguments) for more info on **LIKE** expression patterns.

See the [Examples](#examples) section below for example values for this argument.
