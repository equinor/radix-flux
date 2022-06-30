#!/usr/bin/env bash

# Documentation about this script can be found here:
# https://github.com/equinor/radix-private/blob/master/docs/radix-platform/flux.md
# Please update the documentation if any changes are made to this script.

MAX_RETRIES=3

function create-pr() {
    retry_nr=$1
    sleep_before_retry=$(($retry_nr * 2))
    if [[ -z "${PR_BRANCH}" ]]; then
        PR_BRANCH="flux-image-updates"
    fi

    if [[ $(git fetch origin && git branch --remotes) == *"origin/${PR_BRANCH}"* ]]; then
        git switch "${PR_BRANCH}"
        git pull
        PR_STATE=$(gh pr view ${PR_BRANCH} --json state --jq '.state')
    else
        PR_STATE="NONEXISTENT"
    fi

    if [[ "${PR_STATE}" != "OPEN" ]]; then
        echo "Create PR"
        PR_URL=$(gh pr create --title "Automatic Pull Request" --base master --body "**Automatic Pull Request**")
        if [[ ${PR_URL} ]]; then
            curl --request POST \
            --header 'Content-type: application/json' \
            --data '{"text":"@omnia-radix Please review PR '${PR_URL}'","link_names":1}' \
            --url ${SLACK_WEBHOOK_URL}
            exit 0
        elif [ "$retry_nr" -lt $MAX_RETRIES ]
        then
          sleep $sleep_before_retry
          create-pr $(($retry_nr+1))
        else
            curl --request POST \
            --header 'Content-type: application/json' \
            --data '{"text":"@omnia-radix Creating PR from '${GITHUB_REF_NAME}' to master failed. https://github.com/'${GITHUB_REPOSITORY}'/actions/runs/'${GITHUB_RUN_ID}'","link_names":1}' \
            --url ${SLACK_WEBHOOK_URL}
            exit 1
        fi
    fi
}

create-pr 0