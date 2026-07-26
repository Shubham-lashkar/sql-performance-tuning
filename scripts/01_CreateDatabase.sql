/*
================================================================================
 File        : 01_CreateDatabase.sql
 Purpose     : Create the sample enterprise database used throughout this
               repository (OrderManagementDB) with correct file layout,
               recovery model, and compatibility level for SQL Server.
 Author      : Shubham Lashkar
 Repo        : sql-performance-tuning
================================================================================
*/

USE master;
GO

-- Drop database if it already exists (safe re-run for demo/training purposes)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'OrderManagementDB')
BEGIN
    ALTER DATABASE OrderManagementDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OrderManagementDB;
END
GO

-- ============================================================================
-- Create database with separate data/log files (best practice: never rely on
-- default MDF/LDF paths in production)
-- ============================================================================
CREATE DATABASE OrderManagementDB
ON PRIMARY
(
    NAME = N'OrderManagementDB_Data',
    FILENAME = N'C:\SQLData\OrderManagementDB.mdf',
    SIZE = 512MB,
    MAXSIZE = 10GB,
    FILEGROWTH = 128MB
)
LOG ON
(
    NAME = N'OrderManagementDB_Log',
    FILENAME = N'C:\SQLData\OrderManagementDB_log.ldf',
    SIZE = 256MB,
    MAXSIZE = 4GB,
    FILEGROWTH = 64MB
);
GO

ALTER DATABASE OrderManagementDB SET COMPATIBILITY_LEVEL = 160; -- SQL Server 2022
GO

USE OrderManagementDB;
GO

-- ============================================================================
-- Recovery & performance-relevant database settings
-- ============================================================================
ALTER DATABASE OrderManagementDB SET RECOVERY FULL;
ALTER DATABASE OrderManagementDB SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE OrderManagementDB SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE OrderManagementDB SET AUTO_UPDATE_STATISTICS_ASYNC ON;   -- reduces query-time stat recompute stalls
ALTER DATABASE OrderManagementDB SET READ_COMMITTED_SNAPSHOT ON;       -- reduces blocking (row versioning)
ALTER DATABASE OrderManagementDB SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE OrderManagementDB SET PAGE_VERIFY CHECKSUM;
GO

-- Dedicated filegroup for indexes (optional, useful for I/O separation demos)
ALTER DATABASE OrderManagementDB ADD FILEGROUP FG_Indexes;
GO

ALTER DATABASE OrderManagementDB
ADD FILE
(
    NAME = N'OrderManagementDB_Indexes',
    FILENAME = N'C:\SQLData\OrderManagementDB_Indexes.ndf',
    SIZE = 256MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 64MB
) TO FILEGROUP FG_Indexes;
GO

PRINT 'OrderManagementDB created successfully with performance-optimized settings.';
GO
