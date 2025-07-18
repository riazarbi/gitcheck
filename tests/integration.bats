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
    # Add a second commit for HEAD~1 and commit history tests
    echo "second file" > second.txt
    git add second.txt
    git commit -m "Second commit"
    # Add a README.md for tests that check for it
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Add README"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "should run complete workflow with all phases" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "check_git_status"
    command: "git status --porcelain"
  - name: "check_branch"
    command: "git branch --show-current"
checks:
  - name: "file_count"
    command: "find . -type f -name '*.txt' | wc -l"
  - name: "has_readme"
    command: "test -f README.md && echo 'yes' || echo 'no'"
  - name: "check_file_size"
    command: "wc -c < test.txt"
metrics:
  - name: "code_lines"
    command: "find . -name '*.txt' -exec wc -l {} + | tail -1 | awk '{print $1}'"
    data_type: "number"
    allowed_values: ["1-100"]
    default: "1"
  - name: "repo_size"
    command: "du -s . | cut -f1"
    data_type: "number"
    allowed_values: ["1-1000"]
    default: "1"
EOF
    
    run ./gitcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"Preflight phase completed"* ]]
    [[ "$output" == *"Checks phase completed"* ]]
    [[ "$output" == *"Metrics phase completed"* ]]
    
    # Check that all artefact files were created
    [ -f ".gitcheck/preflight/check_git_status" ]
    [ -f ".gitcheck/preflight/check_branch" ]
    [ -f ".gitcheck/checks/file_count" ]
    [ -f ".gitcheck/checks/has_readme" ]
    [ -f ".gitcheck/checks/check_file_size" ]
    [ -f ".gitcheck/metrics/code_lines" ]
    [ -f ".gitcheck/metrics/repo_size" ]
    [ -f ".gitcheck/metrics.json" ]
}

@test "should handle real-world YAML with complex commands" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "environment_check"
    command: |
      echo "Checking environment..."
      echo "OS: $(uname -s)"
      echo "Shell: $SHELL"
      echo "PWD: $(pwd)"
checks:
  - name: "code_quality"
    command: |
      echo "Running code quality checks..."
      echo "Files found: $(find . -type f | wc -l)"
      echo "Directories: $(find . -type d | wc -l)"
      echo "Largest file: $(find . -type f -exec ls -la {} + | sort -k5 -nr | head -1 | awk '{print $9}')"
  - name: "git_analysis"
    command: |
      echo "Git repository analysis:"
      echo "Commits: $(git rev-list --count HEAD)"
      echo "Branches: $(git branch | wc -l)"
      echo "Last commit: $(git log -1 --format='%h %s')"
metrics:
  - name: "complexity_score"
    command: |
      # Calculate a simple complexity score
      files=$(find . -type f | wc -l)
      lines=$(find . -type f -exec wc -l {} + | tail -1 | awk '{print $1}')
      echo $((files * lines / 10))
    data_type: "number"
    allowed_values: ["0-10000"]
    default: "1"
  - name: "maintenance_status"
    command: |
      # Determine maintenance status based on various factors
      if [ -f "README.md" ] && [ -f "Makefile" ]; then
        echo "well_maintained"
      elif [ -f "README.md" ]; then
        echo "basic_maintenance"
      else
        echo "needs_attention"
      fi
    data_type: "string"
    allowed_values: ["well_maintained", "basic_maintenance", "needs_attention"]
    default: "basic_maintenance"
EOF
    
    run ./gitcheck --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"environment_check"* ]]
    [[ "$output" == *"code_quality"* ]]
    [[ "$output" == *"git_analysis"* ]]
    [[ "$output" == *"complexity_score"* ]]
    [[ "$output" == *"maintenance_status"* ]]
}

@test "should handle different git scenarios" {
    # Create multiple commits
    echo "feature 1" > feature1.txt
    git add feature1.txt
    git commit -m "Add feature 1"
    
    echo "feature 2" > feature2.txt
    git add feature2.txt
    git commit -m "Add feature 2"
    
    # Create a branch
    git checkout -b feature-branch
    echo "branch content" > branch.txt
    git add branch.txt
    git commit -m "Add branch content"
    
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "git_info"
    command: |
      echo "Current branch: $(git branch --show-current)"
      echo "Commit count: $(git rev-list --count HEAD)"
      echo "Last commit: $(git log -1 --format='%h %s')"
checks:
  - name: "branch_analysis"
    command: |
      echo "All branches:"
      git branch -a
      echo "Branch count: $(git branch | wc -l)"
  - name: "commit_analysis"
    command: |
      echo "Recent commits:"
      git log --oneline -5
      echo "Total commits: $(git rev-list --count HEAD)"
metrics:
  - name: "branch_count"
    command: "git branch | wc -l"
    data_type: "number"
    allowed_values: ["1-10"]
    default: "1"
  - name: "commit_frequency"
    command: |
      # Calculate commits per day (simplified)
      days=$(git log --format=%cd --date=short | sort | uniq | wc -l)
      commits=$(git rev-list --count HEAD)
      if [ "$days" -gt 0 ]; then
        echo $((commits / days))
      else
        echo "0"
      fi
    data_type: "number"
    allowed_values: ["0-100"]
    default: "0"
EOF
    
    run ./gitcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"git_info"* ]]
    [[ "$output" == *"branch_analysis"* ]]
    [[ "$output" == *"commit_analysis"* ]]
}

@test "should handle detached HEAD state" {
    # Create a detached HEAD
    git checkout HEAD~1
    
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "head_status"
    command: |
      if git symbolic-ref HEAD >/dev/null 2>&1; then
        echo "attached"
      else
        echo "detached"
      fi
checks:
  - name: "commit_info"
    command: |
      echo "Current commit: $(git rev-parse HEAD)"
      echo "Commit message: $(git log -1 --format='%s')"
      echo "Author: $(git log -1 --format='%an')"
metrics:
  - name: "head_type"
    command: |
      if git symbolic-ref HEAD >/dev/null 2>&1; then
        echo "attached"
      else
        echo "detached"
      fi
    data_type: "string"
    allowed_values: ["attached", "detached"]
    default: "detached"
EOF
    
    run ./gitcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"head_status"* ]]
    [[ "$output" == *"commit_info"* ]]
    [[ "$output" == *"head_type"* ]]
}

@test "should handle specific commit hashes" {
    # Get the commit hash
    COMMIT_HASH=$(git rev-parse HEAD)
    
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "commit_check"
    command: "git show --format='%H %s' --no-patch"
checks:
  - name: "file_at_commit"
    command: "git ls-tree -r HEAD"
metrics:
  - name: "commit_age"
    command: |
      # Calculate days since commit
      commit_date=$(git log -1 --format=%ct)
      current_date=$(date +%s)
      days=$(( (current_date - commit_date) / 86400 ))
      echo "$days"
    data_type: "number"
    allowed_values: ["0-365"]
    default: "0"
EOF
    
    run ./gitcheck --commit "$COMMIT_HASH"
    [ "$status" -eq 0 ]
    [[ "$output" == *"commit_check"* ]]
    [[ "$output" == *"file_at_commit"* ]]
    [[ "$output" == *"commit_age"* ]]
}

@test "should handle large output gracefully" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "large_output_test"
    command: |
      echo "Generating large output..."
      for i in {1..1000}; do
        echo "Line $i: $(date)"
      done
checks:
  - name: "count_lines"
    command: "wc -l < test.txt"
metrics:
  - name: "output_size"
    command: "wc -c < test.txt"
    data_type: "number"
    allowed_values: ["1-10000"]
    default: "10"
EOF
    
    run ./gitcheck --timeout=10
    [ "$status" -eq 0 ]
    [[ "$output" == *"large_output_test"* ]]
    [[ "$output" == *"count_lines"* ]]
    [[ "$output" == *"output_size"* ]]
    
    # Check that the large output was captured
    [ -f ".gitcheck/preflight/large_output_test" ]
    run wc -l .gitcheck/preflight/large_output_test
    output_lines=$(echo "$output" | awk '{print $1}')
    [ "$output_lines" -gt 1000 ]  # Should have captured the large output
}

@test "should handle concurrent execution scenarios" {
    cat > gitcheck.yaml << 'EOF'
preflight:
  - name: "parallel_test_1"
    command: "sleep 1 && echo 'test 1'"
  - name: "parallel_test_2"
    command: "sleep 1 && echo 'test 2'"
  - name: "parallel_test_3"
    command: "sleep 1 && echo 'test 3'"
checks:
  - name: "sequential_test"
    command: "echo 'sequential'"
metrics:
  - name: "concurrent_metric"
    command: "echo 'concurrent'"
    data_type: "string"
    allowed_values: ["concurrent"]
    default: "concurrent"
EOF
    
    run ./gitcheck --timeout=5
    [ "$status" -eq 0 ]
    [[ "$output" == *"parallel_test_1"* ]]
    [[ "$output" == *"parallel_test_2"* ]]
    [[ "$output" == *"parallel_test_3"* ]]
    [[ "$output" == *"sequential_test"* ]]
    [[ "$output" == *"concurrent_metric"* ]]
} 