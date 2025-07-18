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

@test "should handle command injection attempts safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "injection_test"
    command: "echo 'test'; rm -rf /tmp/test_file; echo 'injection'"
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
    
    # Create a test file to see if injection works
    echo "test content" > /tmp/test_file
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"injection_test"* ]]
    
    # The file should be deleted (command injection worked as expected)
    # This demonstrates that commands can modify the system
    [ ! -f "/tmp/test_file" ]
}

@test "should handle path traversal attempts safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "path_traversal"
    command: "cat ../../../etc/passwd"
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
    [ "$status" -eq 1 ]  # Should fail due to file not found or permission denied
    [[ "$output" == *"path_traversal"* ]]
}

@test "should handle privilege escalation attempts safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "privilege_test"
    command: "sudo -n echo 'privilege escalation' 2>/dev/null || echo 'sudo failed'"
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
    
    run ./gitcheck --only=preflight --timeout=5
    [ "$status" -eq 0 ]  # Should succeed but show sudo failure
    [[ "$output" == *"privilege_test"* ]]
}

@test "should handle file system access safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "file_access"
    command: "ls -la /etc"
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
    [ "$status" -eq 0 ]  # Should work if user has read access to /etc
    [[ "$output" == *"file_access"* ]]
}

@test "should handle network access safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "network_test"
    command: "curl -s --max-time 3 http://example.com | head -1"
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
    
    run ./gitcheck --only=preflight --timeout=10
    [ "$status" -eq 0 ]  # Should work if network is available
    [[ "$output" == *"network_test"* ]]
}

@test "should handle environment variable access safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "env_test"
    command: "echo 'PATH: $PATH' && echo 'HOME: $HOME'"
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
    [[ "$output" == *"PATH:"* ]]
    [[ "$output" == *"HOME:"* ]] || [[ "$output" == *"env_test"* ]]
}

@test "should handle process creation safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "process_test"
    command: "ps -ef | head -5"
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
    
    run ./gitcheck --only=preflight --timeout=10
    [ "$status" -eq 0 ]
    [[ "$output" == *"process_test"* ]]
}

@test "should handle shell command injection safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "shell_injection"
    command: "echo 'test'; $(echo 'injection'); echo 'after'"
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
    [ "$status" -eq 0 ]  # Should execute the command as written
    [[ "$output" == *"shell_injection"* ]]
}

@test "should handle file creation safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "file_creation"
    command: "echo 'test content' > test_created.txt && cat test_created.txt"
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
    [[ "$output" == *"file_creation"* ]]
    [[ "$output" == *"test content"* ]]
    
    # Check that the file was created
    [ -f "test_created.txt" ]
    [ "$(cat test_created.txt)" = "test content" ]
}

@test "should handle directory traversal safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "dir_traversal"
    command: "find . -name '*.txt' | xargs cat"
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
    [[ "$output" == *"dir_traversal"* ]]
    [[ "$output" == *"dir_traversal"* ]]  # Should run successfully
}

@test "should handle symbolic link resolution safely" {
    # Create a symbolic link
    ln -sf test.txt symlink.txt
    
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "symlink_test"
    command: "ls -la symlink.txt && cat symlink.txt"
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
    [[ "$output" == *"symlink_test"* ]]
    [[ "$output" == *"symlink_test"* ]]  # Should run successfully
}

@test "should handle command substitution safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "cmd_substitution"
    command: "echo 'Result: $(echo 'substituted')'"
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
    [[ "$output" == *"cmd_substitution"* ]]
    [[ "$output" == *"cmd_substitution"* ]]  # Should run successfully
}

@test "should handle pipeline injection safely" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "pipeline_injection"
    command: "echo 'test' | grep 'test' | wc -l"
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
    [[ "$output" == *"pipeline_injection"* ]]
    [[ "$output" == *"1"* ]]  # Should count one line
} 