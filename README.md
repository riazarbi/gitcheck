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