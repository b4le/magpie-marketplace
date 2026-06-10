# Workflow & Task Management Tools - Detailed Reference

Comprehensive documentation for Task agents, task management tools, and AskUserQuestion.

---

## Task Tool (Specialized Agents)

**Purpose**: Launch specialized agents for complex, multi-step tasks

**Available Agent Types**:

### 1. Explore Agent
**When to use**:
- Exploring codebase structure and organization
- Understanding how features are implemented
- Finding patterns across multiple files
- Answering "how does X work?" or "where is Y handled?"
- Any search requiring multiple rounds of glob/grep
- Questions about codebase architecture

**Thoroughness levels**: "quick", "medium", "very thorough"

**Examples**:
```
"How are API endpoints structured in this project?" - medium thoroughness
"Where are client errors handled?" - medium thoroughness
"What is the overall codebase structure?" - very thorough
```

### 2. Plan Agent
**When to use**:
- Breaking down complex implementation tasks
- Planning multi-step features before coding
- Understanding implementation steps needed

**NOT for**: Research tasks, exploration, or gathering information

**Examples**:
```
"Plan how to implement user authentication feature"
"Break down steps for adding dark mode support"
```

### 3. General-Purpose Agent
**When to use**:
- Complex research requiring multiple steps
- Searching when not confident about finding right match quickly
- Multi-step tasks needing autonomous handling

**Parameters**:
- `subagent_type` (required): Agent type to use
- `prompt` (required): Detailed task description
- `description` (required): Short 3-5 word description
- `model` (optional): "sonnet", "opus", "haiku" (prefer haiku for quick tasks)

**Best Practices**:
- Provide highly detailed task descriptions (agents are stateless)
- Specify exactly what information to return
- Agent gets full conversation history (can reference earlier context)
- Clearly state if agent should write code or just research
- Launch multiple agents concurrently when possible (parallel tool calls)
- Trust agent outputs
- Use proactively when task matches agent description

**When NOT to use the Task tool**:
- Reading a specific known file path (use Read)
- Searching for specific class like "class Foo" (use Glob)
- Searching within 2-3 specific files (use Read)
- Tasks unrelated to agent descriptions

---

## Task Management Tools

**Purpose**: Track multi-step tasks and demonstrate progress

> **Note**: The current task management tools are `TaskCreate`, `TaskUpdate`, `TaskGet`, and `TaskList`. The legacy `Tasks` alias may also work. The old `TodoWrite` and `TodoRead` names are no longer valid.

**When to use**:
- Complex tasks with 3+ distinct steps
- Non-trivial complex tasks requiring planning
- User explicitly requests todo list
- User provides multiple tasks
- After receiving new instructions
- When starting work (mark in_progress)
- After completing tasks (mark completed)

**When NOT to use**:
- Single straightforward tasks
- Trivial tasks
- Tasks completable in <3 steps
- Purely conversational/informational tasks

**Parameters**:
- `todos`: Array of todo objects with:
  - `content`: Imperative form (e.g., "Run tests")
  - `activeForm`: Present continuous (e.g., "Running tests")
  - `status`: "pending", "in_progress", "completed"

**Best Practices**:
- Update in real-time as you work
- Mark completed IMMEDIATELY after finishing (don't batch)
- Exactly ONE task in_progress at a time
- Only mark completed when FULLY accomplished
- Keep tasks if blocked/errored (don't mark complete)
- Remove no-longer-relevant tasks entirely
- Break complex tasks into smaller steps
- Be proactive with task management

**Task Completion Requirements**:
- ONLY mark as completed when FULLY accomplished
- If you encounter errors, blockers, or cannot finish, keep as in_progress
- When blocked, create new task describing what needs resolution
- Never mark completed if:
  - Tests are failing
  - Implementation is partial
  - You encountered unresolved errors
  - You couldn't find necessary files or dependencies

**Examples**:

Good todo structure:
```
{
  content: "Fix authentication bug in login.ts",
  activeForm: "Fixing authentication bug in login.ts",
  status: "in_progress"
}
```

Bad (vague):
```
{
  content: "Work on auth",
  activeForm: "Working on auth",
  status: "in_progress"
}
```

---

## AskUserQuestion Tool

**Purpose**: Gather user input during execution

**When to use**:
- Need user preferences or requirements
- Clarify ambiguous instructions
- Get decisions on implementation choices
- Offer multiple options to user

**Parameters**:
- `questions`: Array (1-4 questions) with:
  - `question`: Complete question with "?"
  - `header`: Short label (max 12 chars)
  - `options`: Array of 2-4 options with label and description
  - `multiSelect`: Allow multiple selections

**Best Practices**:
- Users can always select "Other" for custom input
- Make options mutually exclusive (unless multiSelect)
- Provide clear descriptions for each option
- Keep headers concise (max 12 characters)
- Phrase question clearly
- Use multiSelect when choices aren't mutually exclusive

**Example**:

```json
{
  "questions": [
    {
      "question": "Which authentication method should we use?",
      "header": "Auth method",
      "options": [
        {
          "label": "OAuth 2.0",
          "description": "Industry standard, works with Google/GitHub"
        },
        {
          "label": "JWT",
          "description": "Stateless tokens, good for APIs"
        },
        {
          "label": "Session-based",
          "description": "Traditional cookies, simple to implement"
        }
      ],
      "multiSelect": false
    }
  ]
}
```

---

## Task Management Workflow

### When to Use Tasks

**Example 1**: Complex multi-step task
```
User: "I want to add dark mode toggle to the application settings. Run tests when done!"

Assistant creates todos:
1. Create dark mode toggle component
2. Add dark mode state management
3. Implement CSS for dark theme
4. Update components to support theme switching
5. Run tests and ensure they pass
```

**Example 2**: Multiple user requests
```
User: "Implement user registration, product catalog, shopping cart, and checkout"

Assistant creates todos for each feature broken into sub-tasks
```

### When NOT to Use Tasks

**Example 1**: Simple single task
```
User: "Can you add a comment to the calculateTotal function?"