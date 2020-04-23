# SQL Server Jobs & AlwaysOn Availability Groups Interoperability

{% include applies-to-md.md %}

This folder contains a script which can be used to automatically **enable or disable SQL Server jobs** based on the **Availability Groups role** of their respective database(s).

The script will create one **scheduled job**, and one **alert**.

In this page:

- [Download](#download)
- [Arguments](#arguments)
- [Prerequisites](#prerequisites)
- [Remarks](#remarks)
- [Permissions](#permissions)
- [Examples](#examples)
- [See Also](#see-also)

## Download

- [AlwaysOn - Master Control Job and Alert.sql](AlwaysOn%20-%20Master%20Control%20Job%20and%20Alert.sql)

## Arguments

`SET @MasterControlJobName = N'AlwaysOn: Master Control Job'` sets the name to be used for the master control job.

`SET @AlertName = N'AlwaysOn: Role Changes'` sets the name to be used for the alert triggered by role change events.

{% include include-xml-argument-md.md %}

## Prerequisites

The script only supports **SQL Server versions 2012 and later**, that have **SQL Server Agent** available (**Express** editions and **SQL Azure DB** are _not_ supported).

To install the script, simply run it on your servers involved in an HA/DR architecture.

You may change the values of the variables at the top of the script, if you want to customize the solution.

See the "Arguments" section below for more info.

## Remarks

[TBA](https://eitanblumin.com/?p=938)

## Permissions

Only members of the `sysadmin` fixed server role can run this script.

## Examples

TBA

## See Also

- [TBA](https://eitanblumin.com/?p=938)
