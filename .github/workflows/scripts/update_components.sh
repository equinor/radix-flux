#!/usr/bin/env bash

# Documentation about this script can be found here:
# https://github.com/equinor/radix-private/blob/master/docs/radix-platform/flux.md
# Please update the documentation if any changes are made to this script.

if [[ -z "${PR_BRANCH}" ]]; then
    PR_BRANCH="flux-image-updates"
fi

if [[ -z "${SOURCE_CLUSTER}" ]]; then
    SOURCE_CLUSTER="development"
fi

if [[ -z "${DESTINATION_CLUSTER}" ]]; then
    DESTINATION_CLUSTER="development"
fi

numberOfChanges=0

function get_version() {
    local push=false
    git config --global user.name 'Automatic Update'
    git config --global user.email 'radix@statoilsrm.onmicrosoft.com'
    git fetch
    git checkout -t "origin/${PR_BRANCH}" -b "${PR_BRANCH}" || git checkout -b "${PR_BRANCH}"

    while read -r entry; do
        local file=$(echo ${entry} | awk '{split($1,a,":"); print a[1]}')
        local line=$(echo ${entry} | awk '{split($1,a,":"); print a[2]}')
        local current=$(echo ${entry} | awk '{print $3}')
        local repo=$(echo ${entry} | grep -Eo 'https://[^ >]+' | sed 's/\/releases.*$//' | awk '{n=split($1,a,"/"); print a[n-1]"/"a[n]}')
        local package_name=${repo##*/}

        if [[ "${current}" ]]; then
            if [[ "${SOURCE_CLUSTER}" == "${DESTINATION_CLUSTER}" ]]; then
                # Get version from ArtifactHub
                newest=$(curl "https://artifacthub.io/api/v1/packages/helm/${repo}" \
                    --request "GET" \
                    --header "accept: application/json" \
                    --silent |
                    jq -er '.version // empty' ||
                    # Try GitHub
                    curl "https://api.github.com/repos/${repo}/tags" \
                    --request "GET" \
                    --header "Accept: application/vnd.github.v3+json" \
                    --silent |
                    jq -er '.[0].name // empty') || { echo "Version for $package_name not found. $current"; continue; }
                    #--header "Authorization: token ${GITHUB_TOKEN}" \
            else
                # Update versions in destination cluster with versions in source cluster
                newest="${current}"
                file=$(echo ${file} | sed 's/'${SOURCE_CLUSTER}'/'${DESTINATION_CLUSTER}'/')
                if [[ -f "${file}" ]]; then
                    current=$(grep "${repo}" "${file}" | awk '{print $2}')
                fi
            fi

            # Compare versions
            if [[ "${current}" && "${newest}" && "${current}" != "${newest}" ]]; then
                # Update file, create branch and commit change
                printf "New version for %s available: %s -> %s\n" "${package_name}" "${current}" "${newest}"
                find="$(echo ${entry} | awk '{print $2}') ${current}"
                replace="$(echo ${entry} | awk '{print $2}') ${newest}"
                sed -i "s/${find}/${replace}/" "${file}"
                git add "${file}"
                git commit -m "Update ${package_name} from ${current} to ${newest}"
                push=true
            else
                printf "No new version available for %s - Current %s\n" "${package_name}" "${current}"
            fi
        else
            printf "Could not find package version locally."
            
        fi
    done < <(grep -rn -E 'artifacthub.io|github.com' ${GITHUB_WORKSPACE}'/clusters/'${SOURCE_CLUSTER} --exclude-dir 'flux-system' | grep -v -e "tag:")

    if [[ "${push}" == true ]]; then
        echo "push"
        git push --set-upstream origin "${PR_BRANCH}"
        numberOfChanges=$((numberOfChanges + 1))
    fi
}

get_version
if [[ -n $CI ]]; then
    echo "numberOfChanges=$numberOfChanges" >> $GITHUB_OUTPUT
fi
