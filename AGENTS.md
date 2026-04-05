# n8n Workflow Builder

This project is set up for building high-quality n8n workflows with the `n8n-mcp` server and the `n8n-skills` skill pack.

## Environment

- n8n instance: self-hosted n8n
- MCP server: `n8n-mcp` (`czlonkowski/n8n-mcp`)
- Skills: `n8n-skills` (`czlonkowski/n8n-skills`)

## Workflow Process

### 1. Understand Requirements

- Clarify the workflow purpose and trigger
- Identify integrations, data flow, and error handling needs

### 2. Search Templates First

- Use templates before building from scratch
- Start from the closest proven pattern whenever possible

### 3. Research Nodes

- Search for the right nodes before configuring them
- Review node details before choosing operations and fields

### 4. Build Incrementally

- Start with the trigger node
- Add nodes one at a time
- Validate as changes are made

### 5. Validate Before Deployment

- Validate nodes and workflows before deployment
- Fix issues before continuing

### 6. Test

- Test with representative data
- Verify outputs and error handling

## Safety Rules

- Never edit production workflows directly; create copies first
- Never deploy without validation
- Never skip testing
- Never rely on defaults for important node behavior

## Quality Standards

### Before Creating

- Search templates for existing patterns
- Understand required node configuration details
- Plan error handling explicitly

### During Building

- Validate nodes as they are added
- Use correct n8n expression syntax
- Follow established workflow patterns

### Before Deployment

- Run strict workflow validation
- Test with realistic data
- Confirm error handling paths

## Recommended Workflow Patterns

1. Webhook processing
2. HTTP API integration
3. Database operations
4. AI workflows
5. Scheduled tasks

## Common Mistakes To Avoid

- Using expressions inside Code nodes instead of variables
- Forgetting `$json.body` for webhook payload access
- Not handling null or empty values
- Skipping validation before deployment
- Editing production workflows directly
