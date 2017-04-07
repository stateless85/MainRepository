--Identify wait stats
SELECT * FROM SYSPROCESSES
ORDER BY lastwaittype

-- Resource Semaphore Allocation
SELECT PO.Name AS PoolName, CASE WHEN S.resource_semaphore_id = 0 THEN 'regular' else 'small' END AS QuerySemaphore,   S.*, PO.*
FROM sys.dm_exec_query_resource_semaphores AS S
INNER JOIN sys.dm_resource_governor_resource_pools AS PO
	ON PO.Pool_id = S.Pool_Id

-- Check memory grants per query 
SELECT 
	PO.Name AS PoolName,
	Query_Text  = SUBSTRING(qt.text,r.statement_start_offset/2, (case 
													when r.statement_end_offset = -1 then len(convert(nvarchar(max), qt.text)) * 2 
													else r.statement_end_offset
												   end -r.statement_start_offset)/2)
	,Query_Plan	= CONVERT(XML, PH.query_plan)
	,s.login_name
	,r.wait_type
	,r.last_wait_type
	,gr.dop Query_Parallelism, gr.requested_memory_kb, gr.granted_memory_kb, gr.required_memory_kb, gr.used_memory_kb, gr.max_used_memory_kb, gr.ideal_memory_kb, gr.query_cost
-- select *
FROM sys.dm_exec_requests r
join  sys.dm_exec_query_memory_grants gr
    on r.session_Id = gr.session_Id
join sys.dm_exec_sessions as s
	on s.session_id = r.session_id
INNER JOIN sys.dm_resource_governor_resource_pools AS PO
	ON PO.Pool_id = gr.Pool_Id
CROSS APPLY sys.dm_exec_sql_text(gr.sql_handle) AS QT
CROSS APPLY sys.dm_exec_query_plan (gr.plan_handle) AS PH

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
