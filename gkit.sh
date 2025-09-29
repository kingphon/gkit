#!/bin/bash
#
# Helper script for Git and GitHub workflows.
#
# Usage:
#   source ./gh_helpers.sh               # To load functions into your shell
#   ./gh_helpers.sh <command> [args...]  # To execute a command
#
# Shareable via curl:
#   curl -sSL <raw_github_url> | bash -s <command> [args...]
#
# Dependencies:
#   - gh: The GitHub CLI (https://cli.github.com/)
#   - fzf: A command-line fuzzy finder (https://github.com/junegunn/fzf)
#   - jq: A lightweight and flexible command-line JSON processor (https://stedolan.github.io/jq/)
#
# Configuration (via environment variables):
#   - SLACK_TOKEN: Your Slack API token (e.g., 'xoxb-...')
#   - PR_ROOM: The Slack channel ID to send notifications to (e.g., 'C09E15YGCES')
#   - DINH_SLACK_ID, PHUONG_SLACK_ID, VINH_SLACK_ID, THY_SLACK_ID: Slack member IDs for mentions.
#

set -e
export DINH_SLACK_ID="U08TVVC6PL5"
export PHUONG_SLACK_ID="U08UAPSK14H"
export VINH_SLACK_ID="U08TR09LSEP"
export THY_SLACK_ID="U08TS1P3JMC"
export SLACK_TOKEN=xoxb-8934931706583-9181274909602-ohoQYRKnL61ZHatMyMEfwThd
export PR_ROOM="C09E15YGCES"

# --- Configuration & Dependency Checks ---
check_deps() {
    local missing=0
    command -v gh >/dev/null 2>&1 || { echo "❌ 'gh' (GitHub CLI) not found. Please install it." >&2; missing=1; }
    command -v fzf >/dev/null 2>&1 || { echo "❌ 'fzf' not found. Please install it." >&2; missing=1; }
    command -v jq >/dev/null 2>&1 || { echo "❌ 'jq' not found. Please install it." >&2; missing=1; }
    
    if [ -n "$SLACK_TOKEN" ]; then
        [[ -z "$PR_ROOM" ]] && { echo "⚠️ PR_ROOM is not set. Slack messages will not be sent." >&2; }
    fi

    if [ "$missing" -eq 1 ]; then
        exit 1
    fi
}


# Display help message
ghh_help() {
  echo "Git & GitHub Helper Scripts"
  echo ""
  echo "Usage: $0 <command> [arguments...]"
  echo ""
  echo "Commands:"
  echo "  prs [remote] [title]        Create a PR to the latest release branch."
  echo "  pr <base> [title]           Create a PR to a specific base branch."
  echo "  nb <branch> [from] [remote] Create a new branch from 'develop' (or [from])."
  echo "  nbs <branch> [remote]       Create a new branch from the latest release branch."
  echo "  nbh <branch> [from] [remote] Create a new branch from 'main' (or [from])."
  echo "  approve <pr_url>            Approve a GitHub PR."
  echo "  merge <pr_url>              Approve and merge a GitHub PR."
  echo "  wf <pr_url>                 Interactively trigger a GitHub Action workflow for a PR."
  echo "  slack <message>             Send a message to a Slack channel."
  echo "  help, -h, --help            Show this help message."
  echo ""
  echo "Note: For Slack integration, ensure SLACK_TOKEN and PR_ROOM are set in your environment."
}

# Send a message to Slack
ghh_slack() {
  if [[ -z "$SLACK_TOKEN" ]]; then
    echo "❌ SLACK_TOKEN not set. Cannot send notification." >&2
    return 1
  fi

  if [[ $# -lt 1 ]]; then
    echo "Usage: ghh_slack <message>" >&2
    return 1
  fi

  echo "Sending message to $PR_ROOM: $*"

  local channel="${PR_ROOM}"
  local message="$*"

  local response
  response=$(curl -s -X POST https://slack.com/api/chat.postMessage \
    -H "Authorization: Bearer $SLACK_TOKEN" \
    -H "Content-type: application/json" \
    --data "{\"channel\":\"$channel\",\"text\":\"$message\"}")

  if [[ "$(jq -r '.ok' <<<"$response")" == "true" ]]; then
    echo "✅ Sent to $channel: $message"
  else
    echo "❌ Error sending to Slack: $(jq -r '.error' <<<"$response")" >&2
  fi
}

# Create pull request to the latest release branch
ghh_prs() {
  echo "ghh_prs $1 $2"
  echo "🔥 Start to create pull request"
  local remote="${1:-origin}"
  local title="$2"

  git fetch "$remote" || return 1
  latest_release=$(git branch -r | grep 'origin/release/v' | sed 's|origin/release/v||' | sort -V | tail -n1 | awk '{$1=$1;print}')
  if [ -z "$latest_release" ]; then
    echo "No release branch found"
    return 1
  fi
  echo "Latest release: $latest_release"
  echo "Create pull request with title: $title"
  ghh_pr "release/v$latest_release" "$title"
  echo "✅ $1 Pull request created"
}

# Create a pull request
ghh_pr() {
  echo "ghh_pr $1 $2"
  echo "🔥 Start to create pull request"
  local base=${1:-release}
  local title="$2"
  local pr_url

  if [[ -n "$title" ]]; then
    echo "🔥 Create pull request with title: $title"
    pr_url=$(gh pr create --base "$base" --title "$title")
  else
    echo "🔥 Create pull request with fill"
    pr_url=$(gh pr create --base "$base" --fill)
  fi

  if [[ -n "$pr_url" ]]; then
    echo "✅ Pull request created: $pr_url 🎉"
    if [[ -z "$SLACK_TOKEN" || -z "$PR_ROOM" ]]; then
        echo "⚠️ SLACK_TOKEN or PR_ROOM not set. Skipping Slack notification."
        return 0
    fi

    local current_branch
    current_branch=$(git branch --show-current)
    local author
    author=$(git config user.name)
    local pr_number
    pr_number=$(echo "$pr_url" | grep -o '[0-9]\+$')
    local repo_name
    repo_name=$(basename "$(git rev-parse --show-toplevel)")
    
    local slack_users=(
      "DINH:$DINH_SLACK_ID"
      "PHUONG:$PHUONG_SLACK_ID"
      "VINH:$VINH_SLACK_ID"
      "THY:$THY_SLACK_ID"
      "NONE:"
    )
    
    local selected_user
    selected_user=$(printf '%s\n' "${slack_users[@]}" | fzf --prompt="Select user to mention: " --height=7 --reverse --border)
    
    if [[ -n "$selected_user" && "$selected_user" != "NONE:" ]]; then
      local user_id="${selected_user#*:}"
      ghh_slack "🚀 Pull request <$pr_url|$pr_number> created by *$author* in *$repo_name* \n> Branch: \`$current_branch\` to: \`$base\` <@$user_id>"
    else
      ghh_slack "🚀 Pull request <$pr_url|$pr_number> created by *$author* in *$repo_name* \n> Branch: \`$current_branch\` to: \`$base\`"
    fi
  else
    echo "❌ Failed to create pull request." >&2
    return 1
  fi
}


# Create new branch
ghh_nb() {
  echo "ghh_nb $1 $2 $3"
  echo "🔥 Start to create new branch"
  git fetch "${3:-origin}" && git checkout -b "$1" "${3:-origin}/${2:-develop}" && git push -u "${3:-origin}" "$1"
  echo "✅ $1 New branch created from develop 🎉"
}

# Create new branch from staging
ghh_nbs() {
  echo "ghh_nbs $1 $2"
  echo "🔥 Start to create new branch from staging"
  local remote="${2:-origin}"
  latest_release=$(git branch -r | grep 'origin/release/v' | sed 's|origin/release/v||' | sort -V | tail -n1 | awk '{$1=$1;print}')
  echo "Latest release: $latest_release"

  git fetch "$remote" || return 1
  echo "Fetch remote: $remote"
  ghh_nb "$1" "release/v$latest_release" "$remote"
  echo "✅ $1 Branch created from staging 🎉"
}

# Create new hotfix branch
ghh_nbh() {
  echo "ghh_nbh $1 $2 $3"
  echo "🔥 Start to create new branch"
  git fetch "${3:-origin}" && git checkout -b "$1" "${3:-origin}/${2:-main}" && git push -u "${3:-origin}" "$1"
  echo "✅ $1 New branch hotfix created 🎉"
}

# Approve a PR
ghh_approve() {
  url=$1
  echo "🔥 Approving PR: $url"

  pr_number=$(echo "$url" | awk -F/ '{print $7}')
  repo=$(echo "$url" | awk -F/ '{print $4 "/" $5}')

  gh pr review "$pr_number" --approve --repo "$repo"
  echo "✅ PR for $url approved 🎉"
}

# Approve and merge a PR
ghh_merge() {
  url=$1
  echo "🔥 Approving PR: $url"

  pr_number=$(echo "$url" | awk -F/ '{print $7}')
  repo=$(echo "$url" | awk -F/ '{print $4 "/" $5}')

  gh pr review "$pr_number" --approve --repo "$repo"
  gh pr merge "$pr_number" --repo "$repo"
  echo "✅ PR for $url approved and merged 🎉"
}

# List and trigger a workflow for a PR
ghh_wf() {
  url=$1

  if [ -z "$url" ]; then
    echo "Usage: ghh_wf <github_pr_url>" >&2
    return 1
  fi

  owner=$(echo "$url" | awk -F/ '{print $4}')
  repo=$(echo "$url" | awk -F/ '{print $5}')
  pr_number=$(echo "$url" | awk -F/ '{print $7}')

  if [ -z "$owner" ] || [ -z "$repo" ] || [ -z "$pr_number" ]; then
    echo "❌ Invalid GitHub PR URL provided." >&2
    return 1
  fi

  echo "owner: $owner"
  echo "repo: $repo"
  echo "pr_number: $pr_number"

  branch=$(gh pr view "$pr_number" --repo "$owner/$repo" --json headRefName --jq '.headRefName')
  if [[ -z "$branch" ]]; then
    echo "❌ Could not determine branch for PR #$pr_number. Is the PR valid and do you have access?" >&2
    return 1
  fi

  echo "🔍 Checking workflows on branch '$branch' of '$owner/$repo'..."

  workflows=$(gh api "repos/$owner/$repo/contents/.github/workflows?ref=$branch" --jq '.[].name' 2>/dev/null)

  if [[ -z "$workflows" ]]; then
      echo "❌ No workflows found on branch '$branch'" >&2
      return 1
  fi

  workflow_to_run=$(echo "$workflows" | fzf --prompt="Please select a workflow to trigger > " --height=40% --layout=reverse)

  if [[ -n "$workflow_to_run" ]]; then
      echo "🚀 Triggering workflow '$workflow_to_run' on branch '$branch'..."
      gh workflow run "$workflow_to_run" --ref "$branch" --repo "$owner/$repo"
  else
      echo "No workflow selected. Aborting."
  fi
}


# --- Main Command Router ---
main() {
    # Check dependencies first
    check_deps

    # If no command is provided, show help and exit.
    if [ -z "$1" ]; then
        ghh_help
        exit 0
    fi

    COMMAND=$1
    shift # Remove command from arguments, leaving only the parameters

    case "$COMMAND" in
        prs)
            ghh_prs "$@"
            ;;
        pr)
            ghh_pr "$@"
            ;;
        slack)
            ghh_slack "$@"
            ;;
        nb)
            ghh_nb "$@"
            ;;
        nbs)
            ghh_nbs "$@"
            ;;
        nbh)
            ghh_nbh "$@"
            ;;
        approve)
            ghh_approve "$@"
            ;;
        merge)
            ghh_merge "$@"
            ;;
        wf)
            ghh_wf "$@"
            ;;
        help|-h|--help)
            ghh_help
            ;;
        *)
            echo "❌ Error: Unknown command '$COMMAND'" >&2
            echo ""
            ghh_help
            exit 1
            ;;
    esac
}

# Execute main function if the script is not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
