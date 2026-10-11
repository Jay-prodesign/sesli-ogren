# Rule: engineering quality (D-029)

AGENTS.md §14 governs. This rule removes two ambiguities.

- **When to run the Final Engineering Test:** for decisions that add a
  dependency, a service, a schema or authority boundary, provider coupling, a
  security or privacy surface, or a cost driver, and for choosing GO_ADAPT or
  FALLBACK_CLEAN_FLUTTER. Record the ten answers in the task's exec plan or
  return. Use N/A with a one-line reason only where a question truly does not
  apply. Routine reversible edits do not need the test.
- **What counts as evidence:** a command that was run, with its exit status or
  output, or a named test with its result. "The code exists" or "a document says
  so" is not evidence.
