#!/usr/bin/env bats

# Test that Claude commands work correctly and don't cause early loop exit

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
    
    # Create prompts directory
    mkdir -p .gitcheck/prompts
}

# Helper function to create a minimal valid YAML file with Claude commands
create_claude_yaml() {
    local filename="${1:-gitcheck.yaml}"
    cat > "$filename" << 'EOF'
checks:
  - name: "simple_check"
    command: "echo 'simple output'"
  - name: "claude_check1"
    command: "echo 'claude1 output'"
  - name: "claude_check2"
    command: "echo 'claude2 output'"
  - name: "final_check"
    command: "echo 'final output'"
EOF
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

@test "should process all checks including those after Claude commands" {
    create_claude_yaml
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Should process all 4 checks
    [[ "$output" == *"Running: simple_check"* ]]
    [[ "$output" == *"Running: claude_check1"* ]]
    [[ "$output" == *"Running: claude_check2"* ]]
    [[ "$output" == *"Running: final_check"* ]]
    
    # Should execute all 4 checks
    [[ "$output" == *"✅ simple_check: EXECUTED"* ]]
    [[ "$output" == *"✅ claude_check1: EXECUTED"* ]]
    [[ "$output" == *"✅ claude_check2: EXECUTED"* ]]
    [[ "$output" == *"✅ final_check: EXECUTED"* ]]
    
    # Should complete with all checks succeeded
    [[ "$output" == *"Checks phase completed: 4/4 commands succeeded"* ]]
}

@test "should create artefact files for all checks" {
    create_claude_yaml
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Check that all artefact files were created
    [ -f ".gitcheck/simple_check" ]
    [ -f ".gitcheck/claude_check1" ]
    [ -f ".gitcheck/claude_check2" ]
    [ -f ".gitcheck/final_check" ]
}

@test "should handle multiple Claude commands in sequence" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "claude1"
    command: "echo 'claude1'"
  - name: "claude2"
    command: "echo 'claude2'"
  - name: "claude3"
    command: "echo 'claude3'"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Should process all 3 Claude commands
    [[ "$output" == *"Running: claude1"* ]]
    [[ "$output" == *"Running: claude2"* ]]
    [[ "$output" == *"Running: claude3"* ]]
    
    # Should execute all 3
    [[ "$output" == *"✅ claude1: EXECUTED"* ]]
    [[ "$output" == *"✅ claude2: EXECUTED"* ]]
    [[ "$output" == *"✅ claude3: EXECUTED"* ]]
    
    [[ "$output" == *"Checks phase completed: 3/3 commands succeeded"* ]]
}

@test "should work with real Claude command structure" {
    # Create a prompt file
    cat > .gitcheck/prompts/test_prompt.md << 'EOF'
Test prompt content
EOF
    
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "simple_check"
    command: "echo 'simple'"
  - name: "claude_check"
    command: "echo 'claude output'"
  - name: "final_check"
    command: "echo 'final'"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Should process all 3 checks
    [[ "$output" == *"Running: simple_check"* ]]
    [[ "$output" == *"Running: claude_check"* ]]
    [[ "$output" == *"Running: final_check"* ]]
    
    # Should execute all 3
    [[ "$output" == *"✅ simple_check: EXECUTED"* ]]
    [[ "$output" == *"✅ claude_check: EXECUTED"* ]]
    [[ "$output" == *"✅ final_check: EXECUTED"* ]]
    
    [[ "$output" == *"Checks phase completed: 3/3 commands succeeded"* ]]
}

@test "should handle long commands without early exit" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "short_check"
    command: "echo 'short'"
  - name: "long_check"
    command: "echo 'this is a very long command that might cause issues' && echo 'with process substitution' && echo 'if not handled correctly'"
  - name: "final_check"
    command: "echo 'final'"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Should process all 3 checks
    [[ "$output" == *"Running: short_check"* ]]
    [[ "$output" == *"Running: long_check"* ]]
    [[ "$output" == *"Running: final_check"* ]]
    
    # Should execute all 3
    [[ "$output" == *"✅ short_check: EXECUTED"* ]]
    [[ "$output" == *"✅ long_check: EXECUTED"* ]]
    [[ "$output" == *"✅ final_check: EXECUTED"* ]]
    
    [[ "$output" == *"Checks phase completed: 3/3 commands succeeded"* ]]
}

@test "should work with complex command structures" {
    cat > gitcheck.yaml << 'EOF'
checks:
  - name: "check1"
    command: "echo 'check1'"
  - name: "check2"
    command: "echo 'check2' && echo 'more output'"
  - name: "check3"
    command: "echo 'check3' || echo 'fallback'"
  - name: "check4"
    command: "echo 'check4'; echo 'semicolon separated'"
EOF
    
    run ./gitcheck --only=checks
    [ "$status" -eq 0 ]
    
    # Should process all 4 checks
    [[ "$output" == *"Running: check1"* ]]
    [[ "$output" == *"Running: check2"* ]]
    [[ "$output" == *"Running: check3"* ]]
    [[ "$output" == *"Running: check4"* ]]
    
    # Should execute all 4
    [[ "$output" == *"✅ check1: EXECUTED"* ]]
    [[ "$output" == *"✅ check2: EXECUTED"* ]]
    [[ "$output" == *"✅ check3: EXECUTED"* ]]
    [[ "$output" == *"✅ check4: EXECUTED"* ]]
    
    [[ "$output" == *"Checks phase completed: 4/4 commands succeeded"* ]]
} 