#!/bin/sh -e

if [ -z $1 ]; then
	echo "Pass Jenkins URL"
	exit 1
fi

JENKINS_URL=$1

for PLUGIN in git github rebuild parameterized-trigger copyartifact ssh-agent job-restrictions credentials-binding tap matrix-project config-file-provider; do
	echo "Installing $PLUGIN..."
	curl ${CURL_OPTS} --silent --header "Content-Type: application/xml" -XPOST "$JENKINS_URL/pluginManager/installNecessaryPlugins" --data "<install plugin=\"$PLUGIN@current\" />" >/dev/null
done

curl ${CURL_OPTS} -XPOST $JENKINS_URL/updateCenter/safeRestart

echo "Visit $JENKINS_URL/updateCenter and wait for Jenkins to restart."

