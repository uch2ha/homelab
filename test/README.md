Test infrastructure for the homelab repo. All tests run in a Docker image to ensure a consistent environment.

## CI

[GitHub Actions](.github/workflows/pipeline.yaml) runs this automatically on every PR. The pipeline builds the Docker image itself, so when `CI=true` is set, `run-tests.sh` skips the image build/cleanup and runs the tests directly.

## Run locally

```bash
# build + run everything (image is cleaned up after)
bash test/run-tests.sh

# specific scope (build -> run -> cleanup)
bash test/run-tests.sh validator
bash test/run-tests.sh script/task
```

## Scopes

- `all` (default) — run every _.sh_ / _.py_ / _.bats_ file in `test/` (except `run-tests.sh`)
- `[scoped]` — run _every test file_ in that subdir only, e.g. `validator`, `script`, `script/task`

## Structure

```
test/
├── Dockerfile            # Alpine image with bash, shellcheck, bats, python, rsync
├── run-tests.sh          # Entry point — builds image, runs tests, cleans up
├── validator/            # Static validation per file type
│   ├── validate-py.py
│   ├── validate-sh.sh
│   └── validate-yaml.py
├── script/task/          # Unit/Integration tests for custom scripts
│   └── test-rsync-from-to.bats
├── script/container/     # Unit/Integration tests for service orchestration scripts
│   └── test-parse-start-config.py
└── scheduler/
    └── test-beszel-token-refresh.bats
```
