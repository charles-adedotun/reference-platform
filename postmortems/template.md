# Postmortem: [Incident Title]

**Date**: YYYY-MM-DD
**Authors**: [Name(s)]
**Status**: Draft | In Review | Final
**Severity**: SEV-1 (Critical) | SEV-2 (High) | SEV-3 (Medium) | SEV-4 (Low)

---

## Summary

*Brief 2-3 sentence summary of what happened, the impact, and the resolution.*

Example: On January 15, 2024, our production database experienced a complete outage from 14:32 to 15:47 UTC affecting all users. The root cause was insufficient connection pool configuration combined with a deployment that increased concurrent request volume. Service was restored by scaling the database and adjusting application connection pool settings.

---

## Impact

### User Impact
- **Duration**: [Start time] to [End time] ([Total duration])
- **Affected Users**: [Number/percentage of users affected]
- **Service Degradation**: [Describe what users experienced]
- **Geographic Impact**: [If relevant, which regions were affected]

### Business Impact
- **Revenue Impact**: [Estimated revenue loss, if applicable]
- **SLA/SLO Impact**: [Which SLAs/SLOs were breached]
- **Customer Complaints**: [Number of support tickets or complaints]

### Metrics
- **Error Rate**: [Peak error rate during incident]
- **Availability**: [Actual vs. target]
- **Latency**: [P50, P95, P99 during incident]
- **Traffic**: [Request volume during incident]

---

## Root Cause

*Detailed explanation of what caused the incident. Be specific and technical.*

**Primary Cause**: [Main technical reason for the failure]

**Contributing Factors**:
1. [Factor 1]
2. [Factor 2]
3. [Factor 3]

**Why did existing safeguards fail?**
- [Explain why monitoring, alerts, or other safeguards didn't prevent this]

---

## Timeline

All times in UTC. Use 24-hour format.

| Time | Event | Actions Taken |
|------|-------|---------------|
| HH:MM | **Incident begins** - [Initial symptom] | |
| HH:MM | [Event description] | [Action taken] |
| HH:MM | Alert fired: [Alert name] | [Who was notified] |
| HH:MM | Team member acknowledged | [Initial investigation] |
| HH:MM | [Discovery/escalation] | [Next action] |
| HH:MM | **Incident detected** - [How it was discovered] | [Investigation started] |
| HH:MM | Root cause identified | [Diagnosis details] |
| HH:MM | Mitigation applied | [Specific remediation] |
| HH:MM | **Service restored** | [Verification performed] |
| HH:MM | Monitoring confirmed recovery | [All-clear given] |
| HH:MM | **Incident resolved** | [Post-incident tasks] |

**Detection Time**: [Time from incident start to detection]
**Response Time**: [Time from detection to first action]
**Resolution Time**: [Time from detection to resolution]
**Total Duration**: [Total incident duration]

---

## Detection

### How was the incident detected?
- [ ] Automated monitoring alert
- [ ] Customer report
- [ ] Internal user report
- [ ] Scheduled health check
- [ ] Other: [Specify]

### What worked well?
- [What detection mechanisms worked]

### What didn't work?
- [What failed to detect or alert]

### Time to Detection
- **Actual**: [Time from incident start to detection]
- **Target**: [SLO for detection time]
- **Gap**: [If target was missed, by how much]

---

## Response

### Incident Response Team
- **Incident Commander**: [Name]
- **Technical Lead**: [Name]
- **Communications Lead**: [Name]
- **Subject Matter Experts**: [Names and areas]

### Response Timeline
- **Time to Acknowledge**: [Time from alert to ack]
- **Time to Engage**: [Time to get right people involved]
- **Time to Diagnose**: [Time to identify root cause]
- **Time to Mitigate**: [Time from diagnosis to mitigation]

### What went well?
- [Effective response actions]
- [Good communication examples]
- [Helpful tools or runbooks]

### What could be improved?
- [Delays or blockers]
- [Communication gaps]
- [Missing tools or documentation]

---

## Resolution

### Immediate Mitigation
*Actions taken to restore service quickly*

```bash
# Commands executed (sanitized)
kubectl scale deployment/app --replicas=10
kubectl rollout restart deployment/database
```

### Permanent Fix
*Long-term solution to prevent recurrence*

- [Describe the permanent fix]
- [Link to PR or change request]

### Verification
*How we confirmed the fix worked*

- [Metrics checked]
- [Tests performed]
- [Monitoring confirmation]

---

## Action Items

### Prevent Recurrence
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| [Specific technical fix] | [Name] | P0 | YYYY-MM-DD | [ ] | [Link] |
| [Improve monitoring] | [Name] | P1 | YYYY-MM-DD | [ ] | [Link] |
| [Update documentation] | [Name] | P2 | YYYY-MM-DD | [ ] | [Link] |

### Improve Detection
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| [Add new alert] | [Name] | P0 | YYYY-MM-DD | [ ] | [Link] |
| [Tune existing alert] | [Name] | P1 | YYYY-MM-DD | [ ] | [Link] |

### Improve Response
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| [Create/update runbook] | [Name] | P1 | YYYY-MM-DD | [ ] | [Link] |
| [Improve tooling] | [Name] | P2 | YYYY-MM-DD | [ ] | [Link] |

### Process Improvements
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| [Process change] | [Name] | P2 | YYYY-MM-DD | [ ] | [Link] |
| [Team training] | [Name] | P3 | YYYY-MM-DD | [ ] | [Link] |

**Priority Levels**:
- P0: Critical - Must complete within 1 week
- P1: High - Complete within 2 weeks
- P2: Medium - Complete within 1 month
- P3: Low - Complete within 1 quarter

---

## Lessons Learned

### What went well?
1. [Positive outcome 1]
2. [Positive outcome 2]
3. [Positive outcome 3]

### What went poorly?
1. [Problem 1]
2. [Problem 2]
3. [Problem 3]

### Where did we get lucky?
*Things that could have made the incident worse but didn't*

1. [Lucky break 1]
2. [Lucky break 2]

---

## Supporting Information

### Relevant Metrics/Graphs
- [Link to dashboard or screenshots]
- [Key metric graphs during incident]

### Logs
```
[Relevant log excerpts]
```

### Related Incidents
- [Link to similar past incidents]
- [Patterns or trends]

### References
- [Runbook used]: [Link]
- [Documentation]: [Link]
- [Slack thread]: [Link]
- [Incident ticket]: [Link]

---

## Review and Sign-off

| Reviewer | Role | Date | Approved |
|----------|------|------|----------|
| [Name] | Engineering Lead | YYYY-MM-DD | [ ] |
| [Name] | SRE Lead | YYYY-MM-DD | [ ] |
| [Name] | Product Lead | YYYY-MM-DD | [ ] |

---

## Follow-up Review

**Review Date**: [30 days after incident]
**Reviewer**: [Name]

### Action Item Completion Status
- [ ] All P0 items completed
- [ ] All P1 items completed or have plan
- [ ] All P2 items tracked

### Effectiveness of Fixes
- [Did the fixes prevent recurrence?]
- [Any new issues discovered?]

---

## Notes

*Additional context, learnings, or observations*

---

**Document History**:
- YYYY-MM-DD: Initial draft created
- YYYY-MM-DD: Review completed
- YYYY-MM-DD: Final version published
- YYYY-MM-DD: 30-day review completed
