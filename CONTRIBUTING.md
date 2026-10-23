# Contributing

Thanks for taking the time to improve this project.

## Workflow

`main` is the trunk and is always releasable. Work happens on short-lived
branches (`feat/...`, `fix/...`, `chore/...`) that live for hours or days, not
weeks.

1. Branch from the latest `main`.
2. Keep the change small and focused; one concern per pull request.
3. Run the checks locally:

   ```bash
   make lint config test-vcl
   make init && make up && make smoke   # for changes to the stack
   ```

4. Open a pull request using the template. CI must be green.
5. Pull requests are **squash-merged**, so the PR title becomes the commit
   message. Use the imperative mood, e.g. `Add Redis healthcheck`.

## Conventions

- Pin image versions (`nginx:1.30-alpine`, not `nginx:latest`). Dependabot
  proposes upgrades.
- New configuration goes through `.env` and must be documented in
  `.env.example` and the README.
- Shell scripts use `set -euo pipefail` and must pass ShellCheck.
- Never commit secrets, certificates, `acme.json`, database dumps or `app/`.
