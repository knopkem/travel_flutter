---
work_package_id: "WP06"
subtasks:
  - "T036"
  - "T037"
  - "T038"
  - "T039"
  - "T040"
  - "T041"
  - "T042"
  - "T043"
title: "POI Data Source - Wikidata SPARQL"
phase: "Phase 1 - Core POI Features"
lane: "for_review"
assignee: ""
agent: "claude"
shell_pid: "68023"
review_status: ""
reviewed_by: ""
history:
  - timestamp: "2025-12-18T08:24:50+0100"
    lane: "planned"
    agent: "system"
    shell_pid: ""
    action: "Prompt generated via /spec-kitty.tasks"
---

# Work Package Prompt: WP06 – POI Data Source - Wikidata SPARQL

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged`.

---

## Review Feedback

*[This section is empty initially. Reviewers will populate it if the work is returned from review.]*

---

## Objectives & Success Criteria

**Goal**: Implement Wikidata SPARQL repository to fetch structured POI data with rich metadata

**Independent Test**: Select London (51.5074, -0.1278); verify Wikidata returns notable places with structured data (inception dates, visitor counts, heritage status)

## Context & Constraints

**Related Documents**:
- [spec.md](../spec.md) - Feature specification with user stories and functional requirements
- [plan.md](../plan.md) - Implementation strategy and technical approach
- [data-model.md](../data-model.md) - Entity definitions and relationships
- [research.md](../research.md) - API research and deduplication algorithms
- [contracts/](../contracts/) - API contract specifications
- [quickstart.md](../quickstart.md) - Developer onboarding and testing guide
- [tasks.md](../tasks.md) - Complete task list with all work packages

**Reference**: See [tasks.md](../tasks.md) for detailed subtask descriptions (T036, T037, T038, T039, T040, T041, T042, T043).

## Subtasks & Detailed Guidance

### Subtask T036 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T037 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T038 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T039 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T040 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T041 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T042 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T043 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.


## Definition of Done Checklist

- [ ] All subtasks completed as specified in tasks.md
- [ ] Independent test scenario passes successfully
- [ ] Code follows Dart/Flutter best practices
- [ ] No lint errors or warnings
- [ ] Documentation updated where needed
- [ ] State management working correctly (notifyListeners called appropriately)
- [ ] Error handling implemented for network/API failures

## Review Guidance

**Key Checkpoints**:
- Verify independent test scenario works end-to-end
- Check code quality: clean, readable, well-commented
- Validate error handling covers edge cases
- Ensure state updates trigger UI refresh correctly

## Activity Log

- 2025-12-18T08:24:50+0100 – system – lane=planned – Prompt created via /spec-kitty.tasks
- 2025-12-18T08:28:13Z – claude – shell_pid=68023 – lane=doing – Starting WP06: Wikidata SPARQL POI data source
- 2025-12-18T08:30:57Z – claude – shell_pid=68023 – lane=for_review – Completed WP06: All 8 subtasks (T036-T043) implemented
