Based on the documentation, here's how to give claude code a non-interactive command:

  Basic Command for Your Use Case

  cat /path/to/STUFF.md | claude -p --output-format json > summary.json

  Or more readable output:

  cat /path/to/STUFF.md | claude -p > summary.txt

  Enhanced Version with Summary Generation

  To have Claude execute tasks AND generate a structured summary document:

  cat /path/to/STUFF.md | claude -p "Execute the tasks described below. When complete, provide a detailed summary document including:
  1. Tasks completed
  2. Changes made (files created/modified)
  3. Challenges encountered and solutions
  4. Any remaining items or recommendations

  Instructions:
  $(cat /path/to/STUFF.md)" --output-format text > SUMMARY.md

  For Full Automation with Permission Pre-approval

  cat /path/to/STUFF.md | claude -p \
    --permission-mode acceptEdits \
    --output-format json \
    > execution-summary.json

  Background Execution

  To run it and continue with other tasks:

  nohup bash -c 'cat STUFF.md | claude -p --output-format text > SUMMARY.md' &

  Or with logging:

  nohup bash -c 'cat STUFF.md | claude -p --output-format text > SUMMARY.md 2>&1' > claude-execution.log &

  Key Flags

  - -p / --print: Non-interactive mode
  - --output-format: text, json, or stream-json
  - --permission-mode acceptEdits: Auto-approve file edits (use cautiously)
  - --allowedTools: Restrict available tools if needed

  Example STUFF.md Format

  # Tasks to Complete

  1. Refactor the PetLocationManager to use modern Swift concurrency
  2. Add comprehensive error handling to WatchLocationProvider
  3. Update tests for all modified components
  4. Generate documentation for the new architecture

  ## Success Criteria
  - All tests passing
  - No compiler warnings
  - Code follows project guidelines in CLAUDE.md

  The -p flag is the key - it makes Claude Code run non-interactively, execute the tasks, and exit with output you can redirect to a file.

