# SQL Server Jobs & AlwaysOn Availability Groups Interoperability

This folder contains the script [AlwaysOn - Master Control Job and Alert.sql](AlwaysOn%20-%20Master%20Control%20Job%20and%20Alert.sql) to properly control **scheduled jobs on SQL Servers** with **Availability Groups**.

## Parameters

`@MasterControlJobName = N'AlwaysOn: Master Control Job'`

Set the name to be used for the master control job.

`@AlertName = N'AlwaysOn: Role Changes'`

Set the name to be used for the alert triggered by role change events.

`@SpecialConfigurations`

This is an XML parameter that can contain special configurations that specify when certain jobs should be enabled or disabled, based on a database role.

This XML parameter can contain a **list of job names**, **job step names** or a **list of job category names**, for which **special use cases** need to be applied. 
Specifically, where the jobs should run:

- `both` - On **both Primary and Secondary**
- `secondary` - On **Secondary only**
- `primary` - On **Primary only** (this is also the **default**)
- `never` - **Never** (if you want certain jobs to always remain disabled)

[More info TBA](https://eitanblumin.com/?p=938)

## Permissions

TBA

## Examples

TBA

## Remarks

TBA

## See Also

- TBA