# Grug's Refactor Plan for GitCheck

Grug brain developer see complexity demon spirit creeping into gitcheck script. This plan fight complexity and make code simpler!

## Problems Grug Identified

### 1. **Complex YAML Validation** 
Lines 200-300 very complex validation logic. Too big brain!

**Current Problem:**
```bash
# One giant function doing everything
validate_yaml_config() {
    # 100+ lines of complex validation logic
    # Mixing preflight, checks, and metrics validation
    # Hard to understand and maintain
}
```

**Grug Solution:**
Break into smaller, focused functions:
- `validate_preflight()` - validate preflight commands
- `validate_checks()` - validate checks commands  
- `validate_metrics()` - validate metrics commands
- `validate_yaml_syntax()` - basic YAML validation

### 2. **Magic Numbers**
```bash
TIMEOUT=300  # 5 minutes
```

**Grug Problem:** Why 300? Why not 600? Why not configurable?

**Grug Solution:**
- Add comment explaining why 300 seconds (5 minutes reasonable for most commands)
- Consider making configurable in YAML file
- Add constants for common timeouts

### 3. **Long Functions**
- `execute_yaml_section()` - very long function
- `execute_metrics_phase()` - very long function

**Grug Problem:** Hard to understand, hard to test, hard to maintain

**Grug Solution:**
Break into smaller functions:
- `execute_command()` - execute single command
- `capture_command_output()` - handle output capture
- `write_artefact_file()` - write artefact files
- `validate_metric_result()` - validate metric output

### 4. **Repetitive Code**
```bash
# This pattern repeat many times:
name=$(echo "$section_data" | jq -r ".[$i].name")
command=$(echo "$section_data" | jq -r ".[$i].command")
```

**Grug Problem:** Copy-paste code = complexity demon spirit!

**Grug Solution:**
Create helper functions:
- `extract_command_name()` - get command name from JSON
- `extract_command_string()` - get command string from JSON
- `parse_section_data()` - parse entire section once

### 5. **Better Comments and Error Messages**
**Grug Problem:** Comments only explain what code do, not why

**Grug Solution:**
- Add business logic comments explaining WHY
- Better error messages for users
- Add examples in comments

## Grug's Refactor Strategy

**Grug will address each problem noninteractively, then stop for conversation about what was done.**

### Problem 1: Repetitive Code Pattern
**Grug will:**
1. Create `extract_command_name()` helper function
2. Create `extract_command_string()` helper function  
3. Replace repetitive jq calls with helper functions
4. Test that behavior unchanged
5. **STOP for conversation**

### Problem 2: Magic Numbers
**Grug will:**
1. Add comment explaining why TIMEOUT=300 (5 minutes reasonable)
2. Add constants for common timeout values
3. Consider making configurable in future
4. Test that behavior unchanged
5. **STOP for conversation**

### Problem 3: Long Validation Function
**Grug will:**
1. Extract `validate_yaml_syntax()` function
2. Extract `validate_preflight()` function
3. Extract `validate_checks()` function
4. Extract `validate_metrics()` function
5. Refactor main validation to use smaller functions
6. Test that behavior unchanged
7. **STOP for conversation**

### Problem 4: Long Execution Functions
**Grug will:**
1. Extract `execute_single_command()` function
2. Extract `write_artefact_file()` function
3. Extract `capture_command_output()` function
4. Extract `handle_command_timeout()` function
5. Refactor execution functions to use helpers
6. Test that behavior unchanged
7. **STOP for conversation**

### Problem 5: Better Documentation
**Grug will:**
1. Add business logic comments explaining WHY
2. Improve error messages for users
3. Add examples in complex sections
4. Test that behavior unchanged
5. **STOP for conversation**

## Grug's Success Criteria

✅ **Code easier to read** - smaller functions, better names  
✅ **Code easier to test** - focused functions, clear inputs/outputs  
✅ **Code easier to maintain** - less duplication, better organization  
✅ **Better user experience** - clearer error messages  
✅ **Fight complexity demon spirit** - simpler, not more complex!  

## Grug's Rules

1. **One function, one job** - each function do one thing well
2. **Extract, don't rewrite** - keep existing logic, just organize better
3. **Test after each change** - make sure nothing break
4. **Keep it simple** - avoid over-engineering
5. **Document the why** - not just the what
6. **Grug no alter tests** - tests must stay same to catch behavior breaks

Grug brain developer ready to fight complexity demon spirit! Let's make gitcheck simpler and better! 