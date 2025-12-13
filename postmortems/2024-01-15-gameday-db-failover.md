# Postmortem: Game Day Exercise - Database Failover

**Date**: 2024-01-15
**Authors**: SRE Team (Alice Chen, Bob Martinez)
**Status**: Final
**Severity**: SEV-3 (Planned Exercise)

---

## Summary

On January 15, 2024, we conducted a planned game day exercise to test our database failover procedures from 10:00 to 12:30 PST. The exercise simulated a complete PostgreSQL primary database failure to validate our backup, recovery, and failover mechanisms. While we successfully failed over to the standby database, we discovered several gaps in our procedures and automation that would have extended recovery time in a real incident.

---

## Impact

### User Impact
- **Duration**: 10:00 - 12:30 PST (2.5 hours planned exercise)
- **Affected Users**: None (staging environment only)
- **Service Degradation**: Database unavailable in staging for 47 minutes during failover
- **Geographic Impact**: N/A (planned test)

### Business Impact
- **Revenue Impact**: None (planned exercise)
- **SLA/SLO Impact**: Would have violated 15-minute RTO SLO by 32 minutes
- **Customer Complaints**: None (staging environment)

### Metrics
- **Error Rate**: 100% during database downtime (expected)
- **Availability**: 0% for database during failover period
- **Latency**: N/A (service completely unavailable)
- **Traffic**: Test traffic only (~100 req/sec)

---

## Exercise Objectives

1. **Test database backup and restore procedures**
2. **Validate PostgreSQL streaming replication failover**
3. **Verify application reconnection handling**
4. **Test runbook accuracy and completeness**
5. **Measure actual RTO (Recovery Time Objective)**
6. **Identify gaps in monitoring and alerting**

---

## Root Cause (Simulated Failure)

**Simulated Scenario**: Complete failure of PostgreSQL primary database pod

**Method**: Executed `kubectl delete pod postgres-0 --grace-period=0 --force` to simulate catastrophic pod failure

**Why this scenario?**
- Common failure mode in Kubernetes environments
- Tests both automated failover and manual intervention
- Validates StatefulSet recovery behavior

---

## Timeline

All times in PST (UTC-8).

| Time | Event | Actions Taken |
|------|-------|---------------|
| 10:00 | **Exercise begins** - Team assembles | Pre-exercise briefing, roles assigned |
| 10:05 | Baseline metrics captured | Screenshots of healthy state taken |
| 10:10 | Simulated failure triggered | `kubectl delete pod postgres-0 --grace-period=0 --force` |
| 10:11 | Alerts fired: DatabaseDown, PodCrashLooping | PagerDuty notification sent |
| 10:12 | IC acknowledged alert | Bob (IC) started investigation |
| 10:14 | Application errors confirmed | Error rate spiked to 100% |
| 10:16 | Database logs examined | Pod not restarting, StatefulSet stuck |
| 10:20 | **GAP IDENTIFIED**: Standby promotion procedure unclear | Team searched for runbook |
| 10:25 | Manual failover initiated | Attempted to promote postgres-1 to primary |
| 10:30 | **BLOCKER**: Insufficient permissions | kubectl user lacked permission to edit ConfigMap |
| 10:35 | Permissions escalated | Admin access obtained |
| 10:38 | Standby promoted to primary | Updated replication config |
| 10:42 | Connection string updated | Service pointing to new primary |
| 10:45 | Application pods restarted | Forced restart to pick up new config |
| 10:50 | **ISSUE**: Some pods still connecting to old primary | Connection pool not refreshed |
| 10:54 | All pods restarted with scale down/up | `kubectl scale --replicas=0` then back to 3 |
| 10:57 | **Service restored** | All health checks passing |
| 11:00 | Monitoring confirmed recovery | Error rate back to 0%, latency normal |
| 11:05 | Old primary recovered | postgres-0 came back online |
| 11:10 | **ISSUE**: Split-brain risk identified | Two primaries briefly existed |
| 11:15 | Old primary demoted to standby | Manually configured as replica |
| 11:30 | Replication verified | Standby catching up with new primary |
| 12:00 | Exercise debrief | Team discussed findings |
| 12:30 | **Exercise concluded** | Cleanup completed |

**Detection Time**: 1 minute (alert fired)
**Response Time**: 2 minutes (investigation started)
**Resolution Time**: 47 minutes (from failure to full recovery)
**Total Duration**: 2.5 hours (including post-recovery validation)

**RTO Performance**: 47 minutes actual vs. 15 minutes target = **32 minutes over target**

---

## Detection

### How was the incident detected?
- [x] Automated monitoring alert
- [ ] Customer report
- [ ] Internal user report
- [ ] Scheduled health check
- [ ] Other

### What worked well?
- Prometheus alerts fired within 1 minute
- PagerDuty notification delivered successfully
- Database health check accurately detected failure
- Application-level database connection errors logged clearly

### What didn't work?
- No alert differentiated between primary and standby failure
- No automatic failover triggered
- Runbook link in alert was broken
- No alert for split-brain condition

### Time to Detection
- **Actual**: 1 minute
- **Target**: 1 minute
- **Status**: Met target

---

## Response

### Exercise Response Team
- **Incident Commander**: Bob Martinez
- **Technical Lead**: Alice Chen
- **Database SME**: Alice Chen
- **Application Owner**: Chris Johnson (observer)
- **Communications Lead**: N/A (staging only)

### Response Timeline
- **Time to Acknowledge**: 2 minutes
- **Time to Engage**: 0 minutes (pre-assembled)
- **Time to Diagnose**: 6 minutes (quickly identified as primary failure)
- **Time to Mitigate**: 41 minutes (from diagnosis to recovery)

### What went well?
- Team pre-assembled and prepared
- Clear roles and communication
- Good documentation of steps taken
- Systematic approach to troubleshooting
- Good use of Slack for coordination

### What could be improved?
- Runbook was incomplete and hard to find
- Multiple permission issues blocked progress
- No clear playbook for StatefulSet failures
- Manual steps were error-prone
- No automated failover mechanism

---

## Resolution

### Immediate Mitigation

```bash
# 1. Identified the healthy standby
kubectl get pods -n staging -l app=postgres

# 2. Promoted standby to primary (manual process)
kubectl exec -it postgres-1 -n staging -- psql -U postgres -c "SELECT pg_promote();"

# 3. Updated ConfigMap with new primary
kubectl edit configmap postgres-config -n staging
# Changed POSTGRES_PRIMARY_HOST from postgres-0 to postgres-1

# 4. Updated Service to point to new primary
kubectl patch service postgres -n staging -p '{"spec":{"selector":{"statefulset.kubernetes.io/pod-name":"postgres-1"}}}'

# 5. Restarted application pods
kubectl rollout restart deployment/app -n staging

# 6. When old primary recovered, demoted it
kubectl exec -it postgres-0 -n staging -- psql -U postgres -c "SELECT pg_ctl promote();"
# Reconfigured as standby
```

### Permanent Fix
*Items to implement for production readiness*

- Implement Patroni for automated failover (P0)
- Create comprehensive failover runbook (P0)
- Set up PgBouncer for connection pooling (P1)
- Implement proper RBAC for database operations (P0)
- Add split-brain detection and prevention (P0)

### Verification

- All application health checks passing
- Database replication status verified
- No errors in application logs
- Prometheus metrics confirmed recovery
- Load test executed successfully

---

## Action Items

### Prevent Recurrence (Prevent Manual Intervention)
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| Implement Patroni for auto-failover | Alice Chen | P0 | 2024-01-31 | [x] | #234 |
| Set up PgBouncer connection pooling | Alice Chen | P1 | 2024-02-15 | [x] | #235 |
| Configure proper RBAC for DB ops | Bob Martinez | P0 | 2024-01-25 | [x] | #236 |
| Add split-brain prevention (fencing) | Alice Chen | P0 | 2024-02-01 | [x] | #237 |
| Implement automated backup verification | Bob Martinez | P1 | 2024-02-28 | [x] | #238 |

### Improve Detection
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| Add alert: DatabasePrimaryDown | Alice Chen | P0 | 2024-01-20 | [x] | #239 |
| Add alert: DatabaseSplitBrain | Alice Chen | P0 | 2024-01-20 | [x] | #240 |
| Add alert: ReplicationLag > 10s | Alice Chen | P1 | 2024-01-25 | [x] | #241 |
| Create dashboard: DB HA status | Bob Martinez | P2 | 2024-02-15 | [x] | #242 |

### Improve Response
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| Create database-failover.md runbook | Bob Martinez | P0 | 2024-01-18 | [x] | #243 |
| Update database-connection-exhausted.md | Bob Martinez | P1 | 2024-01-20 | [x] | #244 |
| Add runbook links to all DB alerts | Alice Chen | P1 | 2024-01-22 | [x] | #245 |
| Create break-db.sh script | Bob Martinez | P2 | 2024-01-20 | [x] | #246 |
| Create fix-db.sh script | Bob Martinez | P2 | 2024-01-20 | [x] | #247 |

### Process Improvements
| Action | Owner | Priority | Due Date | Status | Issue Link |
|--------|-------|----------|----------|--------|------------|
| Schedule monthly game day exercises | Bob Martinez | P1 | 2024-02-01 | [x] | #248 |
| Create game day playbook template | Bob Martinez | P2 | 2024-02-15 | [x] | #249 |
| DB failover training for all SREs | Alice Chen | P1 | 2024-02-28 | [x] | #250 |
| Document RTO/RPO requirements | Product Team | P1 | 2024-02-15 | [x] | #251 |

---

## Lessons Learned

### What went well?
1. **Team coordination**: Clear roles and good communication throughout the exercise
2. **Monitoring coverage**: Alerts fired quickly and accurately detected the failure
3. **Application resilience**: Applications logged errors clearly and were ready to reconnect
4. **Documentation**: Team documented all steps taken for later review
5. **Systematic approach**: Methodical troubleshooting prevented making the situation worse

### What went poorly?
1. **Manual failover complexity**: Too many manual steps, too error-prone
2. **Incomplete runbooks**: Existing documentation didn't cover this scenario
3. **Permission issues**: Multiple delays due to insufficient access
4. **No automated failover**: Complete reliance on manual intervention
5. **Split-brain risk**: Briefly had two primaries, could have caused data corruption
6. **Connection pool issues**: Application didn't automatically reconnect to new primary
7. **RTO exceeded**: 47 minutes vs. 15 minute target (3x longer)

### Where did we get lucky?
1. **Staging environment**: This was a test, not a real incident affecting customers
2. **Team availability**: All subject matter experts were already assembled
3. **Low traffic**: Minimal test traffic made validation easier
4. **No data corruption**: Despite split-brain risk, no data was corrupted
5. **Standby was healthy**: Standby was fully caught up and ready to promote

---

## Supporting Information

### Exercise Plan
- [Link to exercise plan document]
- [Objectives and success criteria]

### Metrics/Graphs
- [Screenshot: Pre-exercise baseline metrics]
- [Screenshot: Error rate during failover]
- [Screenshot: Recovery confirmation]
- [Grafana dashboard: Database HA status]

### Logs
```
# postgres-0 pod deletion
2024-01-15T10:10:15Z Pod postgres-0 deleted (grace period 0, forced)

# Prometheus alert
2024-01-15T10:11:23Z FIRING: DatabaseDown{instance="postgres-0:5432"}

# Application errors
2024-01-15T10:11:45Z [ERROR] Database connection failed: could not connect to server
2024-01-15T10:11:46Z [ERROR] Connection timeout after 5s

# Standby promotion
2024-01-15T10:38:12Z postgres-1: LOG: received promote request
2024-01-15T10:38:13Z postgres-1: LOG: redo done at 0/3000028
2024-01-15T10:38:14Z postgres-1: LOG: selected new timeline ID: 2
2024-01-15T10:38:15Z postgres-1: LOG: database system is ready to accept connections

# Recovery
2024-01-15T10:57:30Z All health checks passing
2024-01-15T10:57:31Z Error rate: 0%
```

### Related Incidents
- None (first exercise of this type)

### References
- [Original (incomplete) runbook]
- [PostgreSQL HA documentation]
- [Exercise Slack thread: #sre-exercises]
- [Exercise planning doc]

---

## Review and Sign-off

| Reviewer | Role | Date | Approved |
|----------|------|------|----------|
| Alice Chen | SRE Lead | 2024-01-16 | [x] |
| Chris Johnson | Engineering Lead | 2024-01-17 | [x] |
| Sarah Kim | VP Engineering | 2024-01-18 | [x] |

---

## Follow-up Review

**Review Date**: 2024-02-15 (30 days after exercise)
**Reviewer**: Bob Martinez

### Action Item Completion Status
- [x] All P0 items completed
- [x] All P1 items completed
- [x] All P2 items in progress

### Effectiveness of Improvements
- **Patroni implemented**: Automated failover now working, tested in subsequent exercise
- **RTO improved**: Second exercise showed 3-minute failover (vs. 47 minutes initially)
- **Runbooks created**: New runbooks used successfully by on-call engineer
- **Monthly exercises**: Scheduled and ongoing, team confidence improving

### Subsequent Exercises
- **2024-02-12**: Redis failover exercise
- **2024-03-11**: Network partition simulation
- **2024-04-15**: Database failover re-test (with Patroni) - **3 minute RTO achieved!**

---

## Notes

This game day exercise was incredibly valuable. While it revealed significant gaps in our procedures and automation, conducting it in a controlled environment allowed us to identify and fix these issues before they could impact production. The 47-minute failover time was sobering and drove home the need for automation.

Key insights:
- **Manual procedures don't scale**: Any manual process will be slow and error-prone under pressure
- **Testing is essential**: Documentation alone isn't enough; regular testing validates readiness
- **Automation is critical**: Patroni reduced our failover time from 47 minutes to 3 minutes
- **Permissions matter**: Ensure on-call engineers have necessary access before an incident
- **Document everything**: Having detailed notes from the exercise made action items clear

This exercise significantly improved our production readiness and team confidence.

---

**Document History**:
- 2024-01-15: Initial draft created during exercise debrief
- 2024-01-16: Review completed, action items assigned
- 2024-01-18: Final version published
- 2024-02-15: 30-day review completed, marked as success
