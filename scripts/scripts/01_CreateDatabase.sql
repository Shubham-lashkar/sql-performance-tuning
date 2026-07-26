/*
Project : SQL Performance Tuning
Database : BankingDB
Author   : Shubham Lashkar
Purpose  : Sample database for SQL performance tuning demonstrations.

NOTE:
This is a demo database created for learning purposes only.
No production or company data is used.
*/

IF DB_ID('BankingDB') IS NULL
BEGIN
    CREATE DATABASE BankingDB;
END;
GO

USE BankingDB;
GO
