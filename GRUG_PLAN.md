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

### Phase 1: Extract Helper Functions
1. Create `extract_command_name()` and `extract_command_string()`
2. Create `write_artefact_file()` function
3. Create `capture_command_output()` function

### Phase 2: Break Validation Logic
1. Extract `validate_yaml_syntax()` 
2. Extract `validate_preflight()`
3. Extract `validate_checks()`
4. Extract `validate_metrics()`

### Phase 3: Break Execution Functions
1. Extract `execute_single_command()`
2. Extract `handle_command_timeout()`
3. Extract `validate_metric_result()`

### Phase 4: Improve Documentation
1. Add business logic comments
2. Improve error messages
3. Add constants for magic numbers

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