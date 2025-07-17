#!/usr/bin/env bats

# Test timeout functionality

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
  - name: "slow_check"
    command: "sleep 3 && echo 'slow output'"
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

@test "should use default timeout of 300 seconds" {
    create_valid_yaml
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Timeout: 300s"* ]]
}

@test "should accept custom timeout value" {
    create_valid_yaml
    run ./gitcheck --only=checks --timeout=60
    [ "$status" -eq 0 ]
    [[ "$output" == *"Timeout: 60s"* ]]
}

@test "should reject invalid timeout values" {
    create_valid_yaml
    run ./gitcheck --only=checks --timeout=0
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Timeout must be a positive integer"* ]]
}

@test "should reject non-numeric timeout values" {
    create_valid_yaml
    run ./gitcheck --only=checks --timeout=abc
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Timeout must be a positive integer"* ]]
}

@test "should timeout long-running commands in checks phase" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "fast_check"
    command: "echo 'fast output'"
  - name: "slow_check"
    command: "sleep 5 && echo 'slow output'"
EOF
    
    run ./gitcheck --only=checks --timeout=2
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ fast_check: EXECUTED"* ]]
    [[ "$output" == *"⏰ slow_check: TIMEOUT (exceeded 2s)"* ]]
}

@test "should timeout long-running commands in preflight phase" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "fast_preflight"
    command: "echo 'fast output'"
  - name: "slow_preflight"
    command: "sleep 5 && echo 'slow output'"
EOF
    
    run ./gitcheck --only=preflight --timeout=2
    [ "$status" -eq 1 ]
    [[ "$output" == *"✅ fast_preflight: SUCCESS"* ]]
    [[ "$output" == *"⏰ slow_preflight: TIMEOUT (exceeded 2s)"* ]]
}

@test "should timeout long-running commands in metrics phase" {
    cat > gitcheck.yaml << 'EOF'
metrics:
  - name: "fast_metric"
    command: "echo 'fast output'"
    data_type: "string"
    allowed_values: ["fast output"]
    default: "fast output"
  - name: "slow_metric"
    command: "sleep 5 && echo 'slow output'"
    data_type: "string"
    allowed_values: ["slow output", "timeout_value"]
    default: "timeout_value"
EOF
    
    run ./gitcheck --only=metrics --timeout=2
    [ "$status" -eq 1 ]
    [[ "$output" == *"✅ fast_metric: PASS"* ]]
    [[ "$output" == *"⏰ slow_metric: TIMEOUT (exceeded 2s)"* ]]
}

@test "should write timeout message to artefact files" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "slow_check"
    command: "sleep 5 && echo 'slow output'"
EOF
    
    run ./gitcheck --only=checks --timeout=2
    [ "$status" -eq 0 ]
    
    # Check that timeout message is written to artefact file
    run cat .gitcheck/slow_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"TIMEOUT: Command exceeded 2s timeout"* ]]
}

@test "should handle timeout with verbose output" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "slow_check"
    command: "sleep 5 && echo 'slow output'"
EOF
    
    run ./gitcheck --only=checks --timeout=2 --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"⏰ slow_check: TIMEOUT (exceeded 2s)"* ]]
    # Should show command details in verbose mode
    [[ "$output" == *"Command: sleep 5 && echo 'slow output'"* ]]
}

@test "should process all checks even after timeout" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "fast_check1"
    command: "echo 'fast1'"
  - name: "slow_check"
    command: "sleep 5 && echo 'slow output'"
  - name: "fast_check2"
    command: "echo 'fast2'"
EOF
    
    run ./gitcheck --only=checks --timeout=2
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ fast_check1: EXECUTED"* ]]
    [[ "$output" == *"⏰ slow_check: TIMEOUT (exceeded 2s)"* ]]
    [[ "$output" == *"✅ fast_check2: EXECUTED"* ]]
    [[ "$output" == *"Checks phase completed: 3/3 commands succeeded"* ]]
}

@test "should handle timeout in metrics with default values" {
    cat > gitcheck.yaml << 'EOF'
metrics:
  - name: "slow_metric"
    command: "sleep 5 && echo 'slow output'"
    data_type: "string"
    allowed_values: ["slow output", "timeout_value"]
    default: "timeout_value"
EOF
    
    run ./gitcheck --only=metrics --timeout=2
    [ "$status" -eq 1 ]
    [[ "$output" == *"⏰ slow_metric: TIMEOUT (exceeded 2s)"* ]]
    
    # Check that metrics.json contains default value
    run cat .gitcheck/metrics.json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"value": "timeout_value"'* ]]
    [[ "$output" == *'"status": "default"'* ]]
}

@test "should handle multiple timeouts in same phase" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "fast_check"
    command: "echo 'fast'"
  - name: "slow_check1"
    command: "sleep 5 && echo 'slow1'"
  - name: "slow_check2"
    command: "sleep 5 && echo 'slow2'"
EOF
    
    run ./gitcheck --only=checks --timeout=2
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ fast_check: EXECUTED"* ]]
    [[ "$output" == *"⏰ slow_check1: TIMEOUT (exceeded 2s)"* ]]
    [[ "$output" == *"⏰ slow_check2: TIMEOUT (exceeded 2s)"* ]]
    [[ "$output" == *"Checks phase completed: 3/3 commands succeeded"* ]]
}

@test "should work with very short timeouts" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "fast_check"
    command: "echo 'fast'"
EOF
    
    run ./gitcheck --only=checks --timeout=1
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ fast_check: EXECUTED"* ]]
}

@test "should handle timeout with complex commands" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "complex_slow"
    command: "sleep 5 && echo 'complex' && echo 'output'"
EOF
    
    run ./gitcheck --only=checks --timeout=2
    [ "$status" -eq 0 ]
    [[ "$output" == *"⏰ complex_slow: TIMEOUT (exceeded 2s)"* ]]
} 