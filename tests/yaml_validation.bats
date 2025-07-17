#!/usr/bin/env bats

# Test YAML validation functionality

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

@test "should validate correct YAML structure" {
    create_valid_yaml
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ YAML configuration validation passed"* ]]
}

@test "should fail with invalid YAML syntax" {
    echo "invalid: yaml: content" > gitcheck.yaml
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: 'gitcheck.yaml' is not a valid YAML file"* ]]
}

@test "should fail when missing preflight section" {
    cat > gitcheck.yaml << 'EOF'
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
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Missing required key 'preflight' in configuration"* ]]
}

@test "should fail when missing checks section" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Missing required key 'checks' in configuration"* ]]
}

@test "should fail when missing metrics section" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "test_check"
    command: "echo 'check test'"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Missing required key 'metrics' in configuration"* ]]
}

@test "should fail when preflight command missing name field" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - command: "echo 'preflight test'"
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
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Preflight command 1 missing 'name' field"* ]]
}

@test "should fail when preflight command missing command field" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
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
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Preflight command 1 missing 'command' field"* ]]
}

@test "should fail when checks command missing name field" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - command: "echo 'check test'"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Checks command 1 missing 'name' field"* ]]
}

@test "should fail when checks command missing command field" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "test_check"
metrics:
  - name: "test_metric"
    command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Checks command 1 missing 'command' field"* ]]
}

@test "should fail when metrics command missing name field" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "test_check"
    command: "echo 'check test'"
metrics:
  - command: "echo 'metric test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Metrics command 1 missing 'name' field"* ]]
}

@test "should fail when metrics command missing command field" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "test_check"
    command: "echo 'check test'"
metrics:
  - name: "test_metric"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Metrics command 1 missing 'command' field"* ]]
}

@test "should fail when metrics command missing allowed_values field" {
    cat > gitcheck.yaml << 'EOF'
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
    default: "test"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Metrics command 1 missing 'allowed_values' field"* ]]
}

@test "should warn when sections are empty" {
    cat > gitcheck.yaml << 'EOF'
preflight: []
checks: []
metrics: []
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning: No preflight commands found"* ]]
    [[ "$output" == *"Warning: No checks commands found"* ]]
    [[ "$output" == *"Warning: No metrics commands found"* ]]
    [[ "$output" == *"✅ YAML configuration validation passed"* ]]
}

@test "should validate multiple commands in each section" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "preflight1"
    command: "echo 'preflight1'"
  - name: "preflight2"
    command: "echo 'preflight2'"
checks:
  - name: "check1"
    command: "echo 'check1'"
  - name: "check2"
    command: "echo 'check2'"
metrics:
  - name: "metric1"
    command: "echo 'metric1'"
    data_type: "string"
    allowed_values: ["value1", "value2"]
    default: "value1"
  - name: "metric2"
    command: "echo 'metric2'"
    data_type: "string"
    allowed_values: ["value3", "value4"]
    default: "value3"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ YAML configuration validation passed"* ]]
}

@test "should validate with complex allowed_values arrays" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test_preflight"
    command: "echo 'preflight test'"
checks:
  - name: "test_check"
    command: "echo 'check test'"
metrics:
  - name: "complex_metric"
    command: "echo 'complex'"
    data_type: "string"
    allowed_values: ["0-100", "101-500", "501-1000", "1001+"]
    default: "0-100"
EOF
    run ./gitcheck --only=validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ YAML configuration validation passed"* ]]
} 