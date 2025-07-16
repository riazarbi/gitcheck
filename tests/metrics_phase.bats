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

@test "should pass with all valid metrics" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "num"
    command: "echo '5'"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "1"
  - name: "str"
    command: "echo 'ok'"
    data_type: "string"
    allowed_values: ["ok", "fail"]
    default: "fail"
EOF
    run ./gitcheck --only=metrics
    echo "OUTPUT: $output"
    [ "$status" -eq 0 ]
    [ -f .gitcheck/metrics.json ]
    run jq -r '.[0].value' .gitcheck/metrics.json
    [ "$output" = "5" ]
    run jq -r '.[1].value' .gitcheck/metrics.json
    [ "$output" = "ok" ]
}

@test "should use default for failing number metric" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "num"
    command: "echo '20'"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "1"
EOF
    run ./gitcheck --only=metrics
    [ "$status" -eq 1 ]
    [ -f .gitcheck/metrics.json ]
    run jq -r '.[0].value' .gitcheck/metrics.json
    [ "$output" = "1" ]
    run jq -r '.[0].status' .gitcheck/metrics.json
    [ "$output" = "default" ]
}

@test "should use default for failing string metric" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "str"
    command: "echo 'bad'"
    data_type: "string"
    allowed_values: ["ok", "fail"]
    default: "fail"
EOF
    run ./gitcheck --only=metrics
    [ "$status" -eq 1 ]
    [ -f .gitcheck/metrics.json ]
    run jq -r '.[0].value' .gitcheck/metrics.json
    [ "$output" = "fail" ]
    run jq -r '.[0].status' .gitcheck/metrics.json
    [ "$output" = "default" ]
}

@test "should use default if command fails" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "failcmd"
    command: "exit 2"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "1"
EOF
    run ./gitcheck --only=metrics
    [ "$status" -eq 1 ]
    [ -f .gitcheck/metrics.json ]
    run jq -r '.[0].value' .gitcheck/metrics.json
    [ "$output" = "1" ]
    run jq -r '.[0].status' .gitcheck/metrics.json
    [ "$output" = "default" ]
}

@test "should fail validation if default not in allowed range" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "bad_default"
    command: "echo '5'"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "20"
EOF
    run ./gitcheck --only=metrics
    [ "$status" -eq 1 ]
    [[ "$output" == *"default value ('20') not in allowed_values"* ]]
}

@test "should handle decimal and range" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "dec"
    command: "echo '0.5'"
    data_type: "number"
    allowed_values: ["0-1"]
    default: "0"
EOF
    run ./gitcheck --only=metrics
    [ "$status" -eq 0 ]
    run jq -r '.[0].value' .gitcheck/metrics.json
    [ "$output" = "0.5" ]
}

@test "should use defaults for all failed metrics" {
    cat > gitcheck.yaml <<EOF
preflight: []
checks: []
metrics:
  - name: "num"
    command: "echo '20'"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "1"
  - name: "str"
    command: "echo 'bad'"
    data_type: "string"
    allowed_values: ["ok", "fail"]
    default: "fail"
EOF
    run ./gitcheck --only=metrics
    [ "$status" -eq 1 ]
    run jq -r '.[0].value' .gitcheck/metrics.json
    [ "$output" = "1" ]
    run jq -r '.[1].value' .gitcheck/metrics.json
    [ "$output" = "fail" ]
} 