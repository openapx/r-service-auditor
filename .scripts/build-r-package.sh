#! /bin/bash

#
# Build R package for release
#
#
#

# -- identify commiit
echo "Processing commit ${GITHUB_SHA}"


# -- identify reference
echo "Reference ${GITHUB_REF}"


# -- release version
RELEASE_VERSION=$( echo ${GITHUB_REF_NAME} | tr -d v )



# -- scaffolding

if [ ! -d /assets ]; then 
echo "Assests directory does not exist"
exit 0
fi


# -- update package DESCRIPTION

# package version
sed -i "s/Version: .*/Version: ${RELEASE_VERSION}/" /src/DESCRIPTION



# -- establish build area
mkdir -p /build
cd /build

# -- build package
R CMD build /src


# -- stage build artifacts to /assets
cp /build/*_${RELEASE_VERSION}.tar.gz /assets
