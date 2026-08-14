# K=1 calibration module seams

Design-aware K=1 calibration modules have four scientific responsibilities:
declare their generator and regime policy, assess each known-truth replicate,
aggregate typed evidence, and render the module's operating map and caption.
Those responsibilities stay with the independent-time, repeated-subject, and
high-dimensional modules because their estimands, non-estimability rules, plot
data, and scientific language differ.

The cross-cutting scientific-artifact publication module owns only the
filesystem publication mechanism described in
[`scientific-artifact-publication.md`](scientific-artifact-publication.md):

- the seven governed evidence files and exact manifest shape;
- rejection of undeclared files, unsafe paths, missing files, and digest drift;
- staging-directory cleanup and one atomic move into the final address.

Each scientific module supplies its own assessment validator, plot function,
display-data attribute and any factor-to-character normalization needed for
stable CSV output. It also owns replay comparison for CSV derivatives,
captions, environment identity, and the content-addressed directory name, and
retains its public publish and verify functions.
Contributors adding a new calibration design should reuse this publication
mechanism, but must not create a generic scientific-result class or weaken the
module-specific validator, caption, typed non-estimability, or plotting rules.

The shared module is internal. Public APIs and serialized assessment and
artifact formats remain module-specific and unchanged. Revised K=1 acceptance
uses the same filesystem module through its own scientific adapter.

`locate_k1_operating_domain()` is a separate public comparison seam. It accepts
a declared sampling design, one compatible design assessment, a
high-dimensional assessment, and versioned observed diagnostics. Its typed
result retains the exact calibration cells that bracket an experiment point or
uncertainty interval. It returns out-of-domain evidence without a recovery
probability when design, feature count, signal/noise range, covariance regime,
or diagnostic coverage is incompatible. This compares operating
characteristics; it never projects biological observations into a synthetic
state space or quasi-potential landscape.

The locator keeps sampling-design and high-dimensional probabilities as four
separate ranges: recovery and downstream estimability from each calibration
module. It does not combine them because no scientifically validated rule yet
defines a joint probability. For destructive time courses, exact design
matching includes total retained biological samples as well as the minimum,
maximum, and mean retained count per declared condition-time cell. A displayed
signal domain is restricted to the feature-count cells that bracket the
experiment; calibration evidence from another feature count cannot enlarge it.
