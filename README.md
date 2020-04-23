# SQL Server Jobs & HA/DR

This repository contains solutions to properly control and maintain **scheduled jobs on SQL Servers** with either **Availability Groups** or **Database Mirroring**.

![Cover Image](media/sql-jobs-hadr.png)

This solution is an improved version of the scripts provided at [Automatically Enable or Disable Jobs Based on HADR Role](https://eitanblumin.com/2018/11/06/automatically-enable-or-disable-jobs-based-on-hadr-role/).

## Permissions

Only members of the `sysadmin` fixed server role can run these scripts.

## Availability Groups

The relevant scripts for Availability Groups are provided in the [`availability-groups` folder](availability-groups/).

Script can be downloaded here: [`AlwaysOn - Master Control Job and Alert.sql`](availability-groups/AlwaysOn%20-%20Master%20Control%20Job%20and%20Alert.sql)

## Database Mirroring

The relevant scripts for Database Mirroring are provided in the [`database-mirroring` folder](database-mirroring/).

Script can be downloaded here: [`DB Mirroring - Master Control Job and Alert.sql`](database-mirroring/DB%20Mirroring%20-%20Master%20Control%20Job%20and%20Alert.sql)

## Classic Version

This repository also contains the "classic" versions of the scripts, provided in the [`classic` folder](classic/).

## License

This solution is released under the [MIT License](LICENSE), and is provided "as-is", as a free contribution to the professional SQL Server community.

## Contribution

This is an open-source solution. Please feel free to [create issues](issues) if you want to submit bug reports or feature requests.

You may also **fork** the solution to your account and submit pull requests if you want to contribute!
