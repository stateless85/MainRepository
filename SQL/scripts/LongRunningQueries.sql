SELECT SPID,ER.percent_complete,

 CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar)       + ' hour(s), '
    + CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + 'min, '
    + CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar)      + ' sec' as running_time
,CAST((estimated_completion_time/3600000) as varchar)             + ' hour(s), '
    + CAST((estimated_completion_time %3600000)/60000 as varchar) + 'min, '
    + CAST((estimated_completion_time %60000)/1000 as varchar)    + ' sec' as est_time_to_go
,DATEADD(second,estimated_completion_time/1000, getdate()) as est_completion_time
,ER.command
,ER.blocking_session_id
,SP.DBID,LASTWAITTYPE
,DB_NAME(SP.DBID) AS DBNAME
,SUBSTRING(est.text, (ER.statement_start_offset/2)+1,

((CASE ER.statement_end_offset
  WHEN -1 THEN DATALENGTH(est.text)
  ELSE ER.statement_end_offset
  END - ER.statement_start_offset)/2) + 1) AS QueryText
,TEXT
,CPU
,HOSTNAME
,LOGIN_TIME
,LOGINAME
,SP.status
,PROGRAM_NAME
,NT_DOMAIN
,NT_USERNAME
,CONVERT(XML, u.query_plan)
FROM SYSPROCESSES SP
INNER JOIN sys.dm_exec_requests ER
 ON sp.spid = ER.session_id
CROSS APPLY SYS.DM_EXEC_SQL_TEXT(er.sql_handle) EST
CROSS APPLY sys.dm_exec_query_plan(er.plan_handle ) u
ORDER BY CPU DESC   

-- STATS UPDATED
SELECT OBJECT_NAME(s.[object_id]) AS [ObjectName]
      ,s.[name] AS [StatisticName]
      ,STATS_DATE(s.[object_id], s.[stats_id]) AS [StatisticUpdateDate]
-- select *
FROM sys.stats AS s
JOIN sys.objects o
       on s.object_id = o.object_id
WHERE type = 'U'
--and OBJECT_NAME(s.[object_id])  like '%job%'


-- STATS QUERY 
SELECT

OBJECT_NAME([sp].[object_id]) AS "Table",
[sp].[stats_id] AS "Statistic ID",
[s].[name] AS "Statistic",
[sp].[last_updated] AS "Last Updated",
[sp].[rows],
[sp].[rows_sampled],
[sp].[unfiltered_rows],
[sp].[modification_counter] AS "Modifications"
,[sp].[modification_counter]/ cast([sp].[unfiltered_rows] as float) percentOfmodifed
-- select *
FROM [sys].[stats] AS [s]
JOIN sys.[tables] AS t
    ON [s].[object_id] = [t].[object_id] and  t.type = 'u'
OUTER APPLY sys.dm_db_stats_properties ([s].[object_id],[s].[stats_id]) AS [sp]
order by percentOfmodifed desc
