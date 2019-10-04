USE master;
GO

CREATE OR ALTER PROCEDURE [dbo].[uspRestoreFromBackup]
    @DBName     nVARCHAR(MAX) --target database name
    ,@BackupFile nVARCHAR(MAX) --source backup file
    ,@DataPath   nVARCHAR(MAX) = 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\'
--target log path
AS
BEGIN

    SET NOCOUNT ON

    /*************************************************************************************
    * DATABASE   : master
    * OBJECT NAME: [dbo].[uspRestoreFromBackup]
    * WorkOrder  : 
    * DATE       : 2019-10-02
    * CREATED BY : Daniel Salgado
    * DESCRIPTION: Restore database from a file; rename the logical files; move physical files
    *              exec master.dbo.uspRestoreFromBackup 'dvmBVS', 'C:\Shares\Storage\Daniel\BronsonVeterinaryServices\SalesDataCheck\DVMDEBAK.BAK'
    **************************************************************************************/

    /*
        This script will generate a "RESTORE DATABASE" command with the correct "MOVE" clause, etc.
    
        By: Max Vernon
        https://dba.stackexchange.com/questions/234925/is-there-a-way-to-retrieve-the-logical-filename-from-a-backup-file
    */

    DECLARE @FileListCmd            nvarchar(max);
    DECLARE @RestoreCmd             nvarchar(max);
    DECLARE @cmd                    nvarchar(max);
    DECLARE @Version                decimal(10,2);
    DECLARE @MaxLogicalNameLength   int;
    DECLARE @MoveFiles              nvarchar(max);


    /* ************************************
    
        modify nothing below this point.
    
       ************************************ */
    IF RIGHT(@DataPath, 1) <> '\' 
        SET @DataPath = @DataPath + N'\';

    SET @cmd = N'';

    SET @Version = CONVERT(decimal(10,2), 
        CONVERT(varchar(10), SERVERPROPERTY('ProductMajorVersion')) 
        + '.' + 
        CONVERT(varchar(10), SERVERPROPERTY('ProductMinorVersion'))
        );

    IF @Version IS NULL --use ProductVersion instead
    BEGIN
        DECLARE @sv varchar(10);
        SET @sv = CONVERT(varchar(10), SERVERPROPERTY('ProductVersion'));
        SET @Version = CONVERT(decimal(10,2), LEFT(@sv, CHARINDEX(N'.', @sv) + 1));
    END

    DROP TABLE if EXISTS #FileList;

    CREATE TABLE #FileList
    (
        LogicalName sysname NOT NULL
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
    );

    IF @Version >= 10.5 
        ALTER TABLE #FileList ADD TDEThumbprint varbinary(32) NULL;
    IF @Version >= 12  
        ALTER TABLE #FileList ADD SnapshotURL nvarchar(360) NULL;

    SET @FileListCmd = REPLACE('RESTORE FILELISTONLY FROM DISK = ''?BackupFile'';', '?BackupFile', @BackupFile);

    INSERT INTO #FileList
    EXEC (@FileListCmd);

    SET @MaxLogicalNameLength = COALESCE((SELECT MAX(LEN(fl.LogicalName)) FROM #FileList fl), 0);

    SELECT @MoveFiles = (SELECT N', MOVE N''' + fl.LogicalName + N''' ' 
        + REPLICATE(N' ', @MaxLogicalNameLength - LEN(fl.LogicalName)) 
        + N'TO N''' +  @DataPath
        +  @DBName + CASE WHEN fl.Type = 'L' THEN N'.log' 
                                    ELSE 
                                        CASE WHEN fl.FileGroupName = N'PRIMARY' THEN N'.mdf'
                                         ELSE N'.ndf' 
                                         END 
                                    END + N'''
        '
        FROM #FileList fl
        FOR XML PATH(''));

    SET @MoveFiles = REPLACE(@MoveFiles, N'&#x0D;', N'');
    SET @MoveFiles = REPLACE(@MoveFiles, char(10), char(13) + char(10));
    SET @MoveFiles = LEFT(@MoveFiles, LEN(@MoveFiles) - 2);

    SET @RestoreCmd = N'RESTORE DATABASE ?DBName FROM DISK = ''?BackupFile'' WITH REPLACE, RECOVERY, STATS = 5' + @MoveFiles;
    SET @RestoreCmd = REPLACE(@RestoreCmd, '?DBName', @DBName);
    SET @RestoreCmd = REPLACE(@RestoreCmd, '?BackupFile', @BackupFile);

    IF LEN(@RestoreCmd) > 4000 
    BEGIN
        
        DECLARE @CurrentLen int;
        
        SET @CurrentLen = 1;
        
        WHILE @CurrentLen <= LEN(@RestoreCmd)
        BEGIN
            PRINT SUBSTRING(@RestoreCmd, @CurrentLen, 4000);
            SET @CurrentLen = @CurrentLen + 4000;
        END

        RAISERROR (N'Output is chunked into 4,000 char pieces - look for errant line endings!', 14, 1);

    END
    ELSE
    BEGIN
        exec (@RestoreCmd);
    END

END
