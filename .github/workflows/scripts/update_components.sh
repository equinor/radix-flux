#!/usr/bin/env bash

# Documentation about this script can be found here:
# https://github.com/equinor/radix-private/blob/master/docs/radix-platform/flux.md
# Please update the documentation if any changes are made to this script.

if [[ -z "${PR_BRANCH}" ]]; then
    if [[ -n "${ZONE}" ]]; then
        PR_BRANCH="automatic-3party-update-${ZONE}"
    else
        PR_BRANCH="automatic-3party-update-dev"
    fi
fi

if [[ -z "${ZONE}" ]]; then
    ZONE="dev"
fi

if [[ -z "${CLUSTER}" ]]; then
    case "${ZONE}" in
    c2)
        CLUSTER="c2-production"
        ;;
    c3)
        CLUSTER="c3"
        ;;
    dev)
        CLUSTER="development"
        ;;
    monitor)
        CLUSTER="monitoring"
        ;;
    playground)
        CLUSTER="playground"
        ;;
    platform)
        CLUSTER="production"
        ;;
    *)
        echo "Unsupported zone '${ZONE}'. Expected one of: c2, c3, dev, monitor, playground, platform"
        exit 1
        ;;
    esac
fi

cluster_infrastructure_path="${GITHUB_WORKSPACE}/clusters/${CLUSTER}/infrastructure"
if [[ ! -d "${cluster_infrastructure_path}" ]]; then
    echo "Cluster infrastructure path not found: ${cluster_infrastructure_path}"
    exit 1
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
            # Get version from ArtifactHub, then fallback to latest GitHub tag.
            newest=$(curl "https://artifacthub.io/api/v1/packages/helm/${repo}" \
                --request "GET" \
                --header "accept: application/json" \
                --silent |
                jq -er '.version // empty' ||
                curl "https://api.github.com/repos/${repo}/tags" \
                    --request "GET" \
                    --header "Accept: application/vnd.github.v3+json" \
                    --silent |
                jq -er '.[0].name // empty') || {
                echo "Version for $package_name not found. $current"
                continue
            }
            #--header "Authorization: token ${GITHUB_TOKEN}" \

            if [[ "${newest}" == *beta* || "${newest}" == *alpha* || "${newest}" == *rc*  ]]; then 
                printf "Skipping %s for %s - Current %s\n" "${newest}" "${package_name}" "${current}"
                continue
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
    done < <(grep -rn -E 'artifacthub.io|github.com' "${cluster_infrastructure_path}" | grep -v -e "tag:")

    if [[ "${push}" == true ]]; then
        echo "push"
        git push --set-upstream origin "${PR_BRANCH}"
        numberOfChanges=$((numberOfChanges + 1))
    fi
}

get_version
if [[ -n $CI ]]; then
    echo "numberOfChanges=$numberOfChanges" >>$GITHUB_OUTPUT
fi
