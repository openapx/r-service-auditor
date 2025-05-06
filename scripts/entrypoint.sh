#! /bin/bash
#
# Container entrypoint for container services
#
#
#

# -- set APP_HOME
export APP_HOME=/opt/openapx/apps/auditor



# -- default service state

# - disable local database
SERVICE_LOCAL_DATABASE=disable

# - default number of worker sessions 
# - defaults to a single worker
SERVICE_WORKERS=1


# -- read serive.properties file ... if it exists

if [ -f ${APP_HOME}/service.properties ]; then

  OPT_VALUE=

  while IFS='=' read -r KEY VALUE; do


    # - translate periods to underscores
    KEY=$(echo "${KEY}" | tr '.' '_' | tr '[:lower:]' '[:upper:]' )

    # - values are lower case
    OPT_VALUE=$(echo "${VALUE}" | tr '[:upper:]' '[:lower:]')

    case ${KEY} in
      LOCAL_DATABASE)
         SERVICE_LOCAL_DATABASE=${OPT_VALUE}
      ;;
      WORKERS)
         SERVICE_WORKERS=${OPT_VALUE}
      ;;
      *)
      ;;
    esac


    OPT_VALUE=

 done <<< $(sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' ${APP_HOME}/service.properties)

fi

# -- local database configuration

if [ ${SERVICE_LOCAL_DATABASE} = "enable" ]; then

  # -- start postgreSQL
  service postgresql start

fi



# -- background services

cd ${APP_HOME}


# - worker configuration
#   note: should be dynamic at some point to find available ports

FIRST_PORT=7749
WORKER_PORTS=${FIRST_PORT}

NGINX_CONF=/etc/nginx/nginx.conf
NGINX_WORKER_CONFIG=

if [ ${SERVICE_WORKERS} -ge 1 ]; then

  for (( i = 1; i < ${SERVICE_WORKERS}; ++i )); do

    # -- define port
    ADD_PORT=$((FIRST_PORT + ${i} ))

    # -- add to workers
    WORKER_PORTS="${WORKER_PORTS} ${ADD_PORT}"

    # - check if port is in nginx config
    #
    CHK_CONFIG=$( grep "${ADD_PORT}" ${NGINX_CONF} | tr ';' ' ' | tr '\n' ' ' )

    if [ -z "${CHK_CONFIG}" ]; then
      # amend nginx config
      NGINX_WORKER_CONFIG="${NGINX_WORKER_CONFIG}    server 127.0.0.1:${ADD_PORT};\n"
    fi

    CHK_CONFIG=

  done

  # -- update nginx.conf with amended configuration
  if [ ! -z "${NGINX_WORKER_CONFIG}" ]; then
    sed -i "/# -- entrypoint: add additional worker ports --/a ${NGINX_WORKER_CONFIG}" ${NGINX_CONF}
  fi
fi


# -- launch one R sessions for each worker port
for R_SESSION_PORT in ${WORKER_PORTS}; do
  # - launch API
  su auditor -c bash -c "R --no-echo --no-restore --no-save -e \"auditor.service::start( port = ${R_SESSION_PORT} )\" &"
done



# -- foreground keep-alive service
nginx -g 'daemon off;'
