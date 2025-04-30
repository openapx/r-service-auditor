--
--  the simplest database schema for auditor on PostgreSQL 
--
--

-- service account
-- note: assuming auditorsvc as an example but it is really up to you
-- note: if you are using another account name .. make sure you update grant statements
-- create user auditorsvc with encrupted password '<password>' nosuperuser nocreatedb ;


-- main record table

create table if not exists tbl_adt_records (
   uid             uuid not null primary key,
   str_event       varchar(50) not null,
   str_type        varchar(100) not null,
   str_class       varchar(100) not null,
   str_ref         varchar(2048) not null,
   str_objecthash  varchar(128) not null,
   str_label       varchar(512) not null,
   str_actor       varchar(512) not null,
   ts_datetime     timestamp not null default current_timestamp  
);

grant select, insert on tbl_adt_records to auditorsvc;


-- attributes associated with the main record

create table if not exists tbl_adt_record_attrs (
   uid_rec	  uuid not null references tbl_adt_records(uid),
   str_key    varchar(1024) not null,
   str_label  varchar(512) not null,
   str_qual   varchar(50) not null default 'current_value',
   str_value  varchar(1024),
   int_vseq   int default 0
);

grant select, insert on tbl_adt_record_attrs to auditorsvc;


-- crude approach to linking audit records

create table if not exists tbl_adt_record_links (
   uid        uuid not null,
   uid_rec    uuid not null references tbl_adt_records(uid)
);

grant select, insert on tbl_adt_record_links to auditorsvc;



