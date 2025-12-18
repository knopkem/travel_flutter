---
work_package_id: "WP05"
subtasks:
  - "T029"
  - "T030"
  - "T031"
  - "T032"
  - "T033"
  - "T034"
  - "T035"
title: "POI Data Source - OpenStreetMap Overpass"
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

# Work Package Prompt: WP05 – POI Data Source - OpenStreetMap Overpass

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

**Goal**: Implement OpenStreetMap Overpass API repository to fetch POIs from OSM data

**Independent Test**: Select Rome (41.9028, 12.4964); verify Overpass returns POIs like Colosseum, Vatican Museums, rate limiting (1 req/sec) enforced

## Context & Constraints

**Related Documents**:
- [spec.md](../spec.md) - Feature specification with user stories and functional requirements
- [plan.md](../plan.md) - Implementation strategy and technical approach
- [data-model.md](../data-model.md) - Entity definitions and relationships
- [research.md](../research.md) - API research and deduplication algorithms
- [contracts/](../contracts/) - API contract specifications
- [quickstart.md](../quickstart.md) - Developer onboarding and testing guide
- [tasks.md](../tasks.md) - Complete task list with all work packages

**Reference**: See [tasks.md](../tasks.md) for detailed subtask descriptions (T029, T030, T031, T032, T033, T034, T035).

## Subtasks & Detailed Guidance

### Subtask T029 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T030 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T031 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T032 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T033 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T034 – Implementation required
**Steps**: Refer to [tasks.md](../tasks.md) for detailed implementation guidance.

### Subtask T035 – Implementation required
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
- 2025-12-18T08:14:16Z – claude – shell_pid=68023 – lane=doing – Starting WP05: OpenStreetMap Overpass POI data source
- 2025-12-18T08:17:14Z – claude – shell_pid=68023 – lane=for_review – Completed WP05: All 7 subtasks (T029-T035) implemented
