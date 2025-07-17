#!/usr/bin/env bats

# Test validation functionality

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

@test "should work in a valid git repository" {
    create_valid_yaml
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"GitCheck Configuration:"* ]]
}

@test "should fail when not in a git repository" {
    # Remove .git directory to simulate non-git directory
    rm -rf .git
    run ./gitcheck --only=validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"fatal: not a git repository"* ]]
}

@test "should validate commit hash exists" {
    COMMIT_HASH=$(git rev-parse HEAD)
    create_valid_yaml
    run ./gitcheck --config gitcheck.yaml --commit "$COMMIT_HASH" --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commit hash: $COMMIT_HASH"* ]]
}

@test "should handle HEAD as valid commit reference" {
    create_valid_yaml
    run ./gitcheck --config gitcheck.yaml --commit HEAD --only=validate
    [ "$status" -eq 0 ]
    HASH=$(echo "$output" | grep 'Commit hash:' | awk '{print $3}')
    echo "DEBUG: Extracted hash: '$HASH' (length: ${#HASH})"
    [ "${#HASH}" -eq 40 ]
    [[ "$HASH" =~ ^[a-f0-9]{40}$ ]]
}

@test "should handle short commit hash" {
    SHORT_HASH=$(git rev-parse --short HEAD)
    create_valid_yaml
    run ./gitcheck --config gitcheck.yaml --commit "$SHORT_HASH" --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Commit hash: $SHORT_HASH"* ]]
}

@test "should fail with invalid commit hash" {
    create_valid_yaml
    run ./gitcheck --config gitcheck.yaml --commit invalid_hash --only=validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"Error: Commit hash 'invalid_hash' does not exist or is not a commit."* ]]
}

@test "should use latest commit when no hash specified" {
    create_valid_yaml
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    # Should contain the current HEAD commit hash
    HEAD_HASH=$(git rev-parse HEAD)
    [[ "$output" == *"Commit hash: $HEAD_HASH"* ]]
} 