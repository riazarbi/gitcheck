#!/usr/bin/env bats

# Test checks phase execution functionality

setup() {
    # Create a temporary directory for testing
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Copy the gitcheck script to test directory
    cp "$BATS_TEST_DIRNAME/../gitcheck" .
    chmod +x gitcheck
    
    # Initialize git repository for testing
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "test file" > test.txt
    git add test.txt
    git commit -m "Initial commit"
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create a minimal valid YAML file
create_valid_yaml() {
    local filename="${1:-gitcheck.yaml}"
    cat > "$filename" << 'EOF'
preflight:
  test_preflight:
    cmd: echo 'preflight test'
checks:
  test_check:
    cmd: echo 'check test'
metrics:
  test_metric:
    cmd: echo 'metric test'
    data_type: string
    allowed_values: ["test"]
    default: "test"
EOF
}

# Helper function to create YAML with multi-line commands
create_multiline_yaml() {
    local filename="${1:-gitcheck.yaml}"
    cat > "$filename" << 'EOF'
preflight:
  test_preflight:
    cmd: echo 'preflight test'
checks:
  simple_check:
    cmd: echo 'simple check'
  multiline_check:
    cmd: |
      echo 'line 1'
      echo 'line 2'
      echo 'line 3'
  failing_check:
    cmd: exit 1
  successful_check:
    cmd: echo 'success'
metrics:
  test_metric:
    cmd: echo 'metric test'
    data_type: string
    allowed_values: ["test"]
    default: "test"
EOF
}

@test "should execute all checks and create artefact files" {
    create_multiline_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]  # All checks executed successfully (even failing_check)
    [[ "$output" == *"Running Checks phase..."* ]]
    [[ "$output" == *"Running: simple_check"* ]]
    [[ "$output" == *"Running: multiline_check"* ]]
    [[ "$output" == *"Running: failing_check"* ]]
    [[ "$output" == *"Running: successful_check"* ]]
    [[ "$output" == *"Checks phase completed:"* ]]
    
    # Check that artefact files were created
    [ -f ".gitcheck/checks/simple_check" ]
    [ -f ".gitcheck/checks/multiline_check" ]
    [ -f ".gitcheck/checks/failing_check" ]
    [ -f ".gitcheck/checks/successful_check" ]
}

@test "should include proper headers in artefact files" {
    create_valid_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check artefact file header
    run cat .gitcheck/checks/test_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"# GitCheck Artefact: test_check"* ]]
    [[ "$output" == *"# Generated:"* ]]
    [[ "$output" == *"# Command: echo 'check test'"* ]]
    [[ "$output" == *"# Phase: Checks"* ]]
    [[ "$output" == *"check test"* ]]
}

@test "should handle multi-line commands correctly" {
    create_multiline_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]  # All checks executed successfully
    
    # Check that multi-line command output is captured
    run cat .gitcheck/checks/multiline_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"line 1"* ]]
    [[ "$output" == *"line 2"* ]]
    [[ "$output" == *"line 3"* ]]
}

@test "should continue execution even when commands fail" {
    create_multiline_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]  # All checks executed successfully
    
    # Should show execution status (all executed, even with non-zero exit codes)
    [[ "$output" == *"✅ simple_check: EXECUTED"* ]]
    [[ "$output" == *"✅ multiline_check: EXECUTED"* ]]
    [[ "$output" == *"✅ failing_check: EXECUTED"* ]]
    [[ "$output" == *"✅ successful_check: EXECUTED"* ]]
    
    # All artefact files should exist, even for commands with non-zero exit codes
    [ -f ".gitcheck/checks/failing_check" ]
}

@test "should capture both stdout and stderr in artefact files" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  test_preflight:
    cmd: echo 'preflight test'
checks:
  stdout_stderr_test:
    cmd: echo 'stdout message' && echo 'stderr message' >&2
metrics:
  test_metric:
    cmd: echo 'metric test'
    data_type: string
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check that both stdout and stderr are captured
    run cat .gitcheck/checks/stdout_stderr_test
    [ "$status" -eq 0 ]
    [[ "$output" == *"stdout message"* ]]
    [[ "$output" == *"stderr message"* ]]
}

@test "should handle empty checks section gracefully" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  test_preflight:
    cmd: echo 'preflight test'
checks: {}
metrics:
  test_metric:
    cmd: echo 'metric test'
    data_type: string
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Checks phase completed: 0/0 commands succeeded"* ]]
    
    # No artefact files should be created - directory should not exist
    run ls .gitcheck/ 2>/dev/null
    [ "$status" -ne 0 ]  # Should fail because directory doesn't exist
}

@test "should handle complex commands with special characters" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  test_preflight:
    cmd: echo 'preflight test'
checks:
  complex_command:
    cmd: echo 'test with spaces' && echo 'test with "quotes"' && echo 'test with $variables'
metrics:
  test_metric:
    cmd: echo 'metric test'
    data_type: string
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check that complex command output is captured correctly
    run cat .gitcheck/checks/complex_command
    [ "$status" -eq 0 ]
    [[ "$output" == *"test with spaces"* ]]
    [[ "$output" == *"test with \"quotes\""* ]]
    [[ "$output" == *"test with \$variables"* ]]
}

@test "should provide accurate success/failure counts" {
    create_multiline_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]  # All checks executed successfully
    
    # Should show correct counts (all 4 executed successfully)
    [[ "$output" == *"Checks phase completed: 4/4 commands succeeded"* ]]
}

@test "should create .gitcheck directory if it doesn't exist" {
    create_valid_yaml
    rm -rf .gitcheck 2>/dev/null || true
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Directory should be created
    [ -d ".gitcheck" ]
    [ -f ".gitcheck/checks/test_check" ]
}

@test "should overwrite existing artefact files" {
    create_valid_yaml
    
    # Create an existing artefact file
    mkdir -p .gitcheck/checks
    echo "old content" > .gitcheck/checks/test_check
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # File should be overwritten with new content
    run cat .gitcheck/checks/test_check
    [ "$status" -eq 0 ]
    [[ "$output" != *"old content"* ]]
    [[ "$output" == *"check test"* ]]
}

@test "should handle commands that produce no output" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  test_preflight:
    cmd: echo 'preflight test'
checks:
  no_output:
    cmd: "true"
  empty_output:
    cmd: echo ''
metrics:
  test_metric:
    cmd: echo 'metric test'
    data_type: string
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Artefact files should exist even for commands with no output
    [ -f ".gitcheck/checks/no_output" ]
    [ -f ".gitcheck/checks/empty_output" ]
    
    # Files should contain headers even if no command output
    run cat .gitcheck/checks/no_output
    [ "$status" -eq 0 ]
    [[ "$output" == *"# GitCheck Artefact: no_output"* ]]
    [[ "$output" == *"# Command: true"* ]]
} 