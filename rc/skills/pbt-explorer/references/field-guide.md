# Designing a useful exploration

## Find a contract with leverage

Look for many inputs or histories with one independently checkable expectation.
Try a postcondition, a conserved quantity, agreement with a simpler model, or
a relationship between executions. Sorting should preserve the input multiset
as well as produce ordered output. An implementation that always returns an
empty list passes the ordering check alone. For a small finite domain, enumerate
it; a known, isolated counterexample fits a unit test.
[How to Specify It!](https://research.chalmers.se/publication/517894/file/517894_Fulltext.pdf)
· [Metamorphic testing](https://arxiv.org/abs/2002.12543)
· [SmallCheck](https://pure.york.ac.uk/portal/en/publications/smallcheck-and-lazy-smallcheck-automatic-exhaustive-testing-for-s-2/)

## Generate reachable, distinguishable histories

Sample the generator. Classify cases in domain terms: new or existing record,
empty or populated, first save or retry. Count discarded candidates and
assertion opportunities. Draw dependent inputs from earlier actions. Construct
valid cases directly when filtering makes them rare. Give invalid actions their
own expected response and check what state survives. For recursive values,
inspect the resulting sizes and depths.
[QuickCheck](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf)
· [Beginner’s Luck](https://arxiv.org/abs/1607.05443)
· [Branching Processes for QuickCheck Generators](https://arxiv.org/abs/1808.01520)

For a wizard, generate two distinct choices, save each in turn, and reopen a
fresh instance. The model remembers the last acknowledged choice. The reopened
instance supplies the observation. One save, two identical choices, or a read
from the original form can all hide a stale value. Compose choice and history
generators independently of browser selectors and storage calls. Share them
when another component exercises the same contract.
[PropEr stateful properties](https://propertesting.com/book_stateful_properties.html)
· [Hypothesis state machines](https://hypothesis.readthedocs.io/en/latest/stateful.html)
· [Rapid queue model](https://github.com/flyingmutant/rapid/blob/master/example_statemachine_test.go)

## Decide whether more time buys more exploration

Count histories where the property applies and where the consequence was
checked. If resets dominate, try a run with fewer resets to reach deeper
states. Keep a separate run that stresses recovery. A quantity such as completed
stages can guide search while the contract independently judges correctness.
Branch coverage can point to an unvisited path; a hit says little about what
the test observed.
[Swarm Testing](https://experts.nau.edu/en/publications/swarm-testing/)
· [Targeted PBT](https://proper-testing.github.io/papers/issta2017.pdf)
· [Worked search example](https://proper-testing.github.io/tutorials/PropEr_testing_with_search_strategies.html)
· [Coverage-guided PBT](https://lemonidas.github.io/pdf/FuzzChick.pdf)

Use a short run to establish that a changed generator reaches its target.
Extend it for rarer combinations and longer histories. A Python corpus study
found many detectable mutations early; its results supply no universal
input count or soak duration.
[Empirical Evaluation of PBT in Python](https://cseweb.ucsd.edu/~mcoblenz/assets/pdf/OOPSLA_2025_PBT.pdf)

## Calibrate detection with a fault

For the two-save history, suppress the second write while returning success.
Predict that reopening yields the first choice. A setup crash leaves that
prediction untested. If the mutation survives, check whether the second write
ran, whether the test reopened, and whether it compared distinct values.
A behavior-preserving change needs no new assertion. A failed write or restart
can also become a permanent generated event when recovery is part of the
contract.
[Practical Mutation Testing at Scale](https://research.google/pubs/practical-mutation-testing-at-scale-a-view-from-google/)
· [Property-Based Mutation Testing](https://arxiv.org/abs/2301.13615)
· [FoundationDB simulation](https://www.foundationdb.org/files/fdb-paper.pdf)

## Preserve a replay

Keep the original input or trace, failing observation, revision, and starting
state. Reset persistent data between independent cases. Let the runner control
random choices. Shrink while retaining the prerequisite and the same failure.
For timing-sensitive behavior, record event order and relevant clock or
schedule inputs. If replay diverges, keep the evidence and investigate what
escaped the harness.
[Hypothesis reduction paper](https://spiral.imperial.ac.uk/entities/publication/86feb3ca-6417-4174-a844-92d5eb02a2ae)
· [PropEr shrinking](https://propertesting.com/book_shrinking.html)
· [Flaky failures](https://hypothesis.readthedocs.io/en/latest/tutorial/flaky.html)
· [QuickCheck and PULSE](https://smallbone.se/papers/finding-race-conditions.pdf)

**Rapid.** Use the project's Go test entrypoint. For repeated package tests,
use `-count=1` to force execution. Size batches with `-rapid.checks` and allow
enough Go test timeout for each batch and reduction. Keep Rapid's fail file
and printed replay command. Reserve fixed seeds for diagnosis. Ordinary Rapid
runs sample the supplied generators; for a suitable fast target,
`rapid.MakeFuzz` exposes the property to Go's coverage-guided fuzzer.
[Rapid](https://github.com/flyingmutant/rapid)
· [Runner flags](https://github.com/flyingmutant/rapid/blob/master/engine.go)
· [Go test caching](https://pkg.go.dev/cmd/go#hdr-Test_packages)
· [Go fuzzing](https://go.dev/doc/security/fuzz/)

**Bombadil.** Keep the trace and printed reproduction command. Inspect the
actions and before/after snapshots at the first violated property. Replay
with matching options and backend state. Where the installed version supports
shrinking, keep the reduced trace beside the original. For an eventual UI
outcome, capture the expected value when the triggering action occurs. Count
how often that trigger occurred.
[Trace inspection](https://antithesishq.github.io/bombadil/browser/4.3-inspecting-test-results.html)
· [Replay](https://antithesishq.github.io/bombadil/browser/4.1-reproducing-violations.html)
· [Shrinking](https://antithesishq.github.io/bombadil/browser/4.2-shrinking-violations.html)
· [Eventual outcome example](https://antithesishq.github.io/bombadil/browser/3.7.4-contextful-guarantee-notification-includes-past-value.html)

Use the installed tool's help for version-specific flags. Revisit upstream
research when a concrete modeling, generation, or replay problem remains open.
