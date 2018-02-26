#!/bin/bash


if [ $# -lt 3 ]; then
echo "Usage: $0 PACKAGE_NAME PACKAGE_VERSION SPEC_FILE"
  exit 1
fi

package_name=$1
package_version=$2
spec_file=$3

FAKE_RPM_SRC_DIR=${FAKE_RPM_SRC_DIR:-${PWD}/pkg}
FAKE_RPM_BUILD_DIR=${FAKE_RPM_BUILD_DIR:-${FAKE_RPM_SRC_DIR}/rpmbuild}



_dir=`dirname "${spec_file}"`
_tar="tar -zcv --exclude=.*.swp --exclude-backups --exclude-vcs-ignores -f ${FAKE_RPM_BUILD_DIR}/SOURCES/files.tar.gz"
_staging="$FAKE_RPM_SRC_DIR/staging"

rm -rf "${_staging}" "${FAKE_RPM_BUILD_DIR}"/{BUILDROOT,BUILD,SOURCES}/** &> /dev/null :
mkdir -p "${FAKE_RPM_BUILD_DIR}"/{BUILDROOT,BUILD,SOURCES}


source_dir="${_dir}/${package_name}"


if [ -d "${source_dir}" ]; then
  echo "ff"
else
  echo "-------------------- default"
  _name=`basename ${source_dir}`
  source_root="${FAKE_RPM_SRC_DIR}/default_files"
  source_dir="${source_root}/opt/test/code/${_name}"
  rm -rf "${source_root}"
  mkdir -p "${source_dir}"
  echo $_spec_file > "${source_dir}/${_name}.txt"
fi

pushd "${dir}" > /dev/null
$_tar "${source_dir}"
popd > /dev/null

  echo =================================
  echo =   building ${package_name}
  echo =================================
  #rpm -q -D "buildroot ${FAKE_RPM_BUILD_DIR}/BUILDROOT" -D "builddir ${FAKE_RPM_BUILD_DIR}/BUILD" -D "_sourcedir ${FAKE_RPM_BUILD_DIR}/SOURCES" -D "_rpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_srcrpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" -D "name ${package_name}" -D "version ${package_version}" --specfile "${spec_file}"
rpmbuild -D "buildroot ${FAKE_RPM_BUILD_DIR}/BUILDROOT" -D "builddir ${FAKE_RPM_BUILD_DIR}/BUILD" -D "_sourcedir ${FAKE_RPM_BUILD_DIR}/SOURCES" -D "_rpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_srcrpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" -bb -D "name ${package_name}" -D "version ${package_version}" "${spec_file}"
#  rpmbuild -D "buildroot ${FAKE_RPM_BUILD_DIR}/BUILDROOT" -D "builddir ${FAKE_RPM_BUILD_DIR}/BUILD" -D "_sourcedir ${FAKE_RPM_BUILD_DIR}/SOURCES" -D "_rpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_srcrpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" -vvvv $@

find "${FAKE_RPM_SRC_DIR}"


