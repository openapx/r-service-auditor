#! /bin/bash

#
# Deploy auditor service
#
#
#

# -- define some constants
APP_HOME=/opt/openapx/apps/auditor 


REPO_URL=https://cran.r-project.org


# -- iniitate install logs directory

mkdir -p /logs/openapx/auditor


# -- local vault

echo "-- local vault"

addgroup --system --quiet vaultuser

mkdir /.vault

chgrp vaultuser /.vault 
chmod g+rs,o-rwx /.vault




# -- auditor service account

echo "-- auditor service account"

adduser --system --group --shell /bin/bash --no-create-home --comment "auditor service user account" --quiet auditor

usermod -a -G vaultuser auditor




# -- initiate app home

echo "-- initiate application install directory"

mkdir -p ${APP_HOME}



# -- configure local R session

echo "-- app R session configurations"

mkdir -p ${APP_HOME}/library

DEFAULT_SITELIB=$(Rscript -e "cat( .Library.site, sep = .Platform\$path.sep )")

cat > ${APP_HOME}/.Renviron << EOF
R_LIBS_SITE=${APP_HOME}/library:${DEFAULT_SITELIB}
EOF


cat > ${APP_HOME}/.Rprofile << EOF

# -- CRAN repo

local( {
  options( "repos" = c( "CRAN" = "https://cloud.r-project.org") )
})

EOF





# -- service install source

echo "-- deploy R packages"

mkdir -p /sources/R-packages


# - cxapp

echo "   - downloading R package cxapp"

SOURCE_ASSET=$(curl -s -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/cxlib/r-package-cxapp/releases/latest )

SOURCE_URL=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^cxapp_\\d+.\\d+.\\d+.tar.gz$") ) | .browser_download_url' )
CXAPP_SOURCE=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^cxapp_\\d+.\\d+.\\d+.tar.gz$") ) | .name' )

curl -sL -o /sources/R-packages/${CXAPP_SOURCE} ${SOURCE_URL}


_MD5=($(md5sum /sources/R-packages/${CXAPP_SOURCE}))
_SHA256=($(sha256sum /sources/R-packages/${CXAPP_SOURCE}))

echo "      ${CXAPP_SOURCE}   (MD5 ${_MD5} / SHA-256 ${_SHA256})"

unset _MD5
unset _SHA256

unset SOURCE_URL
unset SOURCE_ASSET



# - auditor service

echo "   - downloading auditor service"

SOURCE_ASSET=$(curl -s -H "Accept: application/vnd.github+json" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/openapx/r-service-auditor/releases/latest )

SOURCE_URL=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^auditor.service_\\d+.\\d+.\\d+.tar.gz$") ) | .browser_download_url' )
AUDITOR_SOURCE=$( echo ${SOURCE_ASSET} | jq -r '.assets[] | select( .name | match( "^auditor.service_\\d+.\\d+.\\d+.tar.gz$") ) | .name' )

curl -sL -o /sources/R-packages/${AUDITOR_SOURCE} ${SOURCE_URL}


_MD5=($(md5sum /sources/R-packages/${AUDITOR_SOURCE}))
_SHA256=($(sha256sum /sources/R-packages/${AUDITOR_SOURCE}))

echo "      ${AUDITOR_SOURCE}   (MD5 ${_MD5} / SHA-256 ${_SHA256})"

unset _MD5
unset _SHA256

unset SOURCE_URL
unset SOURCE_ASSET



# - install dependencies and service

#   temporarily change workind directory to pick up environ and profile
CURRENT_WD=${pwd}

cd ${APP_HOME}

echo "   - install locations (first in list)"
Rscript -e "cat( c( paste0( \"   \", .libPaths()), \"   --\"), sep = \"\n\" )"

echo "   - install R package dependencies"
Rscript -e "install.packages( c( \"sodium\", \"openssl\", \"plumber\", \"jsonlite\", \"pool\", \"DBI\", \"digest\", \"uuid\", \"httr2\"), type = \"source\", destdir = \"/sources/R-packages\" )" >> /logs/openapx/auditor/install-r-packages.log 2>&1

echo "   - install R package cxapp"
Rscript -e "install.packages( \"/sources/R-packages/${CXAPP_SOURCE}\", type = \"source\", INSTALL_opts = \"--install-tests\" )" >> /logs/openapx/auditor/install-r-packages.log 2>&1

echo "   - install R package auditor service"
Rscript -e "install.packages( \"/sources/R-packages/${AUDITOR_SOURCE}\", type = \"source\", INSTALL_opts = \"--install-tests\" )" >> /logs/openapx/auditor/install-r-packages.log 2>&1

echo "   - install R packages for PostgreSQL"
Rscript -e "install.packages( \"RPostgreSQL\", type = \"source\", destdir = \"/sources/R-packages\" )" >> /logs/openapx/auditor/install-r-packages.log 2>&1

#   restore working directory
cd ${CURRENT_WD}



echo "   - R package install sources"

find /sources/R-packages -maxdepth 1 -type f -exec bash -c '_MD5=($(md5sum $1)); _SHA256=($(sha256sum $1)); echo "      $(basename $1)   (MD-5 ${_MD5} / SHA-256 ${_SHA256})"' _ {} \;

echo "   - (end of R package install sources)"





# -- local database 
#    note: postgres for now .. later probably something like SQLLite


echo "-- local database (PostgreSQL)"

# - start postgres 
service postgresql start


echo "   - set user postgres database password"

# - generate and set database password for postgres account
mkdir -p /.vault/dblocal/postgres
tr -dc A-Za-z0-9 </dev/urandom | head -c 30 > /.vault/dblocal/postgres/password

su postgres -c 'bash -s' << EOF
psql --quiet -c "ALTER USER postgres PASSWORD '$(cat /.vault/dblocal/postgres/password)';"
EOF




# -- set up example auditor database

echo "   - create auditor database"

# - pre-requisite: generate database account password secret
mkdir -p /.vault/dblocal/auditorsvc
tr -dc A-Za-z0-9 </dev/urandom | head -c 30 > /.vault/dblocal/auditorsvc/password


# - create database
su postgres -c 'bash -s' <<EOF
psql --quiet -c "CREATE DATABASE auditor WITH ENCODING=UTF8;"
psql --quiet -c "CREATE USER auditorsvc WITH ENCRYPTED PASSWORD '$(cat /.vault/dblocal/auditorsvc/password)';"
psql --quiet -d auditor -f /opt/openapx/apps/auditor/library/auditor.service/db/postgres.sql
EOF


echo "   - local database initiation completed"
service postgresql stop




echo "   - remove deployment profile"
rm -f ${APP_HOME}/.Rprofile


# -- Logging area

echo "-- set up logging area"
mkdir -p /data/auditor/logs

chgrp -R auditor /data/auditor
chmod -R g+rws /data/auditor



# -- application example configuration

echo "-- example application configuration"


cat <<\EOF > ${APP_HOME}/app.properties 

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
DB.PASSWORD = [vault] /dblocal/auditorsvc/password



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
API.AUTH.SECRETS = /example/auth/services/auditor/*

EOF





# -- clean-up

echo "-- clean-up"

rm -Rf /sources