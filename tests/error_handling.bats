#!/usr/bin/env bats

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    cp "$BATS_TEST_DIRNAME/../gitcheck" .
    chmod +x gitcheck
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
    echo "test file" > test.txt
    git add test.txt
    git commit -m "Initial commit"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "should fail with invalid YAML syntax" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
invalid: yaml: syntax: here
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a valid YAML file"* ]]
}

@test "should fail with malformed YAML structure" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
# Missing metrics section entirely
EOF
    
    run ./gitcheck --only=metrics
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing required key 'metrics'"* ]]
}

@test "should fail with empty YAML file" {
    echo "" > gitcheck.yaml
    
    run ./gitcheck --only=checks
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a valid YAML file"* ]] || [[ "$output" == *"Missing required key"* ]]
}

@test "should fail with YAML containing only comments" {
    cat > gitcheck.yaml << 'EOF'
# This is a comment
# Another comment
# No actual content
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing required key"* ]]
}

@test "should handle file permission errors gracefully" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    # Create .gitcheck as a file instead of directory
    echo "not a directory" > .gitcheck
    
    run ./gitcheck --only=checks
    [ "$status" -eq 1 ]  # Should fail due to file conflict
}

@test "should fail with invalid commit hash" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --commit invalid-commit-hash
    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist or is not a commit"* ]]
}

@test "should handle commands that fail to execute" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "nonexistent_command"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 1 ]
    [[ "$output" == *"FAILED"* ]]
}

@test "should handle commands that produce no output" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "true"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUCCESS"* ]]
}

@test "should handle commands with special characters" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test with spaces and quotes and variables'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUCCESS"* ]]
}

@test "should handle very long command names" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "very_long_command_name_that_exceeds_normal_length_limits_and_tests_edge_cases_for_command_naming_conventions"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUCCESS"* ]]
}

@test "should handle unicode characters in commands" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test with unicode: 🚀 📊 ✅'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUCCESS"* ]]
}

@test "should fail with invalid timeout values" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --timeout=0
    [ "$status" -eq 1 ]
    [[ "$output" == *"Timeout must be a positive integer"* ]]
    
    run ./gitcheck --timeout=-1
    [ "$status" -eq 1 ]
    [[ "$output" == *"Timeout must be a positive integer"* ]]
    
    run ./gitcheck --timeout=abc
    [ "$status" -eq 1 ]
    [[ "$output" == *"Timeout must be a positive integer"* ]]
}

@test "should handle missing config file" {
    run ./gitcheck --config nonexistent.yaml
    [ "$status" -eq 1 ]
    [[ "$output" == *"is not a valid YAML file"* ]]
}

@test "should handle relative config file paths" {
    mkdir -p subdir
    cat > subdir/config.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    run ./gitcheck --config subdir/config.yaml --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"SUCCESS"* ]]
} 