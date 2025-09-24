curl -s -H "Authorization: token $GITHUB_TOKEN" -L "https://raw.githubusercontent.com/${USERNAME:-dg-cafe}/ROConAPI/${BRANCH:-main}/$GITHUB_FILE" -o "$GITHUB_FILE"
