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

@test "should handle many preflight commands efficiently" {
    # Create YAML with many preflight commands
    cat > gitcheck.yaml << 'EOF'
preflight:
EOF
    
    # Add 50 preflight commands
    for i in {1..50}; do
        echo "  - name: \"preflight_$i\"" >> gitcheck.yaml
        echo "    command: \"echo 'preflight $i'\"" >> gitcheck.yaml
    done
    
    cat >> gitcheck.yaml << 'EOF'
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
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=preflight
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    [ "$(echo "$execution_time < 5.0" | bc -l)" -eq 1 ]  # Should complete within 5 seconds
    [[ "$output" == *"preflight_1"* ]]
    [[ "$output" == *"preflight_50"* ]]
}

@test "should handle many checks efficiently" {
    # Create YAML with many checks
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
EOF
    
    # Add 50 checks
    for i in {1..50}; do
        echo "  - name: \"check_$i\"" >> gitcheck.yaml
        echo "    command: \"echo 'check $i'\"" >> gitcheck.yaml
    done
    
    cat >> gitcheck.yaml << 'EOF'
metrics:
  - name: "test"
    command: "echo 'test'"
    data_type: "string"
    allowed_values: ["test"]
    default: "test"
EOF
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=checks
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    [ "$(echo "$execution_time < 5.0" | bc -l)" -eq 1 ]  # Should complete within 5 seconds
    [[ "$output" == *"check_1"* ]]
    [[ "$output" == *"check_50"* ]]
}

@test "should handle many metrics efficiently" {
    # Create YAML with many metrics
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "test"
    command: "echo 'test'"
checks:
  - name: "test"
    command: "echo 'test'"
metrics:
EOF
    
    # Add 50 metrics
    for i in {1..50}; do
        echo "  - name: \"metric_$i\"" >> gitcheck.yaml
        echo "    command: \"echo '$i'\"" >> gitcheck.yaml
        echo "    data_type: \"number\"" >> gitcheck.yaml
        echo "    allowed_values: [\"1-100\"]" >> gitcheck.yaml
        echo "    default: \"50\"" >> gitcheck.yaml
    done
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=metrics
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    [ "$(echo "$execution_time < 10.0" | bc -l)" -eq 1 ]  # Should complete within 10 seconds
    [[ "$output" == *"metric_1"* ]]
    [[ "$output" == *"metric_50"* ]]
}

@test "should handle large output files efficiently" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "large_output"
    command: |
      for i in {1..10000}; do
        echo "Line $i: $(date)"
      done
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
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=preflight --timeout=30
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    [ "$(echo "$execution_time < 30.0" | bc -l)" -eq 1 ]  # Should complete within 30 seconds
    
    # Check that the large output was captured
    [ -f ".gitcheck/large_output" ]
    run wc -l .gitcheck/large_output
    output_lines=$(echo "$output" | awk '{print $1}')
    [ "$output_lines" -gt 10000 ]  # Should have captured the large output
}

@test "should handle memory usage efficiently" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "memory_test"
    command: |
      # Generate large output to test memory usage
      for i in {1..1000}; do
        printf "Line %d: %s\n" $i "$(printf 'x%.0s' {1..1000})"
      done
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
    
    # Measure memory usage (simplified)
    run ./gitcheck --only=preflight --timeout=10
    [ "$status" -eq 0 ]
    
    # Check that the output was captured without memory issues
    [ -f ".gitcheck/memory_test" ]
    run wc -l .gitcheck/memory_test
    output_lines=$(echo "$output" | awk '{print $1}')
    [ "$output_lines" -gt 1000 ]
}

@test "should handle concurrent execution efficiently" {
    cat > gitcheck.yaml << 'EOF'
preflight:
EOF
    
    # Add 20 concurrent commands
    for i in {1..20}; do
        echo "  - name: \"concurrent_$i\"" >> gitcheck.yaml
        echo "    command: \"sleep 1 && echo 'concurrent $i'\"" >> gitcheck.yaml
    done
    
    cat >> gitcheck.yaml << 'EOF'
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
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=preflight --timeout=10
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    # Should complete in roughly 1-2 seconds due to concurrency
    [ "$(echo "$execution_time < 10.0" | bc -l)" -eq 1 ]
    [[ "$output" == *"concurrent_1"* ]]
    [[ "$output" == *"concurrent_20"* ]]
}

@test "should handle timeout efficiently" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "slow_command"
    command: "sleep 10"
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
    
    # Measure execution time with timeout
    start_time=$(date +%s.%N)
    run ./gitcheck --only=preflight --timeout=2
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 1 ]  # Should fail due to timeout
    [ "$(echo "$execution_time < 3.0" | bc -l)" -eq 1 ]  # Should timeout within 3 seconds
    [[ "$output" == *"TIMEOUT"* ]]
}

@test "should handle complex YAML parsing efficiently" {
    # Create complex YAML with nested structures
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "complex_test"
    command: |
      echo "Testing complex YAML parsing..."
      echo "Multiple lines with various characters:"
      echo "  - Indented content"
      echo "  - Special chars: !@#$%^&*()"
      echo "  - Unicode: 🚀 📊 ✅"
      echo "  - Quotes: 'single' and \"double\""
      echo "  - Variables: $PATH and ${HOME}"
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
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=preflight
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    [ "$(echo "$execution_time < 2.0" | bc -l)" -eq 1 ]  # Should complete quickly
    [[ "$output" == *"complex_test"* ]]
}

@test "should handle file I/O efficiently" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "file_io_test"
    command: |
      # Test file I/O performance
      for i in {1..100}; do
        echo "File $i content" > "temp_file_$i.txt"
        cat "temp_file_$i.txt"
        rm "temp_file_$i.txt"
      done
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
    
    # Measure execution time
    start_time=$(date +%s.%N)
    run ./gitcheck --only=preflight
    end_time=$(date +%s.%N)
    
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    [ "$status" -eq 0 ]
    [ "$(echo "$execution_time < 5.0" | bc -l)" -eq 1 ]  # Should complete within 5 seconds
    [[ "$output" == *"file_io_test"* ]]
} 