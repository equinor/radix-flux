#!/usr/bin/env bash

# Documentation about this script can be found here:
# https://github.com/equinor/radix-private/blob/master/docs/radix-platform/flux.md
# Please update the documentation if any changes are made to this script.

if [[ -z "${PR_BRANCH}" ]]; then
    PR_BRANCH="flux-image-updates"
fi

if [[ $(git fetch origin && git branch --remotes) == *"origin/${PR_BRANCH}"* ]]; then
    git switch "${PR_BRANCH}"
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
        --url '${{ secrets.SLACK_WEBHOOK }}'
        exit 0
    else
        curl --request POST \
        --header 'Content-type: application/json' \
        --data '{"text":"@omnia-radix Creating PR from '${GITHUB_REF_NAME}' to master failed. https://github.com/'${GITHUB_REPOSITORY}'/actions/runs/'${GITHUB_RUN_ID}'","link_names":1}' \
        --url ${SLACK_WEBHOOK_URL}
        exit 1
    fi
fi
