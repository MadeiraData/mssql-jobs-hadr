# SQL Server Jobs & Database Mirroring Interoperability

{% include applies-to-md.md %}

This folder contains a script which can be used to automatically **enable or disable SQL Server jobs** based on the **Database Mirroring role** of their respective database(s).

The script will create one **scheduled job**, and one **alert**.

In this page:

- [Download](#download)
- [Prerequisites](#prerequisites)
- [Arguments](#arguments)
- [Permissions](#permissions)
- [Remarks](#remarks)
- [Examples](#examples)
- [See Also](#see-also)

## Download

- [DB Mirroring - Master Control Job and Alert.sql](DB%20Mirroring%20-%20Master%20Control%20Job%20and%20Alert.sql)

## Prerequisites

The script only supports **SQL Server versions 2008 and later**, that have **SQL Server Agent** available (**Express** editions and **SQL Azure DB** are _not_ supported).

To install the script, simply run it on your servers involved in an HA/DR architecture.

You may change the values of the variables at the top of the script, if you want to customize the solution.

See the "Arguments" section below for more info.

## Arguments

`SET @MasterControlJobName = N'DB Mirroring: Master Control Job'` sets the name to be used for the master control job.

`SET @AlertName = N'DB Mirroring: State Changes'` sets the name to be used for the alert triggered by state change events.

{% include include-xml-argument-md.md %}

## Permissions

Only members of the `sysadmin` fixed server role can run this script.

## Remarks

- Your **T-SQL** job steps should be set to **run on their destined databases**. Don't use any "USE" commands or 3-part-names while setting the database context to "master" or something like that. **What you specify as the "target" database in the job step - that's what the script will be using for its logic**.

- If you're using special configurations at the step level, keep in mind that **it's enough for just one step to be enabled, in order for the script to enable the whole job**. If you have more steps in such jobs, consider the possibility that they might be executed not when you necessarily intend them to. You can use something like the `sys.database_mirroring` system table to check for a database's role.

- The scripts will **automatically** detect whether a T-SQL step's context database is accessible or not. For example, if the database is a MIRROR. *If a database is found to be non-accessible, that would override any special configurations you may have had for that step*. However, if another step within the same job should be enabled, then that would **override** the override (as mentioned above, it's enough for one step to be enabled in order to enable the whole job). If you have such use cases, you should properly configure your job step outcomes to take this into consideration (for example, set the **"on failure action"** to go to another step instead of failing the job).

- Generally, it would be best to **avoid** creating jobs that have one step run on a database in Mirroring Session A, and another step run on a database in Mirroring Session B. Otherwise, you'll risk a scenario where session A might be PRINCIPLE on the server, while group B is MIRROR, and your job could potentially fail! (unless you have appropriate mirroring role checks in place, and/or you have appropriate settings for the job step failure outcome).

## Examples

TBA

## See Also

- [More Info](https://eitanblumin.com/?p=938)
