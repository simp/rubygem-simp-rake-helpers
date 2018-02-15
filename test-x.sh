echo
echo '==============================================='
rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n\n\n' --specfile x.spec --info -v
echo
echo ------------------- scripts:
rpm -q --specfile x.spec --scripts --triggers -v
echo '-----------------------------------------------'
echo

