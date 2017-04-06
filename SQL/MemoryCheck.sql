--Identify wait stats
SELECT * FROM SYSPROCESSES
ORDER BY lastwaittype

-- Resource Semaphore Allocation
SELECT * FROM sys.dm_exec_query_resource_semaphore

-- Check memory grants per query 
SELECT gr.*,
SUBSTRING(qt.text,r.statement_start_offset/2,
(case when r.statement_end_offset = -1 then len(convert(nvarchar(max), qt.text)) * 2
 else r.statement_end_offset end -r.statement_start_offset)/2) as query_text
 ,CONVERT(XML, PH.query_plan) AS query_plan
-- select *
FROM sys.dm_exec_requests r
join  sys.dm_exec_query_memory_grants gr
    on r.session_Id = gr.session_Id
CROSS APPLY sys.dm_exec_sql_text(gr.sql_handle) AS QT
CROSS APPLY sys.dm_exec_sql_plan(gr.plan_handle) AS PH

-- Find who uses the most query memory grant:
SELECT TOP(20) mg.granted_memory_kb, mg.session_id, t.text, qp.query_plan
FROM sys.dm_exec_query_memory_grants AS mg
CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) AS t
CROSS APPLY sys.dm_exec_query_plan(mg.plan_handle) AS qp
ORDER BY 1 DESC OPTION (MAXDOP 1)

-- Search cache for queries with memory grants:
SELECT t.text, cp.objtype,qp.query_plan
FROM sys.dm_exec_cached_plans AS cp
JOIN sys.dm_exec_query_stats AS qs ON cp.plan_handle = qs.plan_handle
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS t
WHERE qp.query_plan.exist(‘declare namespace n=”http://schemas.microsoft.com/sqlserver/2004/07/showplan“; //n:MemoryFractions’) = 1
