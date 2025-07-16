#!/usr/bin/env bats

# Test script structure and basic functionality

setup() {
    # Create a temporary directory for testing
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    
    # Copy the gitcheck script to test directory
    cp "$BATS_TEST_DIRNAME/../gitcheck" .
    chmod +x gitcheck
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

@test "should have correct shebang" {
    run head -1 gitcheck
    [ "$status" -eq 0 ]
    [ "$output" = "#!/bin/bash" ]
}

@test "should have error handling enabled" {
    run grep "set -euo pipefail" gitcheck
    [ "$status" -eq 0 ]
}

@test "should have modular sections" {
    run grep -c "GLOBAL VARIABLES" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c "UTILITY FUNCTIONS" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c "ARGUMENT PROCESSING" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c "MAIN EXECUTION" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}

@test "should have required functions" {
    run grep -c "usage()" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c "process_arguments()" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c "validate_arguments()" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c "display_configuration()" gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}

@test "should have default variables defined" {
    run grep -c 'CONFIG_FILE="gitcheck.yaml"' gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c 'COMMIT_HASH=""' gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
    
    run grep -c 'ONLY_PHASE=""' gitcheck
    [ "$status" -eq 0 ]
    [ "$output" -eq 1 ]
}

@test "should be executable" {
    run test -x gitcheck
    [ "$status" -eq 0 ]
}

@test "should have proper line endings" {
    run file gitcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"ASCII text"* ]]
    [[ "$output" == *"executable"* ]]
} 