#!/bin/sh

# PURPOSE
#
# This script is meant for patching kured template with Slack Webhook URL if the current cluster is the active cluster.
# Othwerwise kured will be deployed without Slack notification.

# USAGE
#
# ./patch-kured-if-active-cluster.sh "$radixOperatorPath" "$kuredPath" "$radixPatch"

# EXAMPLE
#
# ../patch-kured-if-active-cluster.sh "$PWD/radix-platform/radix-operator.yaml" "$PWD/third-party/kured.yaml" ./radix-patch.yaml

#######################################################################################
### CONFIG & VALIDATE
### 

radixOperatorPath="$1"
kuredPath="$2"
radixPatch="$3"

# Validate input
# if [ ! -f "$kuredPath" ]; then
#    echo "[$(basename -- $0)] cannot find kuredPath: $kuredPath" >&2
#    exit 1
# fi
if [ -z "$radixPatch" ]; then
   echo "[$(basename -- $0)] is missing input: \"patch\"" >&2
   exit 1
fi


#######################################################################################
### MAIN
### 

# Read and store contents of cluster config as yaml
kubectl get cm "radix-platform-config" -o jsonpath='{.data.platform}' > tmp-cluster-config.yaml

# Transform cluster-config yaml to shell environment variables script
awk '{sub(/: /,"=")}1' tmp-cluster-config.yaml > tmp-cluster-config.env && chmod +x tmp-cluster-config.env

# Make the variables available for the script
source ./tmp-cluster-config.env

# Are we in the active cluster? Use grep (if available) or similar tool to very brutish do a string search
result="$(grep "$clusterName" "$radixOperatorPath")"

if [[ -z "$result" ]]; then
   # Flux is not running in the active cluster
   # Found nothing, do nothing
   :
else
   # Flux is running in the active cluster
   # Add slackWebhookURL as a kured patch in "$radixOperatorPath/radix-patch.yaml"
   cat "$kuredPath" >> "$radixPatch"
   echo "      slack-hook-url: $slackWebhookURL" >> "$radixPatch"
fi

# Clean up tmp files
rm tmp-*