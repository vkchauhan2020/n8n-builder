# n8n Builder

Codex-ready workspace for building, reviewing, and validating n8n workflows against a self-hosted n8n instance.

This repo is set up around:

- `n8n-mcp` for workflow discovery, validation, editing, and testing
- `n8n-skills` for n8n-specific prompting and implementation guidance
- a conservative workflow-review process that creates reviewed copies before changing anything live

## What This Repo Includes

- project instructions for Codex in [`AGENTS.md`](./AGENTS.md)
- Claude-oriented project notes in [`CLAUDE.md`](./CLAUDE.md)
- local MCP server wiring in [`.mcp.json`](./.mcp.json)
- Windows launcher for the MCP server in [`scripts/run-n8n-mcp.ps1`](./scripts/run-n8n-mcp.ps1)
- a workflow review helper in [`scripts/review-active-workflows-v2.ps1`](./scripts/review-active-workflows-v2.ps1)
- reviewed workflow notes in [`docs/WORKFLOW_REVIEW_STATUS.md`](./docs/WORKFLOW_REVIEW_STATUS.md)

## Quick Start

1. Install Codex with MCP support.
2. Install `n8n-mcp` and the `n8n-skills` pack.
3. Copy [`.env.n8n-mcp.example`](./.env.n8n-mcp.example) to `.env.n8n-mcp`.
4. Set `N8N_API_URL` to your n8n base URL and `N8N_API_KEY` to a valid API key.
5. Restart Codex so it reloads skills and MCP configuration.
6. Verify the connection with an MCP health check or by listing workflows.

Detailed setup steps live in [`docs/SETUP.md`](./docs/SETUP.md).

## Working Style

- Never edit production workflows directly.
- Create reviewed `V2` copies first.
- Validate after every meaningful change.
- Test with representative data before considering a workflow done.
- Prefer clear node naming, explicit configuration, and conservative error handling.

## Reviewed Workflow Notes

The repo documents the reviewed copies built during this project, including the fix for the blank PDF issue in the Telegram-to-Drive saver workflow.

See [`docs/WORKFLOW_REVIEW_STATUS.md`](./docs/WORKFLOW_REVIEW_STATUS.md).

## Repo Layout

```text
.
|-- AGENTS.md
|-- CLAUDE.md
|-- README.md
|-- .mcp.json
|-- .env.n8n-mcp.example
|-- docs/
|   |-- SETUP.md
|   `-- WORKFLOW_REVIEW_STATUS.md
`-- scripts/
    |-- review-active-workflows-v2.ps1
    `-- run-n8n-mcp.ps1
```

## Security

- Real credentials stay local in `.env.n8n-mcp`.
- That file is gitignored and should not be committed.
- If an API key is ever pasted into chat or logs, rotate it after verification.

