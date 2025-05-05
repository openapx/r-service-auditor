#! /bin/bash

#
# Container entrypoint for container services
#
#
#

# -- set APP_HOME
export APP_HOME=/opt/openapx/apps/auditor


# -- start postgreSQL
service postgresql start


# -- background services

cd ${APP_HOME}

# - API
su auditor -c bash -c 'R --no-echo --no-restore --no-save -e "auditor.service::start( port = 7749 )" &'


# -- foreground keep-alive service
nginx -g 'daemon off;'
