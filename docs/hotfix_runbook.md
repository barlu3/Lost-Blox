# Hotfix Runbook

Ship a critical fix from identification to live in **≤ 2 hours**. Time estimates
per step are cumulative targets, not hard limits — but if any step blows its
budget, escalate in `#oncall` rather than rushing the next one.

| Step | Action | Target | Cumulative |
|---|---|---|---|
| 1 | Create branch `hotfix/<issue_id>` from `main` | 5 min | 0:05 |
| 2 | Apply the fix; update `CHANGELOG.md` under `## [Unreleased]` | 40 min | 0:45 |
| 3 | `rojo build default.project.json -o build.rbxl` — verify no compile errors | 5 min | 0:50 |
| 4 | Push branch → GitHub Actions runs lint + unit tests | 15 min | 1:05 |
| 5 | Lead reviews and approves the PR | 20 min | 1:25 |
| 6 | Merge to `main` → Actions builds and publishes via `rojo upload` | 10 min | 1:35 |
| 7 | In Roblox, confirm the live place is on the new version | 5 min | 1:40 |
| 8 | Watch `SessionLogger` for error spikes for 30 min | 30 min | 2:10* |

\* Monitoring overlaps with "done"; the fix is live at step 7 (~1:40). The 2-hour
SLA is met when the change is live and not actively regressing.

## Detailed steps

1. **Branch.** `git checkout main && git pull && git checkout -b hotfix/<issue_id>`.
2. **Fix + changelog.** Make the minimal change. Add a `CHANGELOG.md` entry
   describing the user-visible effect and the issue id.
3. **Local build.** `rojo build default.project.json -o build.rbxl`. A clean
   build is the gate before pushing — never push a build that fails locally.
4. **CI.** Push the branch and open a PR. `ci.yml` runs the Luau syntax check,
   the lune unit suite, and the Python tool tests. All must pass.
5. **Review.** A second engineer (lead during an incident) approves. Even hotfixes
   get one review — the cost is 20 minutes, the cost of a bad hotfix is the SLA.
6. **Merge + publish.** Merging to `main` triggers `deploy.yml`, which rebuilds
   and runs `rojo upload` against the live place using the stored
   `ROBLOSECURITY` cookie and `PLACE_ID` secrets.
7. **Verify live.** In Roblox Studio / the Creator Dashboard, confirm the live
   place version matches the merge commit.
8. **Monitor.** Watch the `SessionLogger` ingest for `session_end` crash spikes
   and new error events for 30 minutes.

## Rollback

A hotfix that regresses is itself an incident. Roll back explicitly — do **not**
try to fix-forward under time pressure:

1. `git revert <merge_commit_sha>` on `main` (creates a clean inverse commit).
2. Push the revert. `deploy.yml` runs again and republishes the previous-good build.
3. Repeat runbook steps 3–7 for the revert (build → CI → verify live).
4. Confirm the live place version is the reverted commit and error rates recover.
5. Post-incident: open a tracking issue for the root cause; the revert bought
   time, it did not fix the bug.

## Secrets

`ROBLOSECURITY` and `PLACE_ID` live only in GitHub repo secrets, never in the
codebase. CI fails if `ROBLOSECURITY` is found in any tracked file. The cookie
must be rotated when it expires (publish will start returning 401).
