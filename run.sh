#!/bin/bash

set -e

for pkg in $(find ${WERCKER_PUSH_PACKAGE_PATH} -name "*.deb"); do
  package_cloud yank ${WERCKER_PUSH_PACKAGE_REPO_NAME} $(basename ${pkg}) || true
  package_cloud push ${WERCKER_PUSH_PACKAGE_REPO_NAME} ${pkg}  
done
