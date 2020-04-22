# SQL Server Jobs & Database Mirroring Interoperability

This folder contains the script [DB Mirroring - Master Control Job and Alert.sql](DB%20Mirroring%20-%20Master%20Control%20Job%20and%20Alert.sql) to properly control **scheduled jobs on SQL Servers** with **Database Mirroring**.

## Parameters

`@MasterControlJobName = N'DB Mirroring: Master Control Job'`

Set the name to be used for the master control job.

`@AlertName = N'DB Mirroring: State Changes'`

Set the name to be used for the alert triggered by state change events.

`@SpecialConfigurations`

This is an XML parameter that can contain special configurations that specify when certain jobs should be enabled or disabled, based on a database role.

More info TBA

## Permissions

TBA

## Examples

TBA

## Remarks

TBA

## See Also

- TBA
