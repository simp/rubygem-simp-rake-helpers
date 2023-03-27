#!/bin/sh

if [ "${PUPPERWARE_ANALYTICS_ENABLED}" != "true" ]; then
    # Don't print out any messages here since this is a CLI container
    exit 0
fi

# See: https://developers.google.com/analytics/devguides/collection/protocol/v1/parameters
# Tracking ID
tid=UA-132486246-5
# Application Name
an=r10k
# Application Version
av=$(r10k version | cut -d ' ' -f 2)
# Anonymous Client ID
_file=/var/tmp/pwclientid
cid=$(cat $_file 2>/dev/null || (cat /proc/sys/kernel/random/uuid | tee $_file))
# Event Category
ec=${PUPPERWARE_ANALYTICS_STREAM:-dev}
# Event Action
ea=start
# Anonymize ip
aip=1

_params="v=1&t=event&tid=${tid}&an=${an}&av=${av}&cid=${cid}&ec=${ec}&ea=${ea}&aip=${aip}"
_url="http://www.google-analytics.com/collect?${_params}"

# Don't print out any messages here since this is a CLI container
curl --fail --silent --show-error --output /dev/null \
    -X POST -H "Content-Length: 0" $_url
