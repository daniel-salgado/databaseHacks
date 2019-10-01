DECLARE @Table TABLE ( LogicalName sysname NOT NULL
    ,PhysicalName varchar(255) NOT NULL
    ,[Type] char(1) NOT NULL
    ,FileGroupName sysname NULL
    ,Size numeric(20,0) NOT NULL
    ,MaxSize numeric(20,0) NOT NULL
    ,FileId bigint NOT NULL
    ,CreateLSN numeric(25,0) NOT NULL
    ,DropLSN numeric(25,0) NULL
    ,UniqueId uniqueidentifier NOT NULL
    ,ReadOnlyLSN numeric(25,0) NULL
    ,ReadWriteLSN numeric(25,0) NULL
    ,BackupSizeInBytes bigint NOT NULL
    ,SourceBlockSize int NOT NULL
    ,FileGroupId int NULL
    ,LogGroupGUID uniqueidentifier NULL
    ,DifferentialBaseLSN numeric(25,0) NULL
    ,DifferentialBaseGUID uniqueidentifier NOT NULL
    ,IsReadOnly bit NOT NULL
    ,IsPresent bit NOT NULL
)
DECLARE @Path varchar(1000)='C:\Shares\Storage\Daniel\SMEVS\DVM Backup_ezyVet_20190930.bak'
DECLARE @LogicalNameData varchar(128),@LogicalNameLog varchar(128)
INSERT INTO @table
EXEC('
RESTORE FILELISTONLY 
   FROM DISK=''' +@Path+ '''
   ')

-- SET @LogicalNameData=(SELECT LogicalName
-- FROM @Table
-- WHERE Type='D')
-- SET @LogicalNameLog=(SELECT LogicalName
-- FROM @Table
-- WHERE Type='L')

SELECT @LogicalNameData, @LogicalNameLog

select *
from @table