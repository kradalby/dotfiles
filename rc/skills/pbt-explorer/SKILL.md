---
name: pbt-explorer
description: Bootstrap property-based tests, explore coverage gaps, or run a timed soak. Use for sustained bug hunting with generators, state models, and targeted mutations.
---

# Property-based exploration

**“Explore the install wizard until 9 a.m.”** gives the whole session a deadline.
Choose each soak length from throughput and the histories reached. Allow time for
reproduction, fixes, and reporting. **“Soak for eight hours”** requests eight
hours of actual testing. Use the question tool when the target or overall time
budget is unclear.

## Start from the target

- **Bootstrap:** Pick one consequential contract. Build a generator and a property that exercise it through the cheapest layer where failure is observable.
- **Deepen coverage:** Read existing properties, regressions, and the last run report. Choose a behavior whose reach or detection remains uncertain.
- **Soak existing tests:** Run the requested suite and preserve findings. Follow the requested scope for fixes and test changes.

For stateful behavior, name the states, actions, allowed outcomes, and what must
survive each action. Derive expectations from the contract. Use Rapid for Go and
Bombadil for browser workflows. The [field guide](references/field-guide.md)
covers property design, composable generators, runner controls, and replay.

## Explore until the session ends

Start with a short baseline from known state. Confirm fresh scenarios execute,
the target sequence occurs, and its assertion fires. Record the revision,
command, and starting conditions. Soak with fresh randomness across runs.

- **Failure:** Preserve the original evidence. Shrink, replay, and verify the same contract fails. Trace the cause to the product, model, or harness. Record unresolved failures with enough evidence for another session.
- **Target seldom reached:** Inspect discarded inputs, action weights, and prerequisite states. Change one generator or action mix. Measure whether the next run reaches the missing history.
- **Target reached, outcome unchecked:** Observe the consequence where it becomes visible. A save followed by a read from the same form can miss a dropped write.
- **Quiet run with exercised assertions:** Probe one plausible fault in an isolated checkout. Predict which test should fail and why. If the fault survives, check reach, observation, and whether the fault changes the contract. Close a real gap at the lowest suitable layer. Demonstrate the test passes on clean code and fails for the predicted reason with the fault. Discard the mutation.
- **Target reached and detection demonstrated:** Keep soaking while values, histories, or interleavings can vary. Monitor progress and resume exploration after each investigation.

## Leave reviewable evidence

For each confirmed product bug, commit the smallest failing regression first,
then its production fix separately. Verify the same test on both revisions.
Keep shared generators and harness changes in their own commits. For a test gap
alone, retain the improved test.

**After each run**, report actual test time, completed scenarios, target
transitions and assertions exercised, findings, and the reason for the next
experiment. Identify unavailable measurements explicitly.

**At session end**, summarize what worked, what failed and why, fixes with their
regression/fix commit pairs, remaining gaps, and the next experiment. Include
replay commands and artifact locations. Account for testing and investigation
time separately.
