# Auditor service

The auditor service is a simple audit trail service REST API written in R using {plumber}.

The core principle is simplicity in tracking events across systems and services 
in distributed computing environments where not all events and actions occur in 
a single app, node, pod, container, virtual machine or dedicated compute environment.

The service is a registry of audited events, meaning that the service does not 
audit or monitor a service, an application or a system, but those same
services, applications and systems can register events in the audit trail.

This permits you to track events, actions and content, such as files, across 
environments rather than having to piece together the audit trail from the audit
trails of each individual and separate application, service, environment or 
system.

<br/>

### The Audit Record

The _audit record_ represent a noted event, change, action or occurrence for or on
an _object_ performed or initiated by an _actor_, such as a user or a service.

The audit record aims to answer _Who did What When and Where_. If this is not 
documented in the audit trail, or somewhere else, it is essentially a rumor that
cannot be verified or never happened.

Given that the audit trail can include audit records for almost anything, e.g. an
audited item, artifact, thing, or generally the audited _object_ can represent
pretty much anything, the audit record can also record one or more qualifying 
attributes. The attributes can provide additional context to the event or action, 
the object itself or provide additional details on where the event occurred or
the action was performed, such as which compute environment.

An aspect of the current compute environments, and their complexity, is that an
event or action does not just affect one object but could affect multiple objects.
In some cases, it may be required that the event or action is noted for all the 
affected objects. As such, an audited event or action consists not of one but 
several _linked_ audit records. 

The auditor service automatically links all audit records that are submitted 
together. Adding links after the records have been created is currently not
supported by the auditor API.

A secondary effect of the distributed compute environments of today, is that
there may be a need to audit events and actions across environments on the same
_object_, such as a data file being downloaded, pushed or staged to many different
compute environments or services. The _object_ is represented by a reference digest, 
sometimes also referred to as the hash, checksum, message digest, etc. 

A key property of the digest is that given the content, say a character string, 
set of values or file, the digests will be different if that character string, 
values or file is different. The digest would be the same if two copies are the
same. Simply put, if a file stored in two different compute environments have the
same digest, the files inclde the same content, regardless of the file name 
or where in the directory and folder structure it is stored.

As a practical example, if the same file is copied across various environments 
and the file's _object_ reference is its SHA-1 digest, all audit trail records 
for that file can be associated by the SHA-1 digest, essentially giving you the
ability to track the files journey across environments and storage mediums.

The audit record itself includes additional references. The _type_ is the object
type, e.g. a file, job, task, a variable definition in metadata, etc. 

The _type_ is in many cases a generic reference, since type `datafile` or `file`
can mean almost anything. An object _class_ is a classification of the type. For
example, the _class_ `sdtm` for a `datafile` type can provide additional context as 
to what the `datafile` is representing.

At the same time, we can potentially have more than one item of type `datafile` with 
class `sdtm`. The audit record uses a common _reference_ to permit additional context.
As an example, an entry with _reference_ `AE` of type `datafile` and class `sdtm` 
could likely represent a data set file for the Adverse Event SDTM domain.

If we once again consider that an audit record represents _Who did What When and Where_.

- _Who_ ... is the actor, i.e. user or service.
- _What_ ... is the combination of type, class and reference that would represent the _What_. The object
hash would further identify which version of _What_ by its content. 
- _When_ ... is the record date.
- _Where_ ... is more complex since it may involve several pieces of information, 
such as the host, the directory path within that host, a database, and so on. All 
this is captured as part of the record attributes to provide the flexibility needed
to reconstruct and answer _Where_ the event occurred or action was performed.

<br/>
<br/>

### Dependencies
The auditor service depends on the R package cxapp for configuration, logging and
API authentication. Some of those topics will be briefly mentioned here but please 
refer to the cxapp documentation for additional details.

You can find the cxapp package here [https://github.com/cxlib/r-package-cxapp](https://github.com/cxlib/r-package-cxapp).

<br/>
<br/>


### Getting Started
The auditor service is available either pre-built container image on Docker Hub
or as the R package `auditor.service`.

<br/>

#### Container Image on Docker Hub 

The auditor service container image is available for multiple Linux operating 
system flavors depending on your organization preference.

```
docker pull openapx/auditor.service:<OS>-latest
```

or choose a particular container image version.

<br/>

##### Service Start

The service is installed in the directory `/opt/openapx/apps/auditor` (`APP_HOME`).

The service is started by the standard entry point script `/entrypoint.sh` with 
no arguments.

Start up options are set in the `APP_HOME/service.properties` file.

`WORKERS` specifies the number of parallel R Plumber _worker_ sessions to launch.
A worker equates to the number of requests the service can serve concurrently. Note
that Plumber and the way the API has been written, it is one request per R session.

`LOCAL.DATABASE=ENABLE | DISABLE` enables or disables using the installed default
internal database.

_For production use, do not use the local database_.

<br/>

##### Service Configuration

The service configuration options are set in the `APP_HOME/app.properties` file 
and includes a default configuration (below) to quickly get started. 

_Please note that currently only PostgreSQL database is supported_.

There are three standard directories.

- `/data` for service logs and other service data files
- `/dbdata` for database data files when local database is enabled
- `/.vault` used for a local internal vault

<br/>


```
# -- default service configuration


# -- database
#    note: only supported vendor is postgres
#    note: value for vendor is future use to allow for variations in SQL syntax
DB.VENDOR = postgres

DB.DRIVER = RPostgreSQL::PostgreSQL()
DB.HOST = localhost
DB.PORT = 5432
DB.DATABASE = auditor

#    note: the auditorsvc password for the local database is generated when  
#          /entrypoint.sh is executed and local database is enabled
DB.USERNAME = auditorsvc
DB.PASSWORD = [vault] /dblocal/auditor/password



# -- logging 
LOG.PATH = /data/auditor/logs
LOG.NAME = auditor
LOG.ROTATION = month


# -- vault configuration

#    note: using a local vault
#    note: Azure Key Vault also supported
VAULT = LOCAL
VAULT.DATA = /.vault


# -- API authorization
#    note: access tokens should be created 
#    note: see reference section Authentication in the auditor service API reference
#    note: see section API Authentication in the cxapp package https://github.com/cxlib/r-package-cxapp 
API.AUTH.SECRETS = /test/auth/services/auditor/*

```

<br/>

#### As an R Package
Download and install the latest release of auditor.service from https://github.com/openapx/r-service-auditor/releases/latest

You can also install the latest release directly using install.packages().

```
# -- install dependencies
#    note: see DESCRIPTION for pacakge dependencies
#    note: cxapp can be found at https://github.com/cxlib/r-package-cxapp

install.packages( "https://github.com/openapx/r-service-auditor/releases/download/v0.0.0/auditor.service_0.0.0.tar.gz", type = "source", INSTALL_opts = "--install-tests" )
```

To install prior releases, replace the version number references in the URL.

Please the default configuration for the audit service container image for 
required configuration options.

<br/>
<br/>

### API Reference

<br/>

#### Authentication
The API uses Bearer tokens to authenticate a connection request using the standard
header

```
Authorization: Bearer <token>
```

See `cxapp::cxapp_authapi()` and the API Authentication section for the cxapp 
package for further details and configuration options.

<br/>

#### List audit records

```
GET /api/records
GET /api/records?<options>
```

Returns a list of audit records.

_Note that in this release, the database has not been optimized for queries_.   

The returned records are in the format of a JSON array of audit record objects.

```
[
  {
    "id": "<record identifier>",
    "event": "<event>",
    "type": "<object type>",
    "class": "<class of object type>",
    "reference": "<reference>",
    "object": "<object hash>",
    "label": "<record label>",
    "actor": "<actor>",
    "env": "<environment>",
    "datetime": "<record date and time>"
  },
  ...
]

```

The `id` is the audit record identifier in UUID format.

The values for `event`, `type`, `class`, and `reference` are case 
in-sensitive keywords but by convention returned in upper case.

The `label` is human-readable short description and it's value is URL encoded.

The value of `datetime` is the record date and time in the format
_yyyymmddThhmmss_ with hour, minutes and seconds with leading zeros. The date 
and time is provided without timezone.

The `actor`value represents the user or service who performed or initiated the 
event or action.

The `env` value represent the environment where the actions was performed or 
initiated.

See section Create Audit Records for specific details on the returned properties.

<br/>

##### Selection Filter

The default list includes the last 300 records for the preceding 30 days. Further
refined selection of records can be defined through one or more filter options
in the query string. Note options are separated by the `&` character.

All options and option values are case in-sensitive.

An option on the query string is specified as the filter option name and one or 
more values. Multiple values for an option can defined by either separating each 
value with a comma without spaces or repeating the option for each value.

```
GET /api/records?option=value1,value2
GET /api/records?option=value1&option=value2
```
The options `from`, `to`, `limit`, `offset` and `select` can only be a single value.

The following options are available.

- `event` the audited event (see Create Audit Records below for valid values)
- `type` the type of the audit object
- `class` further classifies the type of object, such as `sdtm` for type `datafile`
- `reference` common reference
- `object`is the object hash value
- `actor` is the service or user associated with an audited event
- `env` is the environment associated with an audited event 
- `from` is start of the period for selecting audit records by their corresponding date
- `to` is end of the period for selecting audit records by their corresponding date
- `limit` is the number of records to retrieve
- `offset` is the first record number to select from
- `select` is the direction from which the number of records is taken


The date range specified by `from` and `to` uses the format `yyyymmddThhmmss`.
Currently partial date and time are not supported.

If `select=first`, the records selected are those in order of chronological
occurrence by date.

If `select=last`, which is also the default, the records selected are those in order
of occurrence by descending date (starting with the last record first). 

The options `limit`and `offset` can be used to only return a set number of records
and/or _page_ through the records returned. The `select` option is applied before
limiting and offsetting any records.

_Note_ that if there are multiple records for the same date and time and the 
selection boundary set by `limit`, `offset` and `select` is such that some records
fall within the selected set and some records are outside of the selection, the 
cut-off is arbitrary. To ensure that all the records for a given period of interest
is included, increase the number of records specified by `limit` to ensure that
all the records for a given period is returned.

<br/>

##### Example 1

Selecting the audit records for all `CREATE` and `UPDATE` events 
associated with the type `DATAFILE` during the last 30 days (default `from` and
`to`). We are assuming that there is no more than 100 000 records.

```
GET /api/records?event=create&event=update&type=datafile&limit=100000
GET /api/records?event=create,update&type=datafile&limit=100000
```

We should note that in the above example, 100 000 records can be a significant 
volume. It would be much more efficient if you use `limit=1000` and then 
incremental increasing `offset` to _page_ through the records and retrieve them 
as part of a query loop.

<br/>

##### Example 2

Selecting the first 500 audit records in chronologically sequence for the month 
of March 2025.

```
GET /api/records?from=20250301T000000&to=20250331T235959&limit=500&select=first
```

Note that the above query will not inform if there are additional records beyond 
those chronologically first 500 records.


<br/>
<br/>

#### Create Audit Records

```
POST /api/records
```

Creates one or more audit records.   

<br/>

_Note that all submitted records are saved in the database using a single 
transaction, meaning if one record is invalid, then none of the submitted 
records in the request will be saved_.

<br/>

##### Audit Record

The audit records provided in the body of the request in the format of a JSON
array with each record as a separate JSON object.

```
[
  {
    "event": "<event>",
    "type": "<object type>",
    "class": "<class of object type>",
    "reference": "<reference>",
    "object": "<object hash>",
    "label": "<record label>",
    "actor": "<actor>",
    "env": "<environment>",
    "datetime": "<record date and time>"
    "attributes" : [
                     {
                       "key" : "<attribute key>",
                       "label" : "< atribute label>",
                       "qualifier" : "<value qualifier>",
                       "value" : "<attribute value>"
                     }, 
                     ...
                   ]
  },
  ...
]

```

The `event` defines the event or action that the audit record represents. Valid
values are `create`, `read`, `update`, `delete`, `execute`, `sign`, `connect` 
and `disconnect`. The event value is case in-sensitive but represented in lower 
case.

The object `type`, `class` and `reference` are case in-sensitive keywords and
references used to programmatically represent the object. Valid characters are
letters `A-Z`, digits `0-9`, period `.`, dash `-` and underscore `_`. Invalid
characters are translated to an underscore `_`.

The `object` value is optional. If not provided, the SHA-1 digest of the string
`object:<type>:<class>:<reference>` is used. 

The record `label` is a free-text field to provide a human-readable reference to
the event or action. The `label` should be URL encoded.

The `actor` value represents the user or service who performed or initiated the 
event or action. The value is stored verbatim as provided to allow for correct
representation of the user or service. The value is not URL encoded by the service, 
so if the actor value includes special characters, they should be submitted in 
encoded or translated form.

The `env` value represents the environment associated with the event or action.
The value is stored verbatim and is not URL encoded.

The `datetime` value is in the format `yyyymmddThhmmss` with leading zeros for 
month, day, hour, minutes and seconds. The service assumes that the date and time
is provided in the organization standard time zone reference.

<br/>


##### Audit Record Attributes
Audit record attributes permits including additional context beyond the main
record as in the form of a key/value pair.

The attribute `key` refers to the attribute programmatic reference. Valid 
characters are letters `A-Z`, digits `0-9`, period `.`, dash `-` and 
underscore `_`. Invalid characters are translated to an underscore `_`.

The value of the attribute `key` does not have to be unique within the list of 
audit record attributes.

The attribute `label` is an optional free-text field to provide a human-readable 
reference to the attribute. If the attribute `label` is not specified, the 
attribute `key` is used. The specified value of the attribute `label` should be 
URL encoded.

The optional attribute `qualifier` is a free-text value that permits adding 
additional context to the attribute value, such as _new_ versus _old_ values if
the audit record should capture the original value and the newly assigned.
The value for attribute `qualifier` should be URL encoded.

Only `key`and `value`are mandatory properties.

<br/>

##### Audit Record Links
Links between audit records are automatically created if more than one audit 
record is submitted as part of the request. 

Currently, only links between the submitted records are supported and a link cannot
be added after an audit record has been saved.

<br/>
<br/>

#### Retrieve an audit record

```
GET /api/records/<record id>
```

Returns a single audit record.

The returned record is in the format of a JSON object.

```
{
  "id": "<record identifier>",
  "event": "<event>",
  "type": "<object type>",
  "class": "<class of object type>",
  "reference": "<reference>",
  "object": "<object hash>",
  "label": "<record label>",
  "actor": "<actor>",
  "env": "<environment>,
  "datetime": "<record date and time>", 
  "attributes" : [
                     {
                       "key" : "<attribute key>",
                       "label" : "< atribute label>",
                       "qualifier" : "<value qualifier>",
                       "value" : "<attribute value>"
                     }, 
                     ...
                  ],
  "links" : [
               {
                 "id": "<record identifier>",
                 "event": "<event>",
                 "type": "<object type>",
                 "class": "<class of object type>",
                 "reference": "<reference>",
                 "object": "<object hash>",
                 "label": "<record label>"
               },
               ...
            ]
}
 
```

The `id` is the audit record identifier in UUID format.

The audit record `event`.

The object `type`, `class` and `reference` are keywords and references used to
programmatically represent the object.

The `object` value is the provided object hash, either specified or generated
(see Create Audit Records).

The audit record `label` value in URL encoded format.

The `actor`value represents the user or service who performed or initiated the 
event or action. The value is returned in verbatim form as provided to allow 
for correct representation of the user or service. 

The `env` value represents the environment associated with the event or action.

The value of `datetime` is the record date and time in the format
_yyyymmddThhmmss_ with hour, minutes and seconds with leading zero's. The date 
and time is returned as recorded with no assumption or translating to a
particular timezone.

<br/>

##### Audit Record Attributes
The attribute `key` is provided as the attribute programmatic reference. The 
value of the attribute `key` does not have to be unique within the list of 
audit record attributes.

The attribute `label` value in URL encoded format.

The attribute `qualifier` value if recorded or an empty string if not specified
when the record was created. The value URL encoded.

The attribute `value` in URL encoded format.

<br/>

##### Audit Record Links
Linked audit records are provided as a reference and includes the linked
audit record `id`, `event`, `type`, `class`, `reference`, `object` and 
`label`.

<br/>
<br/>

#### Service information

```
GET /api/info
```
Get service information

The returned record is in the format of a JSON object.

```
{
  "service": "auditor",
  "version": "<auditor version>",
  "database": {
    "pool": {
      "active.connections": "<number of active connections>",
      "available.connections": "<number of available connections>",
      "max.connections": "<maximum pool size>"
    },
    "configuration": {
      "db.vendor": "<database vendor>",
      "db.driver": "<database driver>",
      "db.host": "<host>",
      "db.port": "<port>",
      "db.username": "<database account>",
      "db.password": "<defined | not defined>",
      "db.pool.minsize": "<database pool minimum size>",
      "db.pool.maxsize": "<database pool maximum size>",
      "db.pool.idletimeout": "<database pool idle timeout>"
    }
  }
}
```

The reported `active.connections`, `available.connections` and `max.connections`
are the values reported by the database pool for the R session serving the 
request. A value of `active.connections` other than `0` may be an indication of 
leaked or hung database connections.

The `configuration` under `database` reports the current database configuration 
properties. A value `<not defined>` indicates that the database configuration 
property is not defined in the application properties.

The `db.password` reported value is either `<defined>` or `<not defined>`. The
clear-text or encoded password is not reported.

<br/>
<br/>

#### Ping

```
GET /api/ping
```

The ping API endpoint is a simple method to ensure that the service is reachable 
and returns status code `200`.

Authentication is not required.

<br/>
<br/>

### Configuration
The service relies on the cxapp package for configuration, logging and 
authorizing API requests.

Audit records are stored in a relational database. Currently, only PostgreSQL 
is supported but additional databases will be added in the near future.

<br/>

#### Application Configuration

The configuration is defined through the `app.properties`file located in one of 
the following directories.

- current working directory
- the `$APP_HOME/config`or `$APP_HOME`directory where `$APP_HOME` is an environmental variable
- first occurrence of the {auditor.service} package installation in `.libPaths()`

See `cxapp::cxapp_config()` for further details.

<br/>

#### Database

The following app properties are used for database connections. The service uses the R packages {pool} 
and {DBI} internally to manage connections.

- `DB.VENDOR` (future) to support vendor specific SQL syntax and optimization
- `DB.DRIVER` Database driver (DBI compatible)
- `DB.DATABASE` Database name 
- `DB.HOST` Database host (defaults to `localhost`)
- `DB.PORT` Database port
- `DB.USERNAME` Database username or account
- `DB.PASSWORD` Database username or account password
- `DB.POOL.MINSIZE` Minimum connections in database pool (default is 1)
- `DB.POOL.MAXSIZE` Maximum connections in database pool (default is 25)
- `DB.POOL.IDLETIMEOUT` Idle duration in seconds until dropping idle connections beyond the pool's minimum number of connections

Note that the above configuration uses `cxapp::cxapp_config()` that supports both environmental variables and key vaults.

For further details on `DB.POOL.MINSIZE`, `DB.POOL.MAXSIZE` and `DB.POOL.IDLETIMEOUT`, see `pool::poolCreate(}`.

<br/>

##### Database Installation
The database install files are located in the `/db` directory in the root of the
`auditor.service` install directory or in the `inst/db` directory of the
`auditor.service` installation source file.

The database install file is provided as a SQL source file. 

The default database account is `auditorsvc`. If you want to use a different
database account, replace `auditorsvc` with the appropriate account name.

To ensure that the audit trail is immutable, i.e. read-only, ensure the account
is only granted permission to `SELECT` and `iNSERT` records for all auditor 
database tables.

<br/>

#### Serice Logs
The services relies on `cxapp::cxapp_log()`to log requests. 

The logging mechanism supports the following configuration options.

- `LOG.PATH`as the parent directory for log files
- `LOG.NAME` is the prefix log name
- `LOG.RORTATION` defines the period of log file rotation. Valid rotations are `YEAR`, `MONTH` and `DAY. The rotation period follows the format four digit year and two digit month and day.

See `cxapp::cxapp_log()` for additional details. 


