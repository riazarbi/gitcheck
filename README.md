# GitCheck

## Purpose

GitCheck is a tool designed to evaluate the quality of code repositories at specific commit points. It reads a `gitcheck.yaml` configuration file (defaults to `gitcheck.yaml` in the current directory), executes quality assessment commands against the code at the specified commit hash (defaults to the latest commit of the current branch), and produces two types of outputs: artefact files containing command output logs, and a metrics.json file with computed quality scores that is automatically added as a git note named `gitcheck-metrics` to the relevant commit.

GitCheck operates in three distinct phases:
1. **Preflight** - Environment setup commands (virtual environments, system packages)
2. **Checks** - Quality assessment commands (linting, coverage, etc.)
3. **Metrics** - Compilation of quality scores from artefact files

## Features

- Configuration-driven quality evaluation via `gitcheck.yaml`
- Commit-specific analysis using specified commit hash
- Automated execution of quality assessment commands against historical code
- Artefact files containing command output logs
- Computed quality metrics stored in `metrics.json`
- Git notes integration for metrics storage
- Customizable quality metrics and checks
- Repository quality scoring and reporting

## Installation

```bash
# Download the gitcheck script
curl -o gitcheck https://raw.githubusercontent.com/your-repo/gitcheck/main/gitcheck

# Make it executable
chmod +x gitcheck

# Move to a directory in your PATH (optional)
sudo mv gitcheck /usr/local/bin/
```

## Usage

### Configuration

Create a `gitcheck.yaml` file in your repository root:

```yaml
# Example gitcheck.yaml configuration
preflight:
  - name: "setup_python_env"
    command: "python -m venv venv && source venv/bin/activate && pip install -r requirements.txt"

checks:
  - name: "code_quality"
    command: "npm run lint"
  
  - name: "test_coverage"
    command: "npm run test:coverage"
```

**Note:**
- Use `--config <file>` (or `-c <file>`) to specify the config file (default: `gitcheck.yaml`).
- Use `--commit <hash>` (or `-C <hash>`) to specify the commit hash (default: latest commit of current branch).
- The script will execute these commands against the code at the specified commit hash, while reading the `gitcheck.yaml` file from the current working directory. Artefact files are automatically named after their step name (without extension) and stored in the `.gitcheck/` folder.

### Example Commands

```bash
# Run with all defaults
gitcheck

# Specify config file
gitcheck --config my-config.yaml

# Specify commit hash
gitcheck --commit abc1234

# Specify both config and commit
gitcheck --config my-config.yaml --commit abc1234

# Run only checks phase
gitcheck --checks-only

# Combine options
gitcheck --config my-config.yaml --commit HEAD --checks-only
```

## Output Structure

GitCheck produces two types of outputs:

1. **Artefact Files** - Command output logs stored in the `.gitcheck/` folder
2. **Metrics File** - Computed quality scores in `metrics.json` that is automatically added as a git note named `gitcheck-metrics` to the evaluated commit

The metrics are computed by analyzing the contents of the artefact files and calculating various quality scores.

## Development

This project is currently in development. More details about setup and contribution guidelines will be added as the project grows.

## License

[License information to be added] 

## Metrics Phase

GitCheck supports a robust metrics phase for validating repository quality metrics. This phase is configured in your `gitcheck.yaml` and produces a `.gitcheck/metrics.json` summary.

### YAML Structure

Your `gitcheck.yaml` must include these top-level keys (even if empty):

```yaml
preflight: []
checks: []
metrics:
  # ... metrics definitions ...
```

#### Metrics Section
Each metric must have the following fields:
- `name`: Unique name for the metric.
- `command`: Shell command to run. The first line of its output is used as the metric value.
- `data_type`: `"number"` or `"string"`.
- `allowed_values`:
  - For `"number"`: List of ranges (e.g., `"0-1"`, `"10-20"`) and/or exact values (e.g., `"5"`).
  - For `"string"`: List of allowed string values.
- `default`: Value to use if the metric fails (must be in `allowed_values`).

**Example:**
```yaml
metrics:
  - name: "code_quality_score"
    command: "echo '0.85'"
    data_type: "number"
    allowed_values: ["0-1"]
    default: "0"
  - name: "build_status"
    command: "echo 'success'"
    data_type: "string"
    allowed_values: ["success", "warning", "failure"]
    default: "failure"
```

### Metrics Phase Behavior
- Each metric command is run in a subshell.
- The output is validated:
  - **Number**: Must fall within at least one allowed range or match an allowed value.
  - **String**: Must match one of the allowed values.
- If validation fails or the command errors, the `default` value is used in the summary.
- All results are written to `.gitcheck/metrics.json` with a `status` field:
  - `"pass"`: Metric passed validation.
  - `"default"`: Default value used due to failure.

**Example `metrics.json`:**
```json
[
  {
    "name": "code_quality_score",
    "value": "0.85",
    "allowed_values": ["0-1"],
    "status": "pass"
  },
  {
    "name": "build_status",
    "value": "failure",
    "allowed_values": ["success", "warning", "failure"],
    "status": "default"
  }
]
```

- The script exits with code 0 if all metrics pass, or 1 if any metric fails (uses default).

### Validation
- All required keys must be present in each metric.
- The `default` value must be valid (in the allowed range/set).
- If validation fails, the script prints an error and exits.

### Testing
- Comprehensive BATS tests cover all metrics scenarios: passing, failing, command errors, invalid defaults, decimals, and all-fail cases.

### Usage

```sh
./gitcheck --only=metrics
``` 