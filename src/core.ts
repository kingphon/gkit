
import { spawn } from 'child_process';
import { Tool } from '@modelcontextprotocol/sdk/types.js';

// This is the single source of truth for all gkit commands.
// Both the MCP server and the Express REST API will use this list.
export const GkitCommands: Tool[] = [
  {
    name: 'create_pr',
    description: 'Create a pull request to a specific base branch',
    inputSchema: {
      type: 'object',
      properties: {
        base: {
          type: 'string',
          description: 'Base branch name (default: release)',
          default: 'release'
        },
        title: {
          type: 'string',
          description: 'PR title (optional, will use --fill if not provided)'
        }
      },
      required: []
    }
  },
  {
    name: 'create_pr_to_staging',
    description: 'Create a pull request to the latest release branch (staging)',
    inputSchema: {
      type: 'object',
      properties: {
        remote: {
          type: 'string',
          description: 'Remote name (default: origin)',
          default: 'origin'
        },
        title: {
          type: 'string',
          description: 'PR title'
        }
      },
      required: []
    }
  },
  {
    name: 'create_branch',
    description: 'Create a new branch from develop (or specified branch)',
    inputSchema: {
      type: 'object',
      properties: {
        branch: {
          type: 'string',
          description: 'New branch name'
        },
        from: {
          type: 'string',
          description: 'Source branch (default: develop)',
          default: 'develop'
        },
        remote: {
          type: 'string',
          description: 'Remote name (default: origin)',
          default: 'origin'
        }
      },
      required: ['branch']
    }
  },
  {
    name: 'create_branch_from_staging',
    description: 'Create a new branch from the latest release branch',
    inputSchema: {
      type: 'object',
      properties: {
        branch: {
          type: 'string',
          description: 'New branch name'
        },
        remote: {
          type: 'string',
          description: 'Remote name (default: origin)',
          default: 'origin'
        }
      },
      required: ['branch']
    }
  },
  {
    name: 'create_hotfix_branch',
    description: 'Create a new hotfix branch from main (or specified branch)',
    inputSchema: {
      type: 'object',
      properties: {
        branch: {
          type: 'string',
          description: 'New branch name'
        },
        from: {
          type: 'string',
          description: 'Source branch (default: main)',
          default: 'main'
        },
        remote: {
          type: 'string',
          description: 'Remote name (default: origin)',
          default: 'origin'
        }
      },
      required: ['branch']
    }
  },
  {
    name: 'approve_pr',
    description: 'Approve a GitHub pull request',
    inputSchema: {
      type: 'object',
      properties: {
        pr_url: {
          type: 'string',
          description: 'GitHub PR URL'
        }
      },
      required: ['pr_url']
    }
  },
  {
    name: 'merge_pr',
    description: 'Approve and merge a GitHub pull request',
    inputSchema: {
      type: 'object',
      properties: {
        pr_url: {
          type: 'string',
          description: 'GitHub PR URL'
        }
      },
      required: ['pr_url']
    }
  },
  {
    name: 'trigger_workflow',
    description: 'Interactively trigger a GitHub Action workflow for a PR',
    inputSchema: {
      type: 'object',
      properties: {
        pr_url: {
          type: 'string',
          description: 'GitHub PR URL'
        }
      },
      required: ['pr_url']
    }
  },
  {
    name: 'send_slack_message',
    description: 'Send a message to a Slack channel',
    inputSchema: {
      type: 'object',
      properties: {
        message: {
          type: 'string',
          description: 'Message to send'
        }
      },
      required: ['message']
    }
  }
];

// A map to easily find the corresponding gkit.sh command for a tool name.
export const ToolToGkitCommandMap: Record<string, string> = {
    create_pr: 'pr',
    create_pr_to_staging: 'prs',
    create_branch: 'nb',
    create_branch_from_staging: 'nbs',
    create_hotfix_branch: 'nbh',
    approve_pr: 'ap',
    merge_pr: 'mg',
    trigger_workflow: 'wf',
    send_slack_message: 'sl'
};

/**
 * Executes a command in the gkit.sh script. This is the single, shared
 * function used by both the REST API and the MCP server.
 * @param command The gkit command to run (e.g., 'pr', 'nb').
 * @param args The arguments to pass to the command.
 * @returns A promise that resolves with the command's output.
 */
export async function executeGkit(command: string, args: string[] = []): Promise<{ success: boolean; output: string; error?: string }> {
  return new Promise((resolve) => {
    const child = spawn('./gkit.sh', [command, ...args], { 
      stdio: ['pipe', 'pipe', 'pipe'],
      shell: true 
    });
    
    let stdout = '';
    let stderr = '';
    
    child.stdout?.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stderr?.on('data', (data) => {
      stderr += data.toString();
    });
    
    child.on('close', (code) => {
      resolve({
        success: code === 0,
        output: stdout.trim(),
        error: stderr.trim()
      });
    });
  });
}
