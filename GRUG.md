# GRUG PLAN: Replace gitcheck complexity with Task tool

## USER STORY (why grug do this)
User have gitcheck tool with 830 lines of complex bash that fight complexity demon. User want simpler tool that do same thing but less complexity. User suggest maybe replace with Taskfile or Makefile. Grug analyze and decide hybrid approach: keep gitcheck.yaml format (good for quality assessment) but replace complex bash execution with simple Task tool calls.

## BEFORE STARTING - REFRESH GRUG BRAIN
1. **Read https://grugbrain.dev** - reset grug persona to fight complexity demon
2. **Read https://taskfile.dev/usage/** - refresh memory of Task capabilities 

## ANALYSIS RESULTS

### COMPLEXITY DEMON LOCATIONS IN CURRENT GITCHECK:
- 830 lines of bash complexity!
- Complex YAML validation with many edge cases  
- Sophisticated number range parsing (`1.5-2.5` type ranges)
- Complex timeout and error handling logic
- Artefact file management with headers
- JSON generation complexity

### WHAT MUST PRESERVE (from tests):
**Command Line Interface:**
- `gitcheck --config|-c <file>`
- `gitcheck --commit|-C <hash>` 
- `gitcheck --only=PHASE` (validate|preflight|checks|metrics)
- `gitcheck --verbose` 
- `gitcheck --timeout=N`
- `gitcheck --help|-h`

**File Structure:**
- `.gitcheck/preflight/command_name`
- `.gitcheck/checks/command_name` 
- `.gitcheck/metrics/command_name`
- `.gitcheck/metrics.json`

**Artefact File Format:**
```
# GitCheck Phase: name
# Generated: date
# Command: command 
# Allowed values: values
# Phase: Phase
# =========================================

command output here...
```

**Metrics JSON Format:**
```json
[{"name": "test", "value": "5", "allowed_values": ["1-10"], "status": "pass"}]
```

**Behavior Contracts:**
- Exit codes: 0=success, 1=failures, 2=config errors
- Timeout handling with 124 exit code
- Default value substitution when command fails/invalid
- Validation of metrics against allowed_values 
- Only first line of command output used for metrics

## NEW ARCHITECTURE DESIGN

```
gitcheck (simplified bash wrapper ~150 lines)
├── 1. Parse arguments & validate 
├── 2. Generate Taskfile from gitcheck.yaml
├── 3. Execute: echo "$taskfile" | task --taskfile -
├── 4. Collect outputs & validate metrics  
└── 5. Generate metrics.json

Generated Taskfile structure:
├── preflight (main task with deps)
├── checks (main task with deps) 
├── metrics (main task with deps)
└── Individual tasks for each command
```

### Generated Taskfile Example:
```yaml
version: '3'
vars:
  TIMEOUT: {{.TIMEOUT}}
  VERBOSE: {{.VERBOSE}}

tasks:
  preflight:
    desc: "Preflight phase"
    deps: [preflight_shellcheck, preflight_bats]
    
  preflight_shellcheck:
    cmds:
      - mkdir -p .gitcheck/preflight
      - |
        {
          echo "# GitCheck Preflight Artefact: shellcheck"
          echo "# Generated: $(date)"
          echo "# Command: which shellcheck..."
          echo "# ========================================="
          echo ""
          timeout {{.TIMEOUT}} bash -c 'which shellcheck || (echo "ShellCheck not found..." && exit 1)'
        } > .gitcheck/preflight/shellcheck 2>&1

  metrics:
    desc: "Metrics phase" 
    deps: [metric_test_coverage, metric_lines_of_code]
    
  metric_test_coverage:
    cmds:
      - mkdir -p .gitcheck/metrics
      - |
        {
          echo "# GitCheck Metrics Artefact: test_coverage"
          echo "# Generated: $(date)" 
          echo "# Command: echo \"85\""
          echo "# Allowed values: [\"0-100\"]"
          echo "# ========================================="
          echo ""
          timeout {{.TIMEOUT}} bash -c 'echo "85"'
        } > .gitcheck/metrics/test_coverage 2>&1
```

## WHAT MOVES TO TASKFILE vs STAYS IN BASH

### CAN MOVE TO TASKFILE:
**Command Execution:**
- Running shell commands with timeout (Taskfile has built-in timeout)
- Output redirection to files (Taskfile handles this better)
- Cross-platform execution (Taskfile strength)
- Dependency management between phases (Task deps)
- Parallel execution within phases

**Error Handling:**
- Command failure detection (Task handles exit codes)
- Stdout/stderr capture (Task output handling)

### STAYS IN BASH WRAPPER:
**Configuration:**
- YAML parsing with yq
- Argument processing and validation
- gitcheck.yaml format validation
- Commit hash resolution

**Taskfile Generation:**
- Convert gitcheck.yaml -> Taskfile YAML
- Inject artefact file headers
- Add timeout and output redirection

**Metrics Processing:**
- Validate metric values against allowed_values/data_type
- Generate metrics.json 
- Handle graceful degradation with defaults

## DETAILED IMPLEMENTATION PLAN

### Phase 1: Create Taskfile Generator Function
1. **Function: `generate_taskfile_from_yaml()`**
   - Input: gitcheck.yaml path, timeout, verbose flag
   - Parse sections with yq: preflight, checks, metrics  
   - Generate Taskfile YAML with proper templating
   - Include artefact headers in each task command
   - Handle timeout and output redirection

### Phase 2: Simplify Main Script Structure
1. **Keep existing argument processing** (tests depend on exact CLI)
2. **Keep existing YAML validation** (critical for user experience)
3. **Replace `execute_yaml_section()` with:**
   ```bash
   generate_taskfile_from_yaml "$CONFIG_FILE" "$TIMEOUT" "$VERBOSE" | task --taskfile - "$phase"
   ```

### Phase 3: Preserve Metrics Processing 
1. **Keep `validate_metric_result()` function** (complex logic, tests depend on it)
2. **Keep `execute_metrics_phase()` flow but simplify execution:**
   - Generate Taskfile for metrics  
   - Run via Task
   - Read output files and validate
   - Generate metrics.json

### Phase 4: Test Compatibility
1. **Run existing BATS tests** to ensure no regression
2. **Key test files to verify:**
   - `argument_processing.bats` (CLI compatibility)
   - `metrics_phase.bats` (metrics validation)
   - `timeout_functionality.bats` (timeout handling)
   - `integration.bats` (end-to-end workflow)

### Phase 5: Code Size Reduction
**Remove these complex functions (save ~400 lines):**
- `run_command_with_timeout()` - Task handles this
- `execute_yaml_section()` - Replace with Task execution
- Complex timeout and output handling - Task handles this
- Most error handling logic - Task provides better error handling

**Keep these essential functions (~150 lines total):**
- Argument processing and validation
- YAML configuration validation  
- `generate_taskfile_from_yaml()` (new)
- Metrics validation and JSON generation
- Main execution flow

### Implementation Steps:
1. **Backup current gitcheck** as `gitcheck.bak`
2. **Create `generate_taskfile_from_yaml()` function**
3. **Replace execution logic** with Task calls
4. **Run tests iteratively** to ensure compatibility
5. **Remove unused functions** once tests pass

## EXPECTED RESULTS

**Expected Result:**
- ~150 line bash script (vs 830 lines)
- All tests continue to pass
- Better cross-platform support via Task
- Simpler maintenance and debugging

**Key Benefits:**
- Task handles cross-platform execution, dependencies, timeout
- Bash wrapper stays focused on gitcheck-specific logic
- Generated Taskfile preserves exact artefact format 
- All tests continue to pass with same external behavior
- 80% less bash complexity
- Fight complexity demon with simple tools doing what they good at

## GRUG WISDOM
- Keep gitcheck.yaml format (designed for quality assessment, very good)
- Use Task for what Task good at (command execution)  
- Use bash for what bash good at (gitcheck-specific logic)
- Preserve all test contracts (users depend on behavior)
- Generate Taskfile on-the-fly (no need to maintain two config formats)
- Simple tools doing simple things = grug happy