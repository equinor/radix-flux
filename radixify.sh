#!/bin/sh

# PURPOSE
#
# Provide templating function for flux manifest factorization.
# It will take a templated yaml and replace variables with values from the cluster config map.

# USAGE
#
# source radixify.sh manifest

# DEPENDENCIES
#
# Flux container shell sets the limitations for what unix tools that are available (ex no bash).
#
# Remember that the script is called from a flux factorization generator.
# This means it should not emit anything to standard output as flux will attempt to deploy any standard output as k8s objects.

# KNOWN ISSUES
#
# Do NOT output anything to standard output.
# Do realize that you are working with SH, not BASH.
# An EXIT will also stop the execution of any remaining generators in .flux.yaml

# DEVELOPMENT
#
# https://www.shellscript.sh/functions.html
#
# Emit errors to standard error (stderr), it will be picked up by flux log. 
# Example: 
# $ echo "Bad bobo in the jungle" >&2
# $ exit 1
# Be aware that using exit will also stop the execution of any remaining generators in .flux.yaml

# INPUTS:
#
# manifest             : Path to template yaml


#######################################################################################
### CONFIG & VALIDATE
### 

manifest="$1"

# Validate input
if [ ! -f "$manifest" ]; then
   echo "radixify cannot find manifest: $manifest" >&2
   exit 1
fi


#######################################################################################
### MAIN
### 

# Read and store contents of cluster config as yaml
kubectl get cm "radix-platform-config" -o jsonpath='{.data.platform}' > tmp-cluster-config.yaml
# Transform cluster-config yaml to shell environment variables script
awk '{sub(/: /,"=")}1' tmp-cluster-config.yaml > tmp-cluster-config.env && chmod +x tmp-cluster-config.env
# Create heredoc that we will use as a cheapo template engine
(echo "#!/bin/sh"; echo ". ./tmp-cluster-config.env"; echo "cat <<EOF >tmp-result.yaml"; cat "$manifest"; echo ""; echo "EOF";)>tmp-heredoc.sh && chmod +x tmp-heredoc.sh
# Transform manifest using a heredoc to inject the env vars, and do so in a subshell to avoid polluting the main flux shell
$(./tmp-heredoc.sh && mv ./tmp-result.yaml "$manifest")
# Clean up tmp files
rm tmp-*
