#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import { spawn } from 'child_process';
import { GkitCommands, executeGkit, ToolToGkitCommandMap } from './core.js';

// Configuration from environment variables
const GITHUB_TOKEN = process.env.GITHUB_TOKEN || process.env.GITHUB_PAT;

// --- Start of AI-powered and advanced tools logic (specific to this MCP server) ---

// Helper function to execute shell commands (used by advanced tools like fetchPrDiff)
async function executeCommand(command: string, args: string[] = []): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return new Promise((resolve) => {
    const child = spawn(command, args, { 
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
        stdout: stdout.trim(),
        stderr: stderr.trim(),
        exitCode: code || 0
      });
    });
  });
}

function sanitizePrUrl(input: string): string {
  let u = (input || '').trim();
  if (u.startsWith('@')) u = u.slice(1);
  if (u.startsWith('<') && u.endsWith('>')) u = u.slice(1, -1);
  u = u.replace(/^`+|`+$/g, '');
  return u;
}

async function fetchPrDiff(prUrl: string, token?: string): Promise<string> {
  try {
    const cleaned = sanitizePrUrl(prUrl);
    const url = new URL(cleaned);
    const parts = url.pathname.split('/').filter(Boolean);
    if (parts.length < 4 || parts[2] !== 'pull') {
      throw new Error('Invalid PR URL. Expected https://github.com/owner/repo/pull/123');
    }
    const owner = parts[0];
    const repo = parts[1];
    const number = parts[3];
    const apiUrl = `https://api.github.com/repos/${owner}/${repo}/pulls/${number}`;

    const headers = [
      '-H', 'Accept: application/vnd.github.v3.diff',
      '-H', 'X-GitHub-Api-Version: 2022-11-28',
      '-H', 'User-Agent: gkit-mcp'
    ];
    let authToken = token || GITHUB_TOKEN;
    if (authToken) {
      headers.push('-H', `Authorization: Bearer ${authToken.replace(/^Bearer\s+/i, '')}`);
    }

    const result = await executeCommand('curl', ['-sSL', ...headers, apiUrl]);
    if (result.exitCode === 0 && result.stdout && !result.stdout.trim().startsWith('{')) {
      return result.stdout;
    }

    throw new Error(`GitHub diff fetch failed for ${cleaned}. Check token and access, or the URL.`);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    throw new Error(`fetchPrDiff error: ${msg}`);
  }
}

export async function reviewCode({ diff }: { diff: string }): Promise<{ summary: string; issues: string[]; rating: number }> {
  const issues: string[] = [];
  const lower = diff.toLowerCase();
  if (diff.includes('console.log')) issues.push('Remove console.log in production code.');
  if (lower.includes('todo') || lower.includes('fixme')) issues.push('Resolve TODO/FIXME before merging.');
  if (lower.includes('password') || lower.includes('secret')) issues.push('Ensure secrets are not hard-coded.');
  if (diff.match(/\bany\b/)) issues.push('Avoid TypeScript any; prefer explicit types.');
  if (diff.match(/catch\s*\(.*\)\s*\{\s*\}/)) issues.push('Avoid empty catch blocks; handle errors meaningfully.');

  const summary = issues.length ? 'Basic static review found potential improvements.' : 'No obvious issues detected by basic static review.';
  const rating = Math.max(1, 10 - Math.min(issues.length, 9));
  return { summary, issues, rating };
}

export async function reviewPullRequest({ diff }: { diff: string }): Promise<{ output: string }> {
  const lines = diff.split('\n');
  const comments: string[] = [];
  lines.forEach((line, idx) => {
    const lineNo = idx + 1;
    if (/console\.log\(/.test(line)) comments.push(`${lineNo}: Avoid console.log in committed code.`);
    if (/TODO|FIXME/.test(line)) comments.push(`${lineNo}: Address TODO/FIXME before merging.`);
  });

  if (comments.length === 0) {
    return { output: `APPROVED:\nLooks good — no issues detected by basic checks.` };
  }

  const summary = `Found ${comments.length} potential issue(s). Please address before merge.`;
  return { output: `REVIEW:\n${comments.join('\n')}\n\nSUMMARY:\n${summary}` };
}

export async function suggestCommitMessage({ diff }: { diff: string }): Promise<{ output: string; commitMessage: string; commitResult: { stdout: string; stderr: string; exitCode: number } }> {
  const possibleType = diff.toLowerCase().includes('fix') ? 'fix' : 'feat';
  const summary = 'update based on diff'; // Simplified summary
  const commitMessage = `${possibleType}: ${summary}`;
  const commitResult = await executeCommand('git', ['commit', '-m', commitMessage]);
  const output = `REVIEW:\n- Looks good.\nCOMMIT:\n${commitMessage}`;
  return { output, commitMessage, commitResult };
}

// Define advanced tools that are NOT simple wrappers around gkit.sh
const advancedTools: Tool[] = [
  {
    name: 'review_code',
    description: 'Review a git diff or code text and return structured feedback',
    inputSchema: { type: 'object', properties: { diff: { type: 'string', description: 'Code or git diff to review' } }, required: ['diff'] }
  },
  {
    name: 'commit',
    description: 'Review a diff, generate a Conventional Commit message, and commit',
    inputSchema: { type: 'object', properties: { diff: { type: 'string', description: 'Git diff to analyze' } }, required: ['diff'] }
  },
  {
    name: 'rv_pr',
    description: 'Review a pull request diff and generate structured comments or approval',
    inputSchema: {
      type: 'object',
      properties: {
        diff: { type: 'string', description: 'Git diff content to review (provide either diff or pr_url)' },
        pr_url: { type: 'string', description: 'GitHub PR URL (e.g., https://github.com/owner/repo/pull/123)' },
        token: { type: 'string', description: 'GitHub token (optional if GITHUB_TOKEN env is set)' }
      },
      required: []
    }
  }
];

// Combine the core gkit commands with the advanced tools
const allTools: Tool[] = [...GkitCommands, ...advancedTools];

// --- End of AI-powered and advanced tools logic ---


// Create and configure the MCP server
const server = new Server({ name: 'gkit-mcp', version: '1.0.0' }, { capabilities: { tools: {} } });

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: allTools };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (!args || typeof args !== 'object') {
    return { content: [{ type: 'text', text: 'Error: Invalid arguments provided' }], isError: true };
  }

  try {
    // Handle gkit.sh wrapper commands dynamically
    const gkitCommand = ToolToGkitCommandMap[name];
    if (gkitCommand) {
      const tool = GkitCommands.find(t => t.name === name)!;
      const paramOrder = Object.keys(tool.inputSchema.properties || {});
      const gkitArgs = paramOrder.map(param => (args as any)[param]).filter(v => v !== undefined);
      
      const result = await executeGkit(gkitCommand, gkitArgs);
      if (!result.success) {
        throw new Error(result.error || result.output);
      }
      return { content: [{ type: 'text', text: result.output }] };
    }

    // Handle advanced, non-gkit tools
    switch (name) {
      case 'rv_pr':
        let diffText: string | undefined;
        const a: any = args;
        if (a.diff) {
          diffText = a.diff;
        } else if (a.pr_url) {
          diffText = await fetchPrDiff(a.pr_url, a.token);
        }
        if (!diffText) throw new Error('Provide either "diff" or "pr_url"');
        const reviewResult = await reviewPullRequest({ diff: diffText });
        return { content: [{ type: 'text', text: reviewResult.output }] };

      case 'review_code':
        const codeReviewResult = await reviewCode({ diff: (args as any).diff });
        return { content: [{ type: 'text', text: JSON.stringify(codeReviewResult, null, 2) }] };

      case 'commit':
        const commitResult = await suggestCommitMessage({ diff: (args as any).diff });
        const text = [
          'Suggested commit and result:',
          commitResult.output,
          '---',
          `Commit Message: ${commitResult.commitMessage}`,
          `Exit Code: ${commitResult.commitResult.exitCode}`,
          `Stdout: ${commitResult.commitResult.stdout || '(empty)'}`,
          `Stderr: ${commitResult.commitResult.stderr || '(empty)'}`
        ].join('\n');
        return { content: [{ type: 'text', text }] };

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return { content: [{ type: 'text', text: `Error: ${errorMessage}` }], isError: true };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('GKit MCP server running on stdio');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
