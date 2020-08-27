use [DatabaseName]
go

-- Set ansi nulls
set ansi_nulls on
go

-- Set quoted identifier
set quoted_identifier on
go

-- ==========================
--        File: GeneratedMac
--     Created: 08/26/2020
--     Updated: 08/26/2020
--  Programmer: Cuates
--   Update By: Cuates
--     Purpose: Generated mac
-- ==========================
create table [dbo].[GeneratedMac](
  [gmID] [bigint] identity (1, 1) not null,
  [created_date] [datetime2](7) not null,
  [modified_date] [datetime2](7) null,
  [generated_mac] [nvarchar](70) not null,
  [searchable_serial] [nvarchar](70) null,
  [mac_family] [nvarchar](70) null,
  constraint [UK_GeneratedMac_generated_mac_family] unique nonclustered
  (
    [generated_mac],
    [mac_family]
  )with (pad_index = off, statistics_norecompute = off, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [primary]
) on [primary]
go

alter table [dbo].[GeneratedMac] add  default (getdate()) for [created_date]
go

alter table [dbo].[GeneratedMac] add  default (getdate()) for [modified_date]
go