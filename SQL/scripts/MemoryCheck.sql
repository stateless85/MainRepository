-- https://blogs.msdn.microsoft.com/sqlqueryprocessing/2010/02/16/understanding-sql-server-memory-grant/

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
OUTER APPLY sys.dm_exec_sql_text(gr.sql_handle) AS QT
OUTER APPLY sys.dm_exec_query_plan (gr.plan_handle) AS PH

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

-- Memory Monitor Per Database
SELECT
 [DatabaseName] = CASE [database_id] WHEN 32767
 THEN 'Resource DB'
 ELSE DB_NAME([database_id]) END,
 COUNT_BIG(*) [Pages in Buffer],
 COUNT_BIG(*)/128 [Buffer Size in MB]
FROM sys.dm_os_buffer_descriptors
GROUP BY [database_id]
ORDER BY [Pages in Buffer] DESC;

-- Memory usage by DB object
SELECT obj.name [Object Name], o.type_desc [Object Type],
i.name [Index Name], i.type_desc [Index Type],
COUNT(*) AS [Cached Pages Count],
COUNT(*)/128 AS [Cached Pages In MB]
FROM sys.dm_os_buffer_descriptors AS bd
INNER JOIN
(
SELECT object_name(object_id) AS name, object_id
,index_id ,allocation_unit_id
FROM sys.allocation_units AS au
INNER JOIN sys.partitions AS p
ON au.container_id = p.hobt_id
AND (au.type = 1 OR au.type = 3)
UNION ALL
SELECT object_name(object_id) AS name, object_id
,index_id, allocation_unit_id
FROM sys.allocation_units AS au
INNER JOIN sys.partitions AS p
ON au.container_id = p.partition_id
AND au.type = 2
) AS obj
ON bd.allocation_unit_id = obj.allocation_unit_id
INNER JOIN sys.indexes i ON obj.[object_id] = i.[object_id]
INNER JOIN sys.objects o ON obj.[object_id] = o.[object_id]
WHERE database_id = DB_ID()
GROUP BY obj.name, i.type_desc, o.type_desc,i.name
ORDER BY [Cached Pages In MB] DESC; 
