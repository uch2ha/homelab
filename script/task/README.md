## rsync-from-to.sh

Sync a source directory to a destination with safety checks.

1. **Validate** — source exists and is not empty, destination parent exists
2. **Warn** — trailing slashes missing, folder names differ, destination empty or missing (asks to continue)
3. **Dry-run** — runs `rsync -aiv --dry-run`, groups changes by directory depth, displays summary
4. **Confirm** — shows dry-run summary, asks to proceed
5. **Real run** — runs `rsync -a`, logs to `/tmp/rsync-script/`
6. **Result** — prints source/destination size

```bash
./rsync-from-to.sh /path/from/user/ /path/to/user/
```
