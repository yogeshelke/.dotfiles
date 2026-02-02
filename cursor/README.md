# Cursor IDE Configuration

## Setup

### Settings & Keybindings
These are automatically symlinked by `bootstrap.sh`:
- `settings.json` → `~/Library/Application Support/Cursor/User/settings.json`
- `keybindings.json` → `~/Library/Application Support/Cursor/User/keybindings.json`

### MCP Configuration (Manual Setup Required)
The `mcp.json.template` contains the structure for MCP server integrations (Jira, Confluence, Slack).

**To set up:**
1. Copy the template:
   ```bash
   cp ~/.dotfiles/cursor/mcp.json.template ~/.cursor/mcp.json
   ```

2. Edit `~/.cursor/mcp.json` and replace placeholders with your actual tokens:
   - `YOUR_SITE_NAME` → Your Atlassian site name (e.g., "mycompany")
   - `your.email@company.com` → Your Atlassian email
   - `YOUR_ATLASSIAN_API_TOKEN` → Generate at https://id.atlassian.com/manage-profile/security/api-tokens
   - `YOUR_SLACK_XOXC_TOKEN` → Your Slack xoxc token
   - `YOUR_SLACK_XOXD_TOKEN` → Your Slack xoxd token

**Note:** `mcp.json` contains sensitive tokens and should NEVER be committed to git.
