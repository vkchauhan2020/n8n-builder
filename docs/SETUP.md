# Setup

## Prerequisites

- Windows PowerShell 7
- Node.js available to the current user
- Codex configured locally
- access to your self-hosted n8n instance
- an n8n API key with workflow read/write access

## Local Files

This repo expects these local pieces:

- [`.mcp.json`](../.mcp.json) to point Codex at the project MCP server launcher
- [`.env.n8n-mcp.example`](../.env.n8n-mcp.example) as the template for local credentials
- [`scripts/run-n8n-mcp.ps1`](../scripts/run-n8n-mcp.ps1) to start `n8n-mcp` in a Windows-friendly way

## Environment

Create a local `.env.n8n-mcp` file with:

```env
N8N_API_URL=https://your-n8n-host
N8N_API_KEY=your-api-key
```

Notes:

- `N8N_API_URL` should be the n8n instance base URL, not an MCP endpoint path.
- Keep `.env.n8n-mcp` local only.

## Codex Reload

After changing MCP config, skills, or local env:

1. restart Codex
2. reopen the repo
3. verify the `n8n` MCP server is available

## Basic Verification

Good first checks:

- `n8n_health_check`
- `n8n_list_workflows`
- `n8n_get_workflow` on a known workflow

If those work, the repo is ready for workflow building and review.

## Review Workflow Pattern

The recommended sequence for production-safe work in this repo is:

1. inspect the live workflow
2. create a reviewed copy
3. rename nodes and fix structure
4. validate
5. test with controlled inputs
6. only then consider activation or promotion

## Scripts

### `scripts/run-n8n-mcp.ps1`

Starts the MCP server in a Windows-safe way so Codex can access n8n tools from this repo.

### `scripts/review-active-workflows-v2.ps1`

Creates reviewed `V2` copies of active workflows so cleanup and testing can happen away from production workflows.

