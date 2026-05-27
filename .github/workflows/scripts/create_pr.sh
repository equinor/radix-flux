#!/usr/bin/env bash

# Documentation about this script can be found here:
# https://github.com/equinor/radix-private/blob/master/docs/radix-platform/flux.md
# Please update the documentation if any changes are made to this script.

MAX_RETRIES=3

function create-pr() {
    retry_nr=$1
    sleep_before_retry=$(($retry_nr * 2))
    date_stamp="$(date +%Y-%m-%d)"
    if [[ -z "${PR_BRANCH}" ]]; then
        PR_BRANCH="flux-image-updates"
    fi

    if [[ -z "${PR_NAME}" ]]; then
        if [[ -z "${ZONE}" && "${PR_BRANCH}" == flux-image-updates-* ]]; then
            ZONE=$(echo "${PR_BRANCH}" | sed -E 's/^flux-image-updates-([^-]+)-.*$/\1/')
        fi

        if [[ -z "${UPDATE_SCOPE}" && "${PR_BRANCH}" == flux-image-updates-* ]]; then
            UPDATE_SCOPE=$(echo "${PR_BRANCH}" | sed -E 's/^flux-image-updates-[^-]+-(.*)$/\1/')
        fi

        if [[ -n "${ZONE}" ]]; then
            if [[ -n "${UPDATE_SCOPE}" ]]; then
                PR_NAME="Automatic Pull Request - ${ZONE} - ${UPDATE_SCOPE} - ${date_stamp}"
            else
                PR_NAME="Automatic Pull Request - ${ZONE} - ${date_stamp}"
            fi
        else
            PR_NAME="Automatic Pull Request"
        fi
    fi

    if [[ -z "${PR_BODY}" ]]; then
        if [[ -n "${ZONE}" ]]; then
            if [[ -n "${UPDATE_SCOPE}" ]]; then
                PR_BODY=$'**Automatic Pull Request**\n\nZone: '${ZONE}$'\nScope: '${UPDATE_SCOPE}$'\nLast updated: '${date_stamp}
            else
                PR_BODY=$'**Automatic Pull Request**\n\nZone: '${ZONE}$'\nLast updated: '${date_stamp}
            fi
        else
            PR_BODY=$'**Automatic Pull Request**\n\nLast updated: '${date_stamp}
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
