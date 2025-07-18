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

@test "should handle YAML with maximum allowed values" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "max_string"
    command: "echo 'value1'"
    data_type: "string"
    allowed_values: ["value1", "value2", "value3", "value4", "value5", "value6", "value7", "value8", "value9", "value10"]
    default: "value1"
  - name: "max_number"
    command: "echo '50'"
    data_type: "number"
    allowed_values: ["1-10", "10-20", "20-30", "30-40", "40-50", "50-60", "60-70", "70-80", "80-90", "90-100"]
    default: "1"
EOF
    
    run ./gitcheck --only=metrics
    [ "$status" -eq 0 ]
    [[ "$output" == *"max_string"* ]]
    [[ "$output" == *"max_number"* ]]
}

@test "should handle YAML with minimum values" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "min_string"
    command: "echo 'single'"
    data_type: "string"
    allowed_values: ["single"]
    default: "single"
  - name: "min_number"
    command: "echo '5'"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "1"
EOF
    
    run ./gitcheck --only=metrics
    [ "$status" -eq 0 ]
    [[ "$output" == *"min_string"* ]]
    [[ "$output" == *"min_number"* ]]
}

@test "should handle commands with extreme output lengths" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "empty_output"
    command: "echo ''"
  - name: "single_char"
    command: "echo 'a'"
  - name: "very_long_line"
    command: "printf '%*s' 10000 | tr ' ' 'x'"
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
    [[ "$output" == *"empty_output"* ]]
    [[ "$output" == *"single_char"* ]]
    [[ "$output" == *"very_long_line"* ]]
}

@test "should handle commands with special shell characters" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "pipe_test"
    command: "echo 'test' | grep 'test'"
  - name: "redirect_test"
    command: "echo 'test' > /dev/null && echo 'success'"
  - name: "subshell_test"
    command: "(echo 'test'; echo 'done')"
  - name: "variable_test"
    command: "VAR=test; echo $VAR"
  - name: "wildcard_test"
    command: "echo *.txt"
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
    [[ "$output" == *"pipe_test"* ]]
    [[ "$output" == *"redirect_test"* ]]
    [[ "$output" == *"subshell_test"* ]]
    [[ "$output" == *"variable_test"* ]]
    [[ "$output" == *"wildcard_test"* ]]
}

@test "should handle commands with newlines and control characters" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "newlines"
    command: |
      echo "line 1"
      echo "line 2"
      echo "line 3"
  - name: "tabs"
    command: "echo -e 'tab\tseparated\tvalues'"
  - name: "control_chars"
    command: "echo -e 'bell\a and newline\n and carriage return\r'"
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
    [[ "$output" == *"newlines"* ]]
    [[ "$output" == *"tabs"* ]]
    [[ "$output" == *"control_chars"* ]]
}

@test "should handle boundary timeout values" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "fast_command"
    command: "echo 'fast'"
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
    
    # Test minimum timeout
    run ./gitcheck --timeout=1 --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"fast_command"* ]]
    
    # Test very short timeout
    run ./gitcheck --timeout=1 --only=preflight
    [ "$status" -eq 0 ]
}

@test "should handle numeric ranges at boundaries" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "boundary_test"
    command: "echo '10'"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "5"
EOF
    
    run ./gitcheck --only=metrics
    [ "$status" -eq 0 ]
    [[ "$output" == *"boundary_test"* ]]
}

@test "should handle decimal precision in numeric ranges" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
  - name: "decimal_test"
    command: "echo '3.14159'"
    data_type: "number"
    allowed_values: ["3.14159-3.14160"]
    default: "3.14159"
EOF
    
    run ./gitcheck --only=metrics
    [ "$status" -eq 0 ]
    [[ "$output" == *"decimal_test"* ]]
}

@test "should handle commands that change working directory" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "cd_test"
    command: "cd /tmp && pwd && cd -"
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
    [[ "$output" == *"cd_test"* ]]
}

@test "should handle commands that modify environment" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "env_test"
    command: "export TEST_VAR=value && echo $TEST_VAR"
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
    [[ "$output" == *"env_test"* ]]
}

@test "should handle commands with different exit codes" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "exit_0"
    command: "exit 0"
  - name: "exit_1"
    command: "exit 1"
  - name: "exit_255"
    command: "exit 255"
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
    [ "$status" -eq 1 ]  # Should fail due to non-zero exit codes
    [[ "$output" == *"exit_0"* ]]
    [[ "$output" == *"exit_1"* ]]
    [[ "$output" == *"exit_255"* ]]
}

@test "should handle commands that produce binary output" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "binary_test"
    command: "printf '\x00\x01\x02\x03'"
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
    [[ "$output" == *"binary_test"* ]]
}

@test "should handle commands with very long names" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "this_is_a_very_long_command_name_that_exceeds_normal_length_limits_and_tests_edge_cases_for_command_naming_conventions_and_should_still_work_properly"
    command: "echo 'long name test'"
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
    
    run ./gitcheck --only=preflight --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"long name test"* ]]
}

@test "should handle commands with unicode in names" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "🚀_rocket_command"
    command: "echo 'rocket'"
  - name: "📊_metrics_command"
    command: "echo 'metrics'"
  - name: "✅_success_command"
    command: "echo 'success'"
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
    [[ "$output" == *"rocket"* ]]
    [[ "$output" == *"metrics"* ]]
    [[ "$output" == *"success"* ]]
} 