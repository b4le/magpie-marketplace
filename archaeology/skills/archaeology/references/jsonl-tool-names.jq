# jsonl-tool-names.jq
# Extracts tool call names from Claude Code JSONL files.
# Only includes actual tool invocations from assistant messages,
# excluding system prompts, meta records, and tool definitions.
#
# Usage (single file):
#   jq -r -f jsonl-tool-names.jq conversation.jsonl | sort | uniq -c | sort -rn
#
# Usage (batch, parallel):
#   find ~/.claude/projects/PROJECT_DIR -name "*.jsonl" -print0 |
#     xargs -0 -P 8 -I{} jq -r -f jsonl-tool-names.jq {} 2>/dev/null |
#     sort | uniq -c | sort -rn

select(.type == "assistant") |
select(.isMeta != true) |
.message.content // [] |
.[] |
select(type == "object") |
select(.type == "tool_use") |
.name
