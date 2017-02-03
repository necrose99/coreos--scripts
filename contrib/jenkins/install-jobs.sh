#!/bin/sh -e

if [ -z $1 ]; then
	echo "Pass Jenkins URL"
	exit 1
fi

JENKINS_URL=$1

for JOB in $(find jobs/ -mindepth 1 -maxdepth 1 -type d); do
	J=$(basename $JOB)
	echo "Creating job $J..."
	curl ${CURL_OPTS} --silent --header "Content-Type: application/xml" -XPOST "$JENKINS_URL/createItem?name=$J" --data-binary "@$JOB/config.xml" >/dev/null
done
