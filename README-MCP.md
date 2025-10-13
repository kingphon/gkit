# GKit MCP Server

An MCP (Model Context Protocol) server that exposes Git and GitHub workflow automation tools from the `gkit.sh` script.

## Features

This MCP server provides the following tools:

- **create_pr** - Create a pull request to a specific base branch
- **create_pr_to_staging** - Create a pull request to the latest release branch
- **create_branch** - Create a new branch from develop (or specified branch)
- **create_branch_from_staging** - Create a new branch from the latest release branch
- **create_hotfix_branch** - Create a new hotfix branch from main
- **approve_pr** - Approve a GitHub pull request
- **merge_pr** - Approve and merge a GitHub pull request
- **trigger_workflow** - Interactively trigger a GitHub Action workflow
- **send_slack_message** - Send a message to a Slack channel

## Prerequisites

1. **Dependencies**: The original `gkit.sh` script dependencies:
   - `gh` (GitHub CLI)
   - `fzf` (fuzzy finder)
   - `jq` (JSON processor)

2. **Environment Variables** (optional, for Slack integration):
   ```bash
   export SLACK_TOKEN="xoxb-your-slack-token"
   export PR_ROOM="C09E15YGCES"
   export DINH_SLACK_ID="U08TVVC6PL5"
   export PHUONG_SLACK_ID="U08UAPSK14H"
   export VINH_SLACK_ID="U08TR09LSEP"
   export THY_SLACK_ID="U08TS1P3JMC"
   ```

## Installation

1. Install dependencies:
   ```bash
   npm install
   ```

2. Build the TypeScript code:
   ```bash
   npm run build
   ```

## Usage

### Running the MCP Server

```bash
npm start
```

### Development Mode

```bash
npm run dev
```

### MCP Client Configuration

Add this to your MCP client configuration (e.g., Claude Desktop):

```json
{
  "mcpServers": {
    "gkit": {
      "command": "node",
      "args": ["/path/to/gkit/dist/index.js"],
      "env": {
        "SLACK_TOKEN": "xoxb-your-token",
        "PR_ROOM": "C09E15YGCES"
      }
    }
  }
}
```

## Tool Descriptions

### create_pr
Create a pull request to a specific base branch.

**Parameters:**
- `base` (string, optional): Base branch name (default: "release")
- `title` (string, optional): PR title (uses --fill if not provided)

### create_pr_to_staging
Create a pull request to the latest release branch.

**Parameters:**
- `remote` (string, optional): Remote name (default: "origin")
- `title` (string, optional): PR title

### create_branch
Create a new branch from develop or specified branch.

**Parameters:**
- `branch` (string, required): New branch name
- `from` (string, optional): Source branch (default: "develop")
- `remote` (string, optional): Remote name (default: "origin")

### create_branch_from_staging
Create a new branch from the latest release branch.

**Parameters:**
- `branch` (string, required): New branch name
- `remote` (string, optional): Remote name (default: "origin")

### create_hotfix_branch
Create a new hotfix branch from main.

**Parameters:**
- `branch` (string, required): New branch name
- `from` (string, optional): Source branch (default: "main")
- `remote` (string, optional): Remote name (default: "origin")

### approve_pr
Approve a GitHub pull request.

**Parameters:**
- `pr_url` (string, required): GitHub PR URL

### merge_pr
Approve and merge a GitHub pull request.

**Parameters:**
- `pr_url` (string, required): GitHub PR URL

### trigger_workflow
Interactively trigger a GitHub Action workflow for a PR.

**Parameters:**
- `pr_url` (string, required): GitHub PR URL

### send_slack_message
Send a message to a Slack channel.

**Parameters:**
- `message` (string, required): Message to send

## Error Handling

The MCP server will return error messages if:
- Required dependencies are missing
- Git commands fail
- GitHub API calls fail
- Invalid parameters are provided

## Development

The server is built with TypeScript and uses the official MCP SDK. The main logic delegates to the existing `gkit.sh` script, ensuring consistency with the original functionality.

## License

MIT
