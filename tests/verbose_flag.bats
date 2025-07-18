#!/usr/bin/env bats

# Test verbose flag functionality

setup() {
    # Create a temporary directory for testing
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Copy the gitcheck script to test directory
    cp "$BATS_TEST_DIRNAME/../gitcheck" .
    chmod +x gitcheck
    
    # Initialize git repository for testing
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test file" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
}

# Helper function to create a minimal valid YAML file
create_valid_yaml() {
    local filename="${1:-gitcheck.yaml}"
    cat > "$filename" << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight output'"
checks:
  - name: "test_check"
    command: "echo 'check output'"
metrics:
  - name: "test_metric"
    command: "echo 'metric output'"
    data_type: "string"
    allowed_values: ["metric output"]
    default: "metric output"
EOF
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

@test "should suppress command output by default in preflight phase" {
    create_valid_yaml
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Preflight phase..."* ]]
    [[ "$output" == *"Running: test_preflight"* ]]
    [[ "$output" == *"✅ test_preflight: SUCCESS"* ]]
    # Should NOT contain the actual command output as a line
    ! grep -xq "preflight output" <<< "$output"
}

@test "should show command output with --verbose in preflight phase" {
    create_valid_yaml
    run ./gitcheck --only=preflight --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Preflight phase..."* ]]
    [[ "$output" == *"Running: test_preflight"* ]]
    [[ "$output" == *"✅ test_preflight: SUCCESS"* ]]
    # Should contain the actual command output
    [[ "$output" == *"preflight output"* ]]
}

@test "should suppress command output by default in checks phase" {
    create_valid_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Checks phase..."* ]]
    [[ "$output" == *"Running: test_check"* ]]
    [[ "$output" == *"✅ test_check: EXECUTED"* ]]
    # Should NOT contain the actual command output as a line
    ! grep -xq "check output" <<< "$output"
}

@test "should show command output with --verbose in checks phase" {
    create_valid_yaml
    run ./gitcheck --only=checks --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Checks phase..."* ]]
    [[ "$output" == *"Running: test_check"* ]]
    [[ "$output" == *"✅ test_check: EXECUTED"* ]]
    # Should contain the actual command output
    [[ "$output" == *"check output"* ]]
}

@test "should suppress command output by default in metrics phase" {
    create_valid_yaml
    run ./gitcheck --only=metrics
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Metrics phase..."* ]]
    [[ "$output" == *"Running metric: test_metric"* ]]
    [[ "$output" == *"✅ test_metric: PASS"* ]]
    # Should NOT contain the actual command output as a line
    ! grep -xq "metric output" <<< "$output"
}

@test "should show command output with --verbose in metrics phase" {
    create_valid_yaml
    run ./gitcheck --only=metrics --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Metrics phase..."* ]]
    [[ "$output" == *"Running metric: test_metric"* ]]
    [[ "$output" == *"✅ test_metric: PASS"* ]]
    # Should contain the actual command output
    [[ "$output" == *"metric output"* ]]
}

@test "should always create artefact files regardless of verbose setting" {
    create_valid_yaml
    
    # Test without verbose
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    [ -f ".gitcheck/checks/test_check" ]
    
    # Test with verbose
    run ./gitcheck --only=checks --verbose
    [ "$status" -eq 0 ]
    [ -f ".gitcheck/checks/test_check" ]
    
    # Both should have the same content in artefact file
    run cat .gitcheck/checks/test_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"check output"* ]]
}

@test "should handle multi-line output correctly with verbose" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'line 1' && echo 'line 2' && echo 'line 3'"
checks:
  - name: "test_check"
    command: "echo 'check line 1' && echo 'check line 2'"
metrics:
  - name: "test_metric"
    command: "echo 'metric line 1' && echo 'metric line 2'"
    data_type: "string"
    allowed_values: ["metric line 1"]
    default: "metric line 1"
EOF
    
    # Test preflight with verbose
    run ./gitcheck --only=preflight --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"line 1"* ]]
    [[ "$output" == *"line 2"* ]]
    [[ "$output" == *"line 3"* ]]
    
    # Test checks with verbose
    run ./gitcheck --only=checks --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"check line 1"* ]]
    [[ "$output" == *"check line 2"* ]]
    
    # Test metrics with verbose
    run ./gitcheck --only=metrics --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"metric line 1"* ]]
    [[ "$output" == *"metric line 2"* ]]
}

@test "should handle stderr output correctly with verbose" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'stdout message' && echo 'stderr message' >&2"
checks:
  - name: "test_check"
    command: "echo 'check stdout' && echo 'check stderr' >&2"
metrics:
  - name: "test_metric"
    command: "echo 'metric stdout' && echo 'metric stderr' >&2"
    data_type: "string"
    allowed_values: ["metric stdout"]
    default: "metric stdout"
EOF
    
    # Test preflight with verbose
    run ./gitcheck --only=preflight --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"stdout message"* ]]
    [[ "$output" == *"stderr message"* ]]
    
    # Test checks with verbose
    run ./gitcheck --only=checks --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"check stdout"* ]]
    [[ "$output" == *"check stderr"* ]]
    
    # Test metrics with verbose
    run ./gitcheck --only=metrics --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"metric stdout"* ]]
    [[ "$output" == *"metric stderr"* ]]
}

@test "should work with all phases when no --only specified" {
    create_valid_yaml
    
    # Test without verbose
    run ./gitcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Preflight phase..."* ]]
    [[ "$output" == *"Running Checks phase..."* ]]
    [[ "$output" == *"Running Metrics phase..."* ]]
    # Should NOT contain command outputs
    [[ "$output" != *"preflight output"* ]]
    [[ "$output" != *"check output"* ]]
    [[ "$output" != *"metric output"* ]]
    
    # Test with verbose
    run ./gitcheck --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running Preflight phase..."* ]]
    [[ "$output" == *"Running Checks phase..."* ]]
    [[ "$output" == *"Running Metrics phase..."* ]]
    # Should contain command outputs
    [[ "$output" == *"preflight output"* ]]
    [[ "$output" == *"check output"* ]]
    [[ "$output" == *"metric output"* ]]
}

@test "should show verbose setting in configuration display" {
    create_valid_yaml
    
    # Test without verbose
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Verbose: false"* ]]
    
    # Test with verbose
    run ./gitcheck --only=validate --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"Verbose: true"* ]]
}

@test "should handle commands that produce no output with verbose" {
    cat > gitcheck.yaml << EOF
preflight:
  - name: "test_preflight"
    command: "true"
checks:
  - name: "test_check"
    command: "echo ''"
metrics:
  - name: "test_metric"
    command: "true"
    data_type: "string"
    allowed_values:
      - ""
    default: ""
EOF
    
    # Test without verbose - should still show status messages
    run ./gitcheck --only=checks
    if [ "$status" -ne 0 ]; then
      echo "DEBUG: status=$status output=$output"
    fi
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running: test_check"* ]]
    [[ "$output" == *"✅ test_check: EXECUTED"* ]]
    
    # Test with verbose - should show empty output (i.e., a blank line after 'Saving output to: ...')
    run ./gitcheck --only=checks --verbose
    if [ "$status" -ne 0 ]; then
      echo "DEBUG: status=$status output=$output"
    fi
    [ "$status" -eq 0 ]
    [[ "$output" == *"Running: test_check"* ]]
    [[ "$output" == *"✅ test_check: EXECUTED"* ]]
    # Should show an empty line after the command runs
    [[ "$output" =~ "Saving output to: .gitcheck/checks/test_check"$'\n'$'\n' ]]
} 