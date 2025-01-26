export CODER_URL=$CODER_AGENT_URL

coder templates push --yes "$1" \
    --directory "$1" \
    --name="$2" \
    --activate=true

