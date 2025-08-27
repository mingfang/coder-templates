coder list -o json \
| jq -r ".[] |  select(.name!=\"$CODER_WORKSPACE_NAME\" and .outdated==true) | .name" \
| xargs -r -n 1 bash -c 'echo $0; coder update $0; coder stop $0 -y'