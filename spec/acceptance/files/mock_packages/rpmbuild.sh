spec_file=$1

FAKE_RPM_SRC_DIR=${FAKE_RPM_SRC_DIR:-${PWD}/pkg}
FAKE_RPM_BUILD_DIR=${FAKE_RPM_BUILD_DIR:-${FAKE_RPM_SRC_DIR}/rpmbuild}

# clean up old builds
rm -rf "${FAKE_RPM_BUILD_DIR}"/{BUILDROOT,BUILD,SOURCES}/** &> /dev/null :
mkdir -p "${FAKE_RPM_BUILD_DIR}"/{BUILDROOT,BUILD,SOURCES}


# if there is a directory with the same name as the spec file, build a tar ball
# from it and stage it under SOURCES
source_dir=`echo ${spec_file}| sed -e 's/.spec$//'`
if [ -d "${source_dir}" ]; then
  echo "Found a directory named '${source_dir}'; building tarball"
  pushd "${source_dir}" > /dev/null
  tar -zcv --exclude=.*.swp  -f "${FAKE_RPM_BUILD_DIR}/SOURCES/files.tar.gz" *
  popd > /dev/null
else
  echo "NOTE: no source directory ar '${source_dir}'"
fi


# rpmbuild
rpmbuild -D "buildroot ${FAKE_RPM_BUILD_DIR}/BUILDROOT" -D "builddir ${FAKE_RPM_BUILD_DIR}/BUILD" -D "_sourcedir ${FAKE_RPM_BUILD_DIR}/SOURCES" -D "_rpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_srcrpmdir ${FAKE_RPM_SRC_DIR}/dist" -D "_build_name_fmt %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" -ba $@ "${spec_file}"
