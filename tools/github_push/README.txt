# GitHub Push Tool

Pushes local commits to GitHub via the REST API, bypassing proxy/HTTP2 issues.

## Prerequisites
- `gh` CLI installed and authenticated (`gh auth login`)
- `curl` installed
- Run from inside the `sio_copilot-` git repo

## Usage

```bash
cd /nfs/site/disks/sunger_wa/git_hub_gfca0/sio_copilot-

# Standard push (all changed files, uses local commit message)
python3 tools/github_push/github_push.py

# Custom commit message
python3 tools/github_push/github_push.py -m "Updated timing configs"

# Preview what would be pushed (no actual push)
python3 tools/github_push/github_push.py --dry-run

# Skip additional files
python3 tools/github_push/github_push.py --skip path/to/file1 path/to/file2
```

## Workflow

1. Make your changes locally
2. `git add -A && git commit -m "your message"`
3. `python3 tools/github_push/github_push.py`

## Notes
- Files with secrets (e.g. `sio_uploader.json`) are auto-skipped
- Add files to `ALWAYS_SKIP` in the script to permanently exclude them
- If `gh auth` expires, re-run `gh auth login`
