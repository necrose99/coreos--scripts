#!/bin/sh -e
#
# Backup jenkins job configs to a directory.
#
# Usage: CURL_OPTS='' backup jenkins_url [directory]
#

if [ -z $1 ]; then
	echo "Pass Jenkins URL"
	exit 1
fi

JENKINS_URL=$1
out=$2

: ${out:="jobs"}

xml=$(curl ${CURL_OPTS} --silent --header "Content-Type: application/xml" \
	-XPOST "${JENKINS_URL}/api/xml?tree=jobs\[name\]")

names=$(echo ${xml} | grep --perl-regexp --only-matching '(?<=<name>).*?(?=</name>)' || true)

if [ -z "${names}" ]; then
	echo "No jobs found."
	exit 1
fi


for n in ${names}; do
	echo "saving job ${n} to ${out}/${n}/config.xml"
	mkdir -p ${out}/${n}
	curl ${CURL_OPTS} --silent ${JENKINS_URL}/job/${n}/config.xml > ${out}/${n}/config.xml
done
