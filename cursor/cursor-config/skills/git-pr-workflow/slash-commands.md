# Simple Command Triggers

## Quick Commands

Now you can trigger the Git PR workflow with these simple commands:

### ⚡ **Safe Command Triggers**
- Type: **`pr workflow`** → Automatically runs the full Git PR workflow
- Type: **`git pr`** → Same as above  
- Type: **`run pr workflow`** → Same as above

### 🎯 **How It Works**
The skill is now configured to activate when it detects these keywords in your message. The agent will:

1. Recognize the simple trigger word
2. Automatically execute the complete workflow:
   - Check git status
   - Commit changes with proper message
   - Push branch
   - Create PR with devops-platform team
   - Send Slack notification to #ae_devops

### 💡 **Usage Examples**

**Safe commands that won't conflict:**
```
pr workflow
```

**Or:**
```
git pr
```

**Or:**
```
run pr workflow
```

The agent will detect the trigger word and execute the complete Git PR workflow without you having to explain the steps every time.

### 🔧 **Alternative: Custom Cursor Command**

If you want a true slash command like `/pr`, you would need to:

1. Create a Cursor extension
2. Register a custom command
3. Bind it to a keybinding

But the simple keyword trigger is much easier and works immediately!