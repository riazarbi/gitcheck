# GitCheck Project

GitCheck is a quality assessment tool for code repositories using Task.
The core functionality is in the `gitcheck` bash script, with configuration 
in `gitcheck.yaml` and tests in the `tests/` directory.

## Build & Commands

- Run all quality checks: `./gitcheck`
- Run only preflight checks: `./gitcheck --only=preflight`
- Run only code checks: `./gitcheck --only=checks`
- Run only metrics: `./gitcheck --only=metrics`
- Run tests: `bats tests/*.bats`
- Run single test file: `bats tests/checks_execution.bats`
- Validate configuration: `./gitcheck --only=validate`
- Run with verbose output: `./gitcheck --verbose`

### Development Environment

- Artefact files created in: `.gitcheck/`
- Command scripts generated in: `.gitcheck/cmds/`
- Taskfiles generated in: `.gitcheck/phases/`
- Default timeout: 300 seconds (5 minutes)

## Code Style

- Bash: Use `set -euo pipefail` for strict error handling
- 2 spaces for indentation in YAML files
- Use double quotes for strings in bash when containing variables
- Keep functions simple and focused (grug approach)
- Use descriptive variable names (`task_name`, `yaml_file`, `timeout`)
- Prefer existing tools (Task, yq, jq) over custom implementations
- Avoid complexity demons - simple solutions preferred
- Use `local` variables in functions
- Comment WHY not WHAT in complex sections

## Testing

- BATS (Bash Automated Testing System) for all tests
- Test files: `tests/*.bats`
- Helper functions: `create_valid_yaml()`, `create_multiline_yaml()`
- Each test creates temporary directory and git repo
- Use new YAML format (key-value) not old array format
- Test both success and failure cases
- Test files: `*.bats`
- Mock dependencies by creating test YAML configurations

## Architecture

- Core: Bash script (`gitcheck`) using Task for execution
- Configuration: YAML file (`gitcheck.yaml`) with task-compatible format
- Script generation: Commands → `.gitcheck/cmds/*.sh` scripts
- Taskfile generation: YAML → Taskfile per phase
- Dependencies: yq, jq, git, bc, task (Taskfile)
- Execution: Task handles parallelism, timeouts, error handling
- Output: Artefact files with headers + metrics.json

## Security

- Commands run in isolated script files with `set -euo pipefail`
- Never commit secrets in gitcheck.yaml configuration
- Command timeouts prevent hanging processes
- Input validation on command line arguments and YAML
- Artefact files contain command output but not secrets
- Script execution uses least privilege (no sudo required)
- Dependencies are standard tools (no custom downloads)

## Git Workflow

- ALWAYS run `bats tests/*.bats` before committing
- Test specific changes with relevant test files
- Run `./gitcheck` to verify the tool works end-to-end
- NEVER use `git push --force` on the main branch
- Use `git push --force-with-lease` for feature branches if needed
- Test with both simple and complex YAML configurations

## Configuration

When adding new configuration options, update all relevant places:
1. YAML validation functions in `gitcheck` script
2. Test helper functions in `tests/*.bats`
3. Documentation in README.md and this AGENT.md

GitCheck YAML format uses task-compatible structure:
```yaml
preflight:
  task_name:
    cmd: command to run
checks:
  task_name:
    cmd: command to run
metrics:
  task_name:
    cmd: command to run
    data_type: string|number
    allowed_values: ["value1", "value2"] or ["0-100"]
    default: "fallback_value"
```