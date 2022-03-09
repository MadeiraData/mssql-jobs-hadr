# SQL Server Jobs & HA/DR

This repository contains solutions to properly control and maintain **scheduled jobs on SQL Servers** with either **Availability Groups** or **Database Mirroring**.

![Cover Image](media/sql-jobs-hadr.png)

Using this solution, you can automatically control which SQL Agent jobs would be executed on which replica, based on several possible criteria (PRIMARY / SECONDARY database role, job name, job category, etc.).

After implementing this solution:

- No longer will you be needing to manually implement an HA/DR role check in each new job or job step that you create.
- Jobs would no longer be executing without actually doing anything because a database's role wasn't the right one.
- No more jobs would fail because they were executed on a secondary/read-only/unreadable database.
- MSDB job history tables would not be needlessly bloated.

This solution is an improved version of the scripts provided at the blog post [Automatically Enable or Disable Jobs Based on HADR Role](https://eitanblumin.com/2018/11/06/automatically-enable-or-disable-jobs-based-on-hadr-role/).

## Availability Groups

This solution is available for AlwaysOn Availability Groups for SQL Server 2012 and later. [Click here for more details](availability-groups/), or download below:

- [🔽 AlwaysOn - Master Control Job and Alert.sql](availability-groups/AlwaysOn%20-%20Master%20Control%20Job%20and%20Alert.sql)

## Database Mirroring

This solution is available for Database Mirroring for SQL Server 2008 and later. [Click here for more details](database-mirroring/), or download below:

- [🔽 DB Mirroring - Master Control Job and Alert.sql](database-mirroring/DB%20Mirroring%20-%20Master%20Control%20Job%20and%20Alert.sql)

## Classic Version

This repository also contains the "classic" versions of the scripts. [Click here for more details](classic/), or download below:

- [🔽 ChangeJobStatusBasedOnHADR.sql](classic/ChangeJobStatusBasedOnHADR.sql)
- [🔽 ChangeJobStatusBasedOnMirroring.sql](classic/ChangeJobStatusBasedOnMirroring.sql)

## License

This solution is released under the [MIT License](LICENSE), and is provided "as-is", as a free contribution to the professional SQL Server community.

## Contribution

This is an open-source solution. Please feel free to [create issues]({{ site.github.repository_url }}/issues) if you want to submit bug reports or feature requests.

You may also **fork** the solution to your account and submit pull requests if you want to contribute!

## See Also

- [Blog Post: Control SQL Jobs based on HADR Role – Taking it to the Next Level](https://eitanblumin.com/2020/05/26/sql-jobs-based-on-hadr-role-next-level/)
- [Webinar: How to HADR Your SQL Jobs](https://eitanblumin.com/portfolio/how-to-hadr-your-sql-jobs/)

Tell your friends! Share this link: [bit.ly/HADRMyJobs](https://bit.ly/HADRMyJobs)