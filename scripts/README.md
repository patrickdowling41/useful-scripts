# Developer Utilities & Scripts

A collection of shell utilities, developer CLI workflows, and environment automation tools for the Digital Integration team.

---

## Available Utilities

| Tool | Category | Description | Setup |
| :--- | :--- | :--- | :--- |
| **[`wta`](wta/README.md)** | Git / Workflow | Git Worktree Add helper that automates branch validation, git pull, directory naming, `.env` file copying, and auto-detecting dependency installation (`pnpm`, `yarn`, `npm`, `bun`). | [scripts/wta/README.md](wta/README.md) |

---

## Contributing a New Utility

When adding a new script or utility, please follow the encapsulation standard:

1. Create a dedicated folder: `scripts/<tool-name>/`
2. Place the executable or shell function inside `scripts/<tool-name>/<tool-name>.sh`
3. Include an `install.sh` (and optionally `uninstall.sh`) script
4. Include a comprehensive `README.md` explaining prerequisites, usage, and manual setup
5. Update this `scripts/README.md` table
