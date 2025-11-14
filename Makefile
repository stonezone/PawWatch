.PHONY: surf surf-logs

# surf: Build + install both simulator targets and capture a timestamped log.
surf:
	@bash scripts/surf_build.sh

# surf-logs: Show the most recent surf build logs for quick reference.
surf-logs:
	@ls -1 logs/surf-build-*.log 2>/dev/null | tail -n 5 || echo "(no logs yet)"
