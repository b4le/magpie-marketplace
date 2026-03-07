# jsonl-filter.jq
# Extracts only real conversation content from Claude Code JSONL files.
# Filters out: progress/system/file-history-snapshot record types,
#              isMeta user messages (skill injections, CLAUDE.md loads),
#              tool_result blocks (contain raw file contents from Read/Glob/Bash
#                which cause self-referential score inflation when archaeology
#                reads its own domain files during surveys),
#              tool_use input fields (bash commands, not conversation content).
#
# Usage (single file):
#   jq -r -f jsonl-filter.jq conversation.jsonl | grep -oi "\bkeyword\b" | wc -l
#
# Usage (batch, parallel):
#   find ~/.claude/projects/PROJECT_DIR -name "*.jsonl" -print0 |
#     xargs -0 -P 8 -I{} jq -r -f jsonl-filter.jq {} 2>/dev/null |
#     grep -oi "\bkeyword\b" | wc -l

select(
  .type == "user" or .type == "assistant"
) |
select(.isMeta != true) |
if .type == "user" then
  .message.content |
  if type == "string" then .
  elif type == "array" then
    [ .[] |
      if type == "object" then
        if .type == "text" then .text
        # tool_result blocks excluded: they contain raw file contents from
        # Read/Glob/Bash tool calls, not conversation text. Including them
        # inflates keyword scores because any file the assistant reads
        # (especially archaeology's own domain definitions) injects all
        # domain keywords into the scoring pipeline.
        else empty
        end
      else empty
      end
    ] | join("\n")
  else empty
  end
elif .type == "assistant" then
  .message.content // [] |
  [ .[] | select(type == "object") | select(.type == "text") | .text ] |
  join("\n")
else empty
end
