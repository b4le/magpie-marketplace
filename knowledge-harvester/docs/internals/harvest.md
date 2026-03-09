---
name: harvest
description: Stage 3 - Copy files to workspace (zero context cost)
internal: true
---

# Harvest Stage

Copies selected sources to workspace using bash only (no agent context cost).

## Input
- `ranked.json` from Stage 2 (only "harvest" decisions)
- Output directory

## Process

### Local Files
```bash
for candidate in ranked_harvest:
    cp -p "$source_path" "sources/local/$(printf '%03d' $idx)-$(basename $source_path)"
```

### Google Drive (V2)
```bash
rclone copy "gdrive:$folder_id" "sources/gdrive/" \
  --drive-export-formats docx,pdf
```

### Web (V2)
```bash
curl -L -o "sources/web/$(printf '%03d' $idx)-page.html" "$url"
```

## Output Structure
```text
sources/
├── local/
├── gdrive/
└── web/
```

## Error Handling
- Copy fails → log, skip, continue
- rclone auth expired → prompt user for re-auth
- curl fails → retry 2x with backoff
