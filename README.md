# gkit

A command-line tool to streamline your Git and GitHub workflows.

## Features

- Create GitHub Pull Requests from the command line.
- Create new branches based on `develop`, `main`, or the latest release branch.
- Approve and merge Pull Requests.
- Trigger GitHub Actions workflows for a Pull Request.
- Optional Slack integration for notifications.

## Prerequisites

Before you begin, ensure you have the following tools installed:

- [GitHub CLI (`gh`)](https://cli.github.com/)
- [fzf](https://github.com/junegunn/fzf)
- [jq](https://stedolan.github.io/jq/)

## Installation

You can install `gkit` with a single command.

```bash
curl -fsSL https://raw.githubusercontent.com/kingphon/gkit/main/install.sh | bash
```

## Usage

Here are the available commands:

```
Usage: gkit <command> [arguments...]

Commands:
  pr <base> [title]           Create a PR to a specific base branch.
  prs [remote] [title]        Create a PR to the latest release branch (staging).
  nb <branch> [from] [remote] Create a new branch from 'develop' (or [from]).
  nbs <branch> [remote]       Create a new branch from the latest release branch.
  nbh <branch> [from] [remote] Create a new branch from 'main' (or [from]).
  ap <pr_url>                 Approve a GitHub PR.
  mg <pr_url>                 Approve and merge a GitHub PR.
  wf <pr_url>                 Interactively trigger a GitHub Action workflow for a PR.
  sl <message>                Send a message to a Slack channel.
  help, -h, --help            Show this help message.
```

## Configuration

For Slack integration, you need to set the following environment variables:

- `SLACK_TOKEN`: Your Slack API token (e.g., `xoxb-...`).
- `PR_ROOM`: The Slack channel ID to send notifications to (e.g., `C09E15YGCES`).
- `DINH_SLACK_ID`, `PHUONG_SLACK_ID`, `VINH_SLACK_ID`, `THY_SLACK_ID`: Slack member IDs for mentions.

You can add them to your shell profile (e.g., `~/.zshrc` or `~/.bashrc`):

```bash
export SLACK_TOKEN="your-slack-token"
export PR_ROOM="your-slack-channel-id"
export DINH_SLACK_ID="your-dinh-slack-id"
export PHUONG_SLACK_ID="your-phuong-slack-id"
export VINH_SLACK_ID="your-vinh-slack-id"
export THY_SLACK_ID="your-thy-slack-id"
```

After adding the variables, be sure to reload your shell for the changes to take effect:

```bash
# For Zsh
source ~/.zshrc

# For Bash
source ~/.bashrc
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
