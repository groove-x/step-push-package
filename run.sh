#!/bin/bash

set -e

export PACKAGECLOUD_TOKEN=${WERCKER_PUSH_PACKAGE_TOKEN}
for pkg in $(find ${WERCKER_PUSH_PACKAGE_PATH} -name "*.deb"); do
  package_cloud yank ${WERCKER_PUSH_PACKAGE_REPO_NAME} $(basename ${pkg}) || true
  package_cloud push ${WERCKER_PUSH_PACKAGE_REPO_NAME} ${pkg}  
done
