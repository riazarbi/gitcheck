#!/usr/bin/env bats

# Test argument processing functionality

setup() {
    # Create a temporary directory for testing
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Copy the gitcheck script to test directory
    cp "$BATS_TEST_DIRNAME/../gitcheck" .
    chmod +x gitcheck
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

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

@test "should use default config file when no arguments provided" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml
    
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Config file: gitcheck.yaml"* ]]
}

@test "should use default commit hash when no commit specified" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml
    
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commit hash:"* ]]
    HASH=$(echo "$output" | grep 'Commit hash:' | awk '{print $3}')
    [ "${#HASH}" -eq 40 ]
    [[ "$HASH" =~ ^[a-f0-9]{40}$ ]]
}

@test "should accept custom config file as argument" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml my-config.yaml
    
    run ./gitcheck --config my-config.yaml --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Config file: my-config.yaml"* ]]
}

@test "should accept commit hash as argument" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml
    HASH=$(git rev-parse HEAD)
    
    run ./gitcheck --commit "$HASH" --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commit hash: $HASH"* ]]
}

@test "should accept custom config and commit hash" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml my-config.yaml
    HASH=$(git rev-parse HEAD)
    
    run ./gitcheck --config my-config.yaml --commit "$HASH" --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Config file: my-config.yaml"* ]]
    [[ "$output" == *"Commit hash: $HASH"* ]]
}

@test "should set preflight-only flag" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml
    
    run ./gitcheck --only=preflight
    [ "$status" -eq 0 ]
    [[ "$output" == *"Only phase: preflight"* ]]
}

@test "should set checks-only flag" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Only phase: checks"* ]]
}

@test "should combine phase options with other arguments" {
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    echo "test" > test.txt
    git add test.txt >/dev/null 2>&1
    git commit -m "test" >/dev/null 2>&1
    create_valid_yaml my-config.yaml
    HASH=$(git rev-parse HEAD)
    
    run ./gitcheck --config my-config.yaml --commit "$HASH" --only=checks
    [ "$status" -eq 0 ]
    [[ "$output" == *"Config file: my-config.yaml"* ]]
    [[ "$output" == *"Commit hash: $HASH"* ]]
    [[ "$output" == *"Only phase: checks"* ]]
}

@test "should display help with --help flag" {
    run ./gitcheck --help
    [ "$status" -eq 1 ]  # Help exits with status 1
    [[ "$output" == *"Usage: gitcheck"* ]]
    [[ "$output" == *"--only=PHASE"* ]]
}

@test "should display help with -h flag" {
    run ./gitcheck -h
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage: gitcheck"* ]]
}

@test "should reject unknown options" {
    run ./gitcheck --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --unknown-option"* ]]
}

@test "should reject multiple phase options" {
    run ./gitcheck --only=checks --only=preflight
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Only one --only flag can be specified"* ]]
}

@test "should reject too many positional arguments" {
    run ./gitcheck foo bar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown positional argument: foo"* ]]
} 