#!/usr/bin/env bash

# Documentation about this script can be found here:
# https://github.com/equinor/radix-private/blob/master/docs/radix-platform/flux.md
# Please update the documentation if any changes are made to this script.

MAX_RETRIES=3

function create-pr() {
    retry_nr=$1
    sleep_before_retry=$(($retry_nr * 2))
    if [[ -z "${PR_BRANCH}" ]]; then
        if [[ -n "${GITHUB_REF_NAME}" ]]; then
            PR_BRANCH="${GITHUB_REF_NAME}"
        elif [[ -n "${ZONE}" ]]; then
            PR_BRANCH="automatic-3party-update-${ZONE}"
        else
            PR_BRANCH="automatic-3party-update-dev"
        fi
    fi

    if [[ -z "${PR_NAME}" ]]; then
        if [[ -z "${ZONE}" && "${PR_BRANCH}" == flux-image-updates-* ]]; then
            ZONE=$(echo "${PR_BRANCH}" | sed -E 's/^flux-image-updates-([^-]+)-.*$/\1/')
        fi

        if [[ -z "${ZONE}" && "${PR_BRANCH}" == automatic-3party-update-* ]]; then
            ZONE=$(echo "${PR_BRANCH}" | sed -E 's/^automatic-3party-update-([^-]+).*$/\1/')
        fi

        if [[ -z "${UPDATE_SCOPE}" && "${PR_BRANCH}" == flux-image-updates-* ]]; then
            UPDATE_SCOPE=$(echo "${PR_BRANCH}" | sed -E 's/^flux-image-updates-[^-]+-(.*)$/\1/')
        fi

        if [[ "${PR_BRANCH}" == flux-image-updates-* ]]; then
            if [[ -n "${ZONE}" ]]; then
                if [[ "${UPDATE_SCOPE}" == "third-party" ]]; then
                    PR_NAME="Flux Image Pull Request - ${ZONE}(flux-policy)"
                elif [[ "${UPDATE_SCOPE}" == "radix-components" ]]; then
                    PR_NAME="Flux Image Pull Request - ${ZONE}(radix)"
                else
                    PR_NAME="Flux Image Pull Request - ${ZONE}"
                fi
            else
                PR_NAME="Flux Image Pull Request"
            fi
        elif [[ "${PR_BRANCH}" == automatic-3party-update-* ]]; then
            if [[ -n "${ZONE}" ]]; then
                PR_NAME="Automatic Pull Request - ${ZONE}(3party)"
            else
                PR_NAME="Automatic Pull Request"
            fi
        else
            if [[ -n "${ZONE}" ]]; then
                PR_NAME="Automatic Pull Request - ${ZONE}"
            else
                PR_NAME="Automatic Pull Request"
            fi
        fi
    fi

    if [[ -z "${PR_BODY}" ]]; then
        if [[ -n "${ZONE}" ]]; then
            if [[ -n "${UPDATE_SCOPE}" ]]; then
                printf -v PR_BODY '**Automatic Pull Request**\n\nZone: %s\nScope: %s' "${ZONE}" "${UPDATE_SCOPE}"
            else
                printf -v PR_BODY '**Automatic Pull Request**\n\nZone: %s' "${ZONE}"
            fi
        else
            PR_BODY='**Automatic Pull Request**'
        fi
    fi

    if [[ $(git fetch origin && git branch --remotes) == *"origin/${PR_BRANCH}"* ]]; then
        git switch "${PR_BRANCH}"
        git pull
        PR_STATE=$(gh pr view ${PR_BRANCH} --json state --jq '.state')
        if [[ "${PR_STATE}" == "OPEN" ]]; then
            gh pr edit ${PR_BRANCH} --title "${PR_NAME}" --body "${PR_BODY}" >/dev/null
        fi
    else
        PR_STATE="NONEXISTENT"
    fi

    if [[ "${PR_STATE}" != "OPEN" ]]; then
        echo "Create PR"
        PR_URL=$(gh pr create --title "${PR_NAME}" --base master --body "${PR_BODY}")
        if [[ ${PR_URL} ]]; then
            curl --request POST \
                --header 'Content-type: application/json' \
                --data '{"text":"@omnia-radix Please review PR '${PR_URL}'","link_names":1}' \
                --url ${SLACK_WEBHOOK_URL} \
                --fail
            return
        elif [ "$retry_nr" -lt $MAX_RETRIES ]; then
            sleep $sleep_before_retry
            create-pr $(($retry_nr + 1))
        else
            curl --request POST \
                --header 'Content-type: application/json' \
                --data '{"text":"@omnia-radix Creating PR from '${GITHUB_REF_NAME}' to master failed. https://github.com/'${GITHUB_REPOSITORY}'/actions/runs/'${GITHUB_RUN_ID}'","link_names":1}' \
                --url ${SLACK_WEBHOOK_URL}
            return 1
        fi
    fi
}

create-pr 0
