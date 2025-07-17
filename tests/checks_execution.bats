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
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "test_check"
    command: "echo 'check test'"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
}

# Helper function to create YAML with multi-line commands
create_multiline_yaml() {
    local filename="${1:-gitcheck.yaml}"
    cat > "$filename" << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "simple_check"
    command: "echo 'simple check'"
  - name: "multiline_check"
    command: |
      echo 'line 1'
      echo 'line 2'
      echo 'line 3'
  - name: "failing_check"
    command: "exit 1"
  - name: "successful_check"
    command: "echo 'success'"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
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
    [ -f ".gitcheck/simple_check" ]
    [ -f ".gitcheck/multiline_check" ]
    [ -f ".gitcheck/failing_check" ]
    [ -f ".gitcheck/successful_check" ]
}

@test "should include proper headers in artefact files" {
    create_valid_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check artefact file header
    run cat .gitcheck/test_check
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
    run cat .gitcheck/multiline_check
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
    [ -f ".gitcheck/failing_check" ]
}

@test "should capture both stdout and stderr in artefact files" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "stdout_stderr_test"
    command: "echo 'stdout message' && echo 'stderr message' >&2"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check that both stdout and stderr are captured
    run cat .gitcheck/stdout_stderr_test
    [ "$status" -eq 0 ]
    [[ "$output" == *"stdout message"* ]]
    [[ "$output" == *"stderr message"* ]]
}

@test "should handle empty checks section gracefully" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks: []
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Checks phase completed: 0/0 commands succeeded"* ]]
    
    # No artefact files should be created
    run ls .gitcheck/
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "should handle complex commands with special characters" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "complex_command"
    command: "echo 'test with spaces' && echo 'test with \"quotes\"' && echo 'test with $variables'"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check that complex command output is captured correctly
    run cat .gitcheck/complex_command
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
    [ -f ".gitcheck/test_check" ]
}

@test "should overwrite existing artefact files" {
    create_valid_yaml
    
    # Create an existing artefact file
    mkdir -p .gitcheck
    echo "old content" > .gitcheck/test_check
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # File should be overwritten with new content
    run cat .gitcheck/test_check
    [ "$status" -eq 0 ]
    [[ "$output" != *"old content"* ]]
    [[ "$output" == *"check test"* ]]
}

@test "should handle commands that produce no output" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "no_output"
    command: "true"
  - name: "empty_output"
    command: "echo ''"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Artefact files should exist even for commands with no output
    [ -f ".gitcheck/no_output" ]
    [ -f ".gitcheck/empty_output" ]
    
    # Files should contain headers even if no command output
    run cat .gitcheck/no_output
    [ "$status" -eq 0 ]
    [[ "$output" == *"# GitCheck Artefact: no_output"* ]]
    [[ "$output" == *"# Command: true"* ]]
} 