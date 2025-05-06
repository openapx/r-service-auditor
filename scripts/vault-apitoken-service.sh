#! /bin/bash
#
# Generate API token
#
#

# -- application home
APP_HOME=/opt/openapx/apps/auditor

TOKEN_SCOPE=service

TOKEN_PRINCIPAL=$1

if [ -z "${TOKEN_PRINCIPAL}" ]; then
  echo "Failed: Service name not specified"
  exit 1
fi



# -- generate clear text token
CLRTXT=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 40)

# -- encode token
ENCODEDTXT=$(cd ${APP_HOME}; Rscript -e "cat( cxapp:::.cxapp_apitokenencode(\"${CLRTXT}\"), sep = \"\" )")

# - generate secret
JSON="{ \"scope\": \"${TOKEN_SCOPE}\", \"principal\": \"${TOKEN_PRINCIPAL}\", \"value\": \"${ENCODEDTXT}\" }"

mkdir -p /.vault/api/auth/auditor/services


echo "${JSON}" > /.vault/api/auth/auditor/services/${TOKEN_PRINCIPAL}



# -- print clear text token

echo " "
echo "Token"
echo "----------------------------------------------------"
echo "${CLRTXT}"
echo " "