#!/bin/sh

# PURPOSE
#
# Provide templating function for flux manifest factorization.
# It will take a templated k8s resource yaml and replace variables with values from the cluster config map,
# then it will add the result to a file intended to be used as a k8s patch.
# The patch file will be created if it does not exist.

# USAGE
#
# ./update_radix_patch.sh "$manifest" "$patch"

# INPUTS:
#
# manifest             : Path to template yaml
# patch:               : Path to patch yaml. This file will be created if it does not exist yet.

# EXAMPLE:
#
# We want to transform the templated external-dns.yaml, and the result should be added to the file "radix-patch.yaml"
# ./update_radix_patch.sh ./third-party/external-dns.yaml ./radix-patch.yaml

# DEPENDENCIES
#
# Flux container shell sets the limitations for what unix tools that are available (ex no bash).
#
# Remember that the script is called from a flux factorization generator.
# This means it should not emit anything to standard output as flux will attempt to deploy any standard output as k8s objects.

# KNOWN ISSUES
#
# - Do NOT output anything to standard output
# - Do realize that you are working with SH, not BASH
# - Using EXIT will also stop the execution of any remaining commands in .flux.yaml

# DEVELOPMENT
#
# https://www.shellscript.sh/functions.html
#
# Emit errors to standard error (stderr), it will be picked up by the flux container log. 
# Example: 
# $ echo "Bad bobo in the jungle" >&2
# $ exit 1
# Be aware that using exit will also stop the execution of any remaining generators in .flux.yaml

# INPUTS:
#
# manifest             : Path to template yaml
# patch:               : Path to radixifed patch, in which this script will add its output. This file will be created if it does not exist yet.


#######################################################################################
### CONFIG & VALIDATE
### 

manifest="$1"
patch="$2"

# Validate input
if [ ! -f "$manifest" ]; then
   echo "[$(basename -- $0)] cannot find manifest: $manifest" >&2
   exit 1
fi
if [ -z "$patch" ]; then
   echo "[$(basename -- $0)] is missing input: \"patch\"" >&2
   exit 1
fi


#######################################################################################
### MAIN
### 

# Create the patch file if it does not exist
if [ ! -f "$patch" ]; then
   touch "$patch"
fi

# Read and store contents of cluster config as yaml
kubectl get cm "radix-platform-config" -o jsonpath='{.data.platform}' > tmp-cluster-config.yaml
# Transform cluster-config yaml to shell environment variables script
awk '{sub(/: /,"=")}1' tmp-cluster-config.yaml > tmp-cluster-config.env && chmod +x tmp-cluster-config.env
# Create heredoc that we will use as a cheapo template engine
(echo "#!/bin/sh"; echo ". ./tmp-cluster-config.env"; echo "cat <<EOF >>${patch}"; cat "$manifest"; echo ""; echo "EOF";)>tmp-heredoc.sh && chmod +x tmp-heredoc.sh
# Transform manifest using a heredoc to inject the env vars, and do so in a subshell to avoid polluting the main flux shell
$(./tmp-heredoc.sh)
wait
# Clean up tmp files
rm tmp-*
