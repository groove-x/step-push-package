#!/bin/bash

set -eu

export PACKAGECLOUD_TOKEN=${WERCKER_PUSH_PACKAGE_TOKEN}

install_jq () {
  command -v jq || apt-get install --yes jq
}

extract_repo_name () {
  parts=(${WERCKER_PUSH_PACKAGE_REPO_NAME//\// })
  USER_REPO=${parts[0]}/${parts[1]}
  DISTRO_VERSION=${parts[2]}/${parts[3]}
}

in_array() {
  local word=$1
  shift
  for e in "$@"; do
    if [[ "$e" == "$word" ]]; then
      return 0;
    fi
  done
  return 1;
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
  pkg_list=()
  for pkg in $(find ${WERCKER_PUSH_PACKAGE_PATH} -name "*${WERCKER_PUSH_PACKAGE_ARCH}.deb"); do
    pkg_filename=`basename ${pkg}`
    if ! in_array "${pkg_filename}" "${pkg_list[@]:-}"; then
      delete_old ${pkg}
      package_cloud push ${WERCKER_PUSH_PACKAGE_REPO_NAME} ${pkg}
    fi
    pkg_list+=($pkg_filename)
  done
}

main
