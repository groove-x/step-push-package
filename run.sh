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

delete_old () {
  pkg_filename=`basename -- ${1}`
  pkg_version=`dpkg-deb -f ${1} Version`
  pkg_name=`dpkg-deb -f ${1} Package`
  pkg_arch=`dpkg-deb -f ${1} Architecture`
  pkg_base_version=`echo ${pkg_version} | cut -d '-' -f 1`

  endpoint="https://packagecloud.io/api/v1/repos/${USER_REPO}/package/deb/${DISTRO_VERSION}/${pkg_name}/${pkg_arch}/versions.json"
  res=`curl -u ${PACKAGECLOUD_TOKEN}: ${endpoint} -s`

  res_length=(`echo ${res} | jq "length"`)
  if [ $res_length -eq 0 ]; then
      return
  fi

  versions=(`echo ${res} | jq -r ".[].version"`)
  filenames=(`echo ${res} | jq -r ".[].filename"`)
  destroy_urls=(`echo ${res} | jq -r ".[].destroy_url"`)

  for idx in ${!versions[@]}
  do
    if [[ ${versions[idx]} == ${pkg_base_version} && ${filenames[idx]} != ${pkg_filename} ]]
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
    package_cloud push ${WERCKER_PUSH_PACKAGE_REPO_NAME} ${pkg}
    if [[ "${WERCKER_PUSH_PACKAGE_DELETE_OLD}" != "false" ]]; then
      delete_old ${pkg}
    fi
  done
}

main
