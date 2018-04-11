#!/bin/bash

set -e

export PACKAGECLOUD_TOKEN=${WERCKER_PUSH_PACKAGE_TOKEN}

install_jq () {
  command -v jq || apt-get install --yes jq
}

extract_repo_name () {
  parts=(${WERCKER_PUSH_PACKAGE_REPO_NAME//\// })
  USER_REPO=${parts[0]}/${parts[1]}
  DISTRO_VERSION=${parts[2]}/${parts[3]}
}

verify_not_duplicated() {
  version=`dpkg-deb -f ${1} Version`
  pkg_name=`dpkg-deb -f ${1} Package`
  arch=`dpkg-deb -f ${1} Architecture`

  endpoint="https://packagecloud.io/api/v1/repos/${USER_REPO}/package/deb/${DISTRO_VERSION}/${pkg_name}/${arch}/${version}.json"
  http_status=`curl -I -u ${PACKAGECLOUD_TOKEN}: ${endpoint} -o /dev/null -w '%{http_code}\n' -s`

  if [[ ${http_status} == "200" ]]; then
    echo "package already exists: ${1}"
    exit 1
  fi
}

delete_old () {
  version=`dpkg-deb -f ${1} Version`
  pkg_name=`dpkg-deb -f ${1} Package`
  arch=`dpkg-deb -f ${1} Architecture`
  base_version=`echo ${version} | cut -d '-' -f 1`

  endpoint="https://packagecloud.io/api/v1/repos/${USER_REPO}/package/deb/${DISTRO_VERSION}/${pkg_name}/${arch}/versions.json"
  res=`curl -u ${PACKAGECLOUD_TOKEN}: ${endpoint}`

  old_vers_len=(`echo ${res} | jq "length"`)
  if [ $old_vers_len -eq 0 ]; then
      return
  fi

  old_vers=(`echo ${res} | jq -r ".[].version"`)
  destroy_urls=(`echo ${res} | jq -r ".[].destroy_url"`)

  for idx in ${!old_vers[@]}
  do
   if [[ ${old_vers[idx]} == ${base_version} ]]
   then
     echo destroy: https://packagecloud.io${destroy_urls[idx]}
     curl -u ${PACKAGECLOUD_TOKEN}: -X DELETE https://packagecloud.io${destroy_urls[idx]}
   fi
  done
}

main () {
  install_jq
  extract_repo_name
  for pkg in $(find ${WERCKER_PUSH_PACKAGE_PATH} -name "*${WERCKER_PUSH_PACKAGE_ARCH}.deb"); do
    verify_not_duplicated ${pkg}
    delete_old ${pkg}
    package_cloud push ${WERCKER_PUSH_PACKAGE_REPO_NAME} ${pkg}
  done
}

main
