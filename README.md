# GitCheck

A robust bash tool for evaluating code repository quality using a mandatory `gitcheck.yaml` configuration file. GitCheck runs commands against a specified commit hash (or latest if unspecified), producing artefact files and a `metrics.json` file stored as a git note.

## Features

- **Three-phase execution**: Preflight, Checks, and Metrics phases
- **YAML configuration**: Structured configuration with validation
- **Artefact generation**: Captures command output in `.gitcheck/` directory
- **Metrics validation**: Supports numeric ranges and string sets with default values
- **Timeout handling**: Configurable timeouts for long-running commands
- **Verbose output**: Optional detailed command output display
- **Git integration**: Works with specific commits, branches, or latest commit
- **Comprehensive testing**: 149+ BATS tests covering all functionality

## Installation

GitCheck is written in bash, and uses as few system dependencies as possible in order to maximise portability.

### Prerequisites

GitCheck requires the following system dependencies:
- `bash` (version 4.0+)
- `git`
- `yq` (for YAML parsing)
- `jq` (for JSON processing)
- `bc` (for decimal arithmetic)

Dependencies used in your checks can be declared in the preflight section of your configuration file.

### Setup

1. Clone or download the `gitcheck` script
2. Make it executable: `chmod +x gitcheck`
3. Add it to your $PATH, either by altering your shell config file (eg. `~/.bashrc`), or copying it to your executible folder (eg. /usr/bin/)
3. Ensure all dependencies are installed. GitCheck will tell you if any are missing, and refuse to run.

## Usage

```bash
cd [PROJECT GIT REPO]
# create valid gitcheck.yaml file
gitcheck
```

Run `gitcheck --help` for more detailed usage guidance

## Configuration

GitCheck executes commands specified in a mandatory `gitcheck.yaml` configuration file and saves each STDOUT to a file in the `.gitcheck/` folder. These files are referred to as 'artefacts'.

Before execution, GitCheck validates your configuration file:
- All required fields must be present
- Default values must be within allowed ranges/sets
- YAML syntax must be valid
- Commands must be properly formatted

A valid configuration file has three main sections:


### Preflight Section

Commands that must succeed before proceeding. Used for environment validation, dependency checks, etc.

```yaml
preflight:
  - name: "check_git_status"
    command: "git status --porcelain"
  - name: "validate_environment"
    command: |
      echo "Checking environment..."
      echo "Python version: $(python --version)"
      echo "Node version: $(node --version)"
```

### Checks Section

Commands that analyze the codebase. These are executed regardless of exit code (non-zero indicates issues found).

```yaml
checks:
  - name: "lint_code"
    command: "eslint src/"
  - name: "run_tests"
    command: "npm test"
  - name: "security_scan"
    command: "npm audit"
  - name: "complexity_analysis"
    command: |
      echo "Analyzing code complexity..."
      find src/ -name "*.js" -exec wc -l {} +
```

### Metrics Section

Commands that produce measurable values, validated against allowed ranges or sets.

```yaml
metrics:
  - name: "test_coverage"
    command: "npm run coverage | grep 'All files' | awk '{print $4}' | sed 's/%//'"
    data_type: "number"
    allowed_values: ["80-100"]
    default: "75"
  - name: "code_quality"
    command: "echo 'excellent'"
    data_type: "string"
    allowed_values: ["poor", "fair", "good", "excellent"]
    default: "fair"
  - name: "maintainability_index"
    command: "echo '85.5'"
    data_type: "number"
    allowed_values: ["0-100"]
    default: "50"
```


## Output and Artefacts

Gitcheck outputs all artefacts to the `.gitcheck/` folder. Each artefact file name is detemrined by the `name` key of the corresponding command in the configuration file. 

### Example Directory Structure

```
.gitcheck/
├── preflight_command_name    # Preflight command outputs
├── checks_command_name       # Checks command outputs
├── metrics/
│   └── metric_name          # Metrics command outputs
└── metrics.json             # Summary of all metrics
```

### Artefact Files

Each command output is saved with headers:
```
# GitCheck Artefact: command_name
# Generated: Thu 17 Jul 2025 22:15:27 SAST
# Command: echo 'test'
# Phase: Checks
# =========================================

command output here...
```

### Metrics JSON

The `metrics.json` file is created after all commands in the configuration file have been run, and simply contains contains all the contents of the `.gitcheck/metrics/` folder as a json object:
```json
[
  {
    "name": "test_coverage",
    "value": "85",
    "allowed_values": ["80-100"],
    "status": "pass"
  },
  {
    "name": "code_quality",
    "value": "excellent",
    "allowed_values": ["poor", "fair", "good", "excellent"],
    "status": "pass"
  }
]
```

## Data Types and Validation

### Numeric Metrics

- **Ranges**: `"1-100"`, `"0.5-1.0"`
- **Exact values**: `"42"`, `"3.14159"`
- **Decimal support**: Uses `bc` for precise floating-point comparison

### String Metrics

- **Exact sets**: `["poor", "fair", "good", "excellent"]`
- **Case-sensitive matching**

### Validation Examples

```yaml
metrics:
  - name: "coverage"
    command: "echo '85.5'"
    data_type: "number"
    allowed_values: ["80-100"]        # Range
    default: "75"
  
  - name: "score"
    command: "echo '42'"
    data_type: "number"
    allowed_values: ["0", "42", "100"] # Exact values
    default: "0"
  
  - name: "quality_grade"
    command: "echo 'A'"
    data_type: "string"
    allowed_values: ["A", "B", "C", "D", "F"]
    default: "C"
```

### Default Values

- Used when commands fail or produce invalid output
- Must be within allowed ranges/sets
- Ensure graceful degradation

## Error Handling

### Exit Codes

- `0`: All phases completed successfully
- `1`: One or more preflight commands failed
- `2`: Configuration or validation errors
- `3`: Git repository issues

### Timeout Handling

- Commands exceeding timeout are terminated
- Timeout messages are written to artefact files
- Default timeout: 300 seconds (configurable)

### Graceful Degradation

- Checks phase continues even if individual commands fail
- Metrics use default values when commands fail
- Artefact files are always created

## Examples

### Basic Quality Check

```yaml
# gitcheck.yaml
preflight:
  - name: "check_clean_working_dir"
    command: "git status --porcelain | wc -l"

checks:
  - name: "run_linter"
    command: "npm run lint"
  - name: "run_tests"
    command: "npm test"
  - name: "check_security"
    command: "npm audit --audit-level=moderate"

metrics:
  - name: "test_coverage"
    command: "npm run test:coverage"
    data_type: "number"
    allowed_values: ["80-100"]
    default: "75"
  - name: "code_quality_score"
    command: "echo '85'"
    data_type: "number"
    allowed_values: ["0-100"]
    default: "50"
```

### Language-Specific Examples

#### JavaScript/Node.js Project

```yaml
preflight:
  - name: "check_node_version"
    command: "node --version"
  - name: "check_clean_working_dir"
    command: "git status --porcelain | wc -l"

checks:
  - name: "install_dependencies"
    command: "npm ci"
  - name: "lint_code"
    command: "npm run lint"
  - name: "type_check"
    command: "npm run type-check"
  - name: "unit_tests"
    command: "npm test"
  - name: "security_audit"
    command: "npm audit --audit-level=moderate"
  - name: "build_project"
    command: "npm run build"

metrics:
  - name: "test_coverage"
    command: "npm run test:coverage | grep 'All files' | awk '{print $4}' | sed 's/%//'"
    data_type: "number"
    allowed_values: ["80-100"]
    default: "75"
  - name: "code_quality_score"
    command: "echo '85'"
    data_type: "number"
    allowed_values: ["0-100"]
    default: "50"
```

#### Python Project

```yaml
preflight:
  - name: "check_python_version"
    command: "python --version"
  - name: "check_clean_working_dir"
    command: "git status --porcelain | wc -l"

checks:
  - name: "install_dependencies"
    command: "pip install -r requirements.txt"
  - name: "lint_code"
    command: "flake8 src/"
  - name: "type_check"
    command: "mypy src/"
  - name: "unit_tests"
    command: "pytest tests/unit/"
  - name: "security_scan"
    command: "bandit -r src/"

metrics:
  - name: "test_coverage"
    command: "pytest --cov=src --cov-report=term-missing | grep 'TOTAL' | awk '{print $4}' | sed 's/%//'"
    data_type: "number"
    allowed_values: ["80-100"]
    default: "75"
```


### CI/CD Integration

```bash
#!/bin/bash
# ci-quality-check.sh

# Run GitCheck
./gitcheck --verbose --timeout=600

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Quality check passed"
    exit 0
else
    echo "❌ Quality check failed"
    # Upload artefacts to CI system
    tar -czf gitcheck-artefacts.tar.gz .gitcheck/
    exit 1
fi
```

### Advanced Configuration

```yaml
# gitcheck.yaml
preflight:
  - name: "validate_environment"
    command: |
      echo "Validating environment..."
      python --version
      node --version
      npm --version
      echo "Environment OK"

checks:
  - name: "code_style"
    command: "prettier --check 'src/**/*.{js,ts}'"
  - name: "type_check"
    command: "tsc --noEmit"
  - name: "unit_tests"
    command: "npm run test:unit"
  - name: "integration_tests"
    command: "npm run test:integration"
  - name: "security_scan"
    command: "npm audit --audit-level=high"
  - name: "dependency_check"
    command: "npm outdated"

metrics:
  - name: "test_coverage"
    command: "npm run test:coverage | grep 'All files' | awk '{print $4}' | sed 's/%//'"
    data_type: "number"
    allowed_values: ["90-100"]
    default: "80"
  - name: "maintainability_index"
    command: "echo '85.5'"
    data_type: "number"
    allowed_values: ["0-100"]
    default: "50"
  - name: "code_quality_grade"
    command: "echo 'A'"
    data_type: "string"
    allowed_values: ["A", "B", "C", "D", "F"]
    default: "C"
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `Error: 'gitcheck.yaml' is not a valid YAML file` | Check YAML syntax, indentation, escape sequences |
| `command not found: yq` | Install dependencies: `brew install yq jq bc` |
| `Error: Not a git repository` | Run `git init` and commit files |
| `Permission denied: .gitcheck/` | Create directory: `mkdir -p .gitcheck` |
| `⏰ command_name: TIMEOUT` | Increase timeout: `--timeout=600` |
| `Error: Metrics command has default value not in allowed_values` | Fix default value to be within allowed range |

### Debug Commands

```bash
# Check YAML syntax
yq eval '.' gitcheck.yaml

# Test command manually
bash -c "your_command_here"

# Check git status
git status

# Validate configuration
./gitcheck --only=validate --verbose
```

### Performance Tips

```bash
# Use shorter timeouts for fast feedback
./gitcheck --timeout=60

# Run only specific phases during development
./gitcheck --only=checks

# Use verbose mode for debugging
./gitcheck --verbose
```

## Testing

GitCheck includes comprehensive BATS tests:

```bash
# Run all tests
bats tests/

# Run specific test suite
bats tests/validation.bats
bats tests/metrics_phase.bats
bats tests/verbose_flag.bats
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the GNU General Public License v3.0 (GPL v3).

### What this means:

- **Freedom to use**: You can use GitCheck for any purpose
- **Freedom to study**: You can examine the source code
- **Freedom to share**: You can distribute copies
- **Freedom to modify**: You can change the code

### Copyleft requirements:

- If you distribute GitCheck (or modified versions), you must share the source code
- If you link GitCheck with other GPL v3 code, the combined work must also be GPL v3
- You must include a copy of the GPL v3 license with any distribution

### Full license text:

The complete GPL v3 license text is included in the [LICENSE](LICENSE) file.

For more information about GPL v3, see: https://www.gnu.org/licenses/gpl-3.0.html

