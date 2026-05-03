# Temporal Design

## General Overview

OrchidApp models the lifecycle and care of plants as a user-correctable biological narrative supported by structural temporal invariants.

The system is not designed as an immutable event log.
Instead, it balances:

-   user-driven narrative accuracy
-   system-enforced lifecycle correctness

Time within OrchidApp serves two distinct but coordinated purposes:

-   to represent meaningful calendar-based events for the user
-   to provide precise ordering and structural alignment within the system

### Date-Led User Experience

User interaction with time is intentionally simplified.

-   Users interact with calendar dates, not timestamps
-   Time components are not displayed in the UI
-   Time input is not required for narrative actions

Where temporal precision is required:

-   the system assigns the time component
-   or exposes it only within controlled structural operations

This ensures the user experience remains intuitive while preserving internal consistency.

### System-Assigned Temporal Precision

Internally, OrchidApp uses DATETIME to:

-   establish deterministic ordering
-   enforce temporal adjacency
-   maintain structural continuity

The time component:

-   is system-assigned for narrative domains
-   is preserved once created
-   is not intended for user manipulation in most contexts

This enables stable same-day ordering without burdening the user with unnecessary detail.

### Narrative vs Structural Time

OrchidApp distinguishes between two temporal roles:

#### Narrative Time

Represents user-correctable events and observations.

Characteristics:

-   date-led input
-   editable
-   reversible
-   may be incomplete or approximate
-   used for horticultural history and analysis

Examples:

-   observations
-   repotting
-   flowering

#### Structural Time

Represents lifecycle boundaries and system-critical temporal relationships.

Characteristics:

-   enforced by SQL
-   not freely editable
-   must remain internally consistent
-   drives lifecycle topology and adjacency

Examples:

-   plant lifecycle (acquisitionDate, endDate when structurally set)
-   location history (startDateTime, endDateTime)
-   split lifecycle (splitDateTime)

### Stable Same-Day Ordering

OrchidApp guarantees stable ordering of events occurring on the same calendar date.

This is achieved by:

-   storing events as DATETIME
-   assigning or preserving time components
-   preventing time mutation during edits

No additional sequencing mechanism is used.

Ordering is determined solely by temporal values.

### Lifecycle Dominance

Plant lifecycle boundaries define the outer limits of all temporal activity.

-   A plant cannot have active events beyond its lifecycle end
-   Structural timelines (e.g. location) must align with lifecycle boundaries
-   Narrative events are constrained by lifecycle state

Lifecycle termination acts as a temporal boundary across all domains.

### Structural Integrity Over Narrative Flexibility

Where narrative and structural concerns conflict:

#### Structural integrity takes precedence

This ensures:

-   no overlapping timelines
-   no broken lineage
-   no ambiguous state

Narrative flexibility is preserved only where it does not compromise system invariants.

### Temporal Mutability Model

OrchidApp supports user correction of narrative data.

-   Users may edit dates to correct mistakes
-   Edits do not rewrite system-assigned time components
-   Structural timestamps are immutable once established

This allows correction without destabilising temporal relationships.

### Naming and Schema Reality

Temporal field naming reflects historical design intent and may not strictly align with current storage datatype or final semantic interpretation.
Field renaming for naming purity is explicitly out of scope.

Temporal meaning must be derived from:

-   system behaviour
-   lifecycle rules
-   schema comments

Not from naming conventions alone.

### Schema as Temporal Contract

Temporal behaviour is documented and enforced through:

-   stored procedures
-   constraints and triggers
-   column comments

Column comments are part of the architectural contract and must describe:

-   temporal meaning
-   lifecycle role
-   editability constraints

All temporal documentation must be consistent with schema-level definitions.

### Explicit Non-Goals

The following are intentionally not implemented:

-   Event sequence columns
-   Timestamp rebasing or retroactive reordering
-   Manual same-day event ordering controls

Temporal ordering is strictly derived from DATETIME values.

### Future Considerations

The system acknowledges potential future extensions:

-   controlled editing of structural timestamps (e.g. split)
-   improved temporal validation across domains
-   analytical use of narrative event types
-   multi-user temporal conflict handling

These must be implemented without violating existing temporal invariants.

## Plant Temporal Model

### Overview

The plant entity represents the primary biological lifecycle boundary within OrchidApp.
Temporal behaviour associated with plants models the plant’s presence within the collection rather than attempting to represent a complete biological history.

Plant temporal data therefore supports:

-   lifecycle start (entry into collection)
-   lifecycle termination (exit from collection)
-   structural lifecycle pivots (e.g. split)
-   user-correctable narrative adjustments

Temporal semantics for plants combine both narrative flexibility and structural invariants.

### Temporal Fields

The plant table contains two lifecycle temporal fields:

-   acquisitionDate
-   endDate

Both are stored as DATETIME and allow NULL.

#### acquisitionDate

Represents the plant’s entry into the collection lifecycle.

Characteristics:

-   May be unknown for historically acquired plants and therefore may be NULL
-   Initially narrative in nature
-   Becomes structurally significant when set via a Split lifecycle event
-   For plants created by Split, this timestamp becomes a lifecycle anchor and must not be editable

#### endDate

Represents the termination of the plant’s presence within the collection.

Characteristics:

-   NULL indicates the plant is currently active within the collection
-   May be set manually by the user to reflect:
    -   death
    -   disposal
    -   transfer
    -   loss
-   When set as part of a Split lifecycle event, this timestamp becomes structural and must not be editable

### Lifecycle Termination Behaviour

Setting endDate represents closure of the plant’s current lifecycle segment within the collection.

System behaviour:

-   Lifecycle termination is applied via stored procedure logic
-   When set, endDate must cascade only to the currently open plant location record
-   No broader temporal cascade is performed

Lifecycle termination does not affect record existence:

-   isActive remains 1
-   Record deletion is managed separately via soft-delete semantics

### Reactivation Behaviour

Clearing endDate reactivates the plant’s lifecycle.

Reactivation rules:

-   Previous location history must not be reopened
-   User must explicitly assign a new location
-   Reactivation represents the start of a new lifecycle segment within the collection

### Split Lifecycle Invariants

Plant Split represents a structural lifecycle pivot.

Temporal invariants:

-   Parent plant endDate must equal the Split timestamp
-   Child plant acquisitionDate must equal the same Split timestamp
-   These timestamps must be immutable following Split

Split therefore converts narrative lifecycle timestamps into structural anchors.

### Narrative vs Structural Temporal Roles

Plant temporal fields exhibit dual semantic roles:

|Context|Temporal Nature|
|-------|---------------|
|Manual acquisition or termination|Narrative and user-correctable|
|Split lifecycle boundary|Structural and immutable|

This distinction is fundamental to OrchidApp’s lifecycle modelling approach.

### UI Temporal Behaviour (Current Direction)

User interaction with plant lifecycle time follows a date-led model:

-   Users enter and edit calendar dates
-   Time components exist for system ordering and lifecycle anchoring
-   Time entry is not intended to be user-driven

Future UI behaviour should:

-   Collect date only for lifecycle edits
-   Assign or preserve time component at system level

### Accessibility of Ended Plants

End-dated plants represent completed lifecycle segments.

System direction:

-   End-dated plants will remain viewable
-   No new events or lifecycle edits should be permitted while a plant is in an ended state
-   Reactivation restores narrative editability

### Location Lifecycle Interaction

Plant lifecycle termination represents the dominant temporal boundary.

Therefore:

-   Ending a plant must close any open location occupancy record
-   Reactivation must not restore previous location automatically

Location history remains temporally truthful and non-rewritten.

## Repotting Temporal Model

### Overview

Repotting represents a narrative horticultural event within OrchidApp.
It reflects a change in growing medium or container but does not represent a structural lifecycle boundary.

Repotting exists to support:

-   horticultural history tracking
-   cultivation analysis
-   chronological narrative construction within the plant history view

Repotting does not influence plant lifecycle state, lineage, or location timeline structure.

### Temporal Field

The repotting table contains a single temporal field:

-   repotDate

This field currently exists as a DATE but is expected to transition to DATETIME to support unified historical ordering across all plant-related events.

#### repotDate

Represents the date on which a repotting event occurred.

Characteristics:

-   Mandatory for all repotting records
-   Narrative in nature
-   Fully user-editable
-   Fully deletable
-   Not structurally constrained by lifecycle invariants
-   Not a lifecycle pivot

Future temporal handling direction:

-   User interaction should remain date-led
-   Time component will be system-assigned
-   Editing must only alter the date component
-   System-assigned time must remain unchanged after creation

### Narrative Temporal Behaviour

Repotting events are considered bounded narrative events.

System characteristics:

-   Repotting does not affect plant lifecycle state
-   Repotting does not affect plant location lifecycle
-   Repotting does not impose structural temporal ordering constraints
-   Repotting exists solely as part of the chronological horticultural narrative

Repotting records may be:

-   created
-   edited
-   deleted

subject only to plant lifecycle state.

### Lifecycle Interaction Rules

Repotting must respect plant lifecycle boundaries.

-   Repotting events must not be added to a plant with a non-NULL endDate
-   Repotting does not modify lifecycle timestamps
-   Repotting does not alter lineage or lifecycle segmentation

No global validation currently exists to prevent repotting prior to acquisitionDate.
Temporal consistency outside structural domains is intentionally permissive.

### Ordering Semantics

Repotting has no independent ordering logic.

Temporal ordering occurs only when constructing the unified plant history view, where repotting events are combined with:

-   observations
-   flowering
-   location changes
-   lifecycle events

The planned transition to DATETIME storage supports stable chronological ordering within this aggregated narrative.

### Interaction with Split Lifecycle

Repotting currently has no direct interaction with Split.

Planned future behaviour:

-   Split may capture growth medium information
-   This may require automatic creation of a repotting record at Split time
-   Such automatically generated repotting timestamps must be strictly later than the Split lifecycle timestamp

This interaction does not change the narrative classification of repotting.

### Structural Classification

Repotting is classified as a narrative temporal event.

It does not:

-   define lifecycle boundaries
-   enforce structural temporal invariants
-   control lineage adjacency
-   participate in temporal propagation

Its temporal role is limited to historical narrative sequencing.

## Flowering Temporal Model

### Overview

Flowering represents a narrative horticultural interval event within OrchidApp.
It captures the period during which a plant is in flower and contributes to the chronological plant history.

Flowering is not a structural lifecycle element and does not influence plant lineage, lifecycle boundaries, or location timelines.

### Temporal Fields

The flowering table contains two temporal fields:

-   startDate
-   endDate

Both currently exist as DATE and represent a bounded temporal interval.

The domain is expected to transition to DATETIME to support consistent ordering across the unified plant history.

#### startDate

Represents the start of a flowering period.

Characteristics:

-   Mandatory
-   Narrative in nature
-   Fully user-editable
-   Not structurally constrained
-   Not a lifecycle pivot

#### endDate

Represents the end of a flowering period.

Characteristics:

-   Optional
-   NULL indicates an ongoing flowering period
-   Fully user-editable
-   Not structurally constrained
-   Does not define lifecycle boundaries

### Interval Semantics

Flowering is modelled as a bounded interval:

-   startDate defines the beginning of the interval
-   endDate defines the end of the interval
-   NULL endDate represents an open interval (currently flowering)

System behaviour:

-   Flowering intervals may overlap, although this is not desirable
-   Multiple flowering records may exist for a plant across different periods
-   No enforced validation currently exists for interval consistency

### Narrative Temporal Behaviour

Flowering is a narrative event domain.

Characteristics:

-   Fully editable
-   Fully deletable
-   No structural temporal invariants
-   No propagation behaviour
-   No lifecycle authority

Flowering contributes only to the horticultural narrative of the plant.

### Lifecycle Interaction Rules

Flowering must respect plant lifecycle boundaries:

-   Flowering must not be created or modified once a plant has a non-NULL endDate
-   Future UI exposure of ended plants must enforce read-only behaviour

Planned behaviour:

-   When a plant is ended, any open flowering interval must be closed by setting endDate

No validation currently exists to prevent flowering prior to acquisitionDate.

### Ordering Semantics

Flowering has no independent ordering logic.

Temporal ordering occurs only within the aggregated plant history view, where flowering intervals are combined with:

-   repotting
-   observations
-   location changes
-   lifecycle events

Flowering is presented as a single record showing:

-   start date
-   end date (if present)

Transition to DATETIME will support stable ordering within this combined timeline.

### Structural Classification

Flowering is classified as a narrative interval event.

It does not:

-   define lifecycle boundaries
-   enforce temporal adjacency
-   participate in structural propagation
-   influence lineage or location timelines

### Future Temporal Direction

-   Storage will transition from DATE to DATETIME
-   User interaction will remain date-only
-   System will assign and preserve the time component
-   No change is planned for open interval handling

## Observation Temporal Model

### Overview

plantevent is OrchidApp’s multi-purpose narrative event table. It began as a general note mechanism, then evolved into a typed event model that also supports photo anchoring and quick-action feeding records.

It currently supports four observation types:

-   Note
-   Photo
-   Growth
-   Bloom

The table represents point-in-time plant events that contribute to the chronological plant history. These events are not structural lifecycle records, but they are richer than free-text notes because event type supports later analysis.

### Temporal Field

The table contains a single temporal field of interest:

-   eventDateTime

#### eventDateTime

Represents the point in time at which the observation event occurred.

Characteristics:

-   Mandatory
-   Stored as DATETIME
-   User interaction remains date-led
-   Time component should be system-assigned
-   Fully editable
-   Fully deletable
-   Not a structural lifecycle pivot
-   Supports multiple same-day events

### Narrative Event Behaviour

Observation events are typed narrative point events.

Characteristics:

-   Fully editable
-   Fully deletable
-   Event type is fixed after creation
-   eventDetails may be blank
-   Photo, Growth and Bloom events begin with default descriptive text, which may be edited or removed
-   Photo events do not differ temporally from other observation types

These events do not define structural lifecycle boundaries, but their typed nature allows analytical use.

### Lifecycle Interaction Rules

Observation events must respect plant lifecycle boundaries.

-   Events must not be added or edited once a plant has a non-NULL endDate
-   Future UI exposure of ended plants must enforce read-only behaviour
-   Observation events should not be allowed before plant acquisitionDate

No structural interaction exists with:

-   Split
-   Location lifecycle

Observation events remain simple point-in-time records within the plant narrative.

### Ordering Semantics

Observation events participate directly in the aggregated plant history shown on the Details page.

Temporal ordering requirements:

-   Same-day multiple events are intentionally supported
-   Regularised ordering requires a non-midnight time component
-   eventDateTime must therefore act as the event’s ordering anchor

Time is not user-facing and must not be displayed in the UI.

### Structural Classification

Observation events are classified as typed narrative point events.

They do not:

-   define lifecycle boundaries
-   participate in temporal propagation
-   control location timelines
-   alter lineage structure

Their role is to record meaningful plant activity at a point in time, with optional analytical value driven by observation type.

## Location Temporal Model

### Overview

plantlocationhistory models the structural timeline of where a plant has been located over time.

Each record represents a bounded interval during which a plant occupies a specific location.
This forms a continuous, non-overlapping, forward-only timeline for each plant.

Location history is a structural temporal domain and is SQL-authoritative.
It enforces strict invariants to maintain temporal correctness and continuity.

### Temporal Fields

The location history table contains two primary lifecycle temporal fields:

-   startDateTime
-   endDateTime

#### startDateTime

Represents the timestamp at which a plant enters a location.

Characteristics:

-   Mandatory
-   System-assigned from user-provided date
-   Editable only through controlled structural operations
-   Defines the boundary between location intervals

#### endDateTime

Represents the timestamp at which a plant leaves a location.

Characteristics:

-   Optional
-   NULL indicates the plant is currently in this location
-   Must always be greater than startDateTime
-   Derived through structural operations (move, edit, remove)

### Timeline Semantics

Location history is modelled as a sequence of contiguous, non-overlapping intervals:

````
[startDateTime → endDateTime)
````

System guarantees:

-   At most one open interval per plant (endDateTime IS NULL)
-   No overlapping intervals
-   Strict chronological ordering
-   Contiguous adjacency when moving between locations

This produces a complete and internally consistent location timeline.

### Lifecycle Operations

#### Move

A move operation:

-   Accepts a user-supplied date
-   Converts it to a DATETIME using the current system time
-   Closes the current open interval (if one exists)
-   Creates a new open interval

Constraints:

-   Cannot move to the same location
-   Cannot backdate into existing history
-   Cannot overlap existing intervals

#### Edit

Editing a location record:

-   Allows modification of startDateTime
-   Propagates changes to the previous interval to maintain adjacency
-   Validates against the next interval to prevent overlap

Edits are constrained mutations that preserve timeline integrity.

#### Remove

Removing a location record:

-   Soft deletes the record (isActive = 0)
-   Repairs the timeline by stitching adjacent intervals

Behaviour:

-   Removing current interval reopens previous interval
-   Removing historical interval reconnects previous and next intervals

### Narrative vs Structural Behaviour

Location history is a structural temporal domain.

It is:

-   Not user-freeform
-   Not purely narrative
-   Not directly editable outside controlled operations

All changes must preserve:

-   interval validity
-   adjacency
-   non-overlap
-   single current location invariant

### UI Temporal Behaviour

User interaction follows a hybrid model:

#### Move
-   User enters date only
-   System assigns time component
#### Edit
-   User may adjust both date and time
-   Required to maintain precise interval boundaries
#### Display
-   Only date component is shown
-   Time component is hidden but remains critical internally

### Lifecycle Interaction

Location history is subordinate to plant lifecycle:

-   A plant may have only one current location
-   Location intervals must align with plant lifecycle boundaries

Plant lifecycle termination must close any open location interval.

### Structural Classification

Location history is classified as a structural temporal timeline.

It:

-   enforces strict invariants
-   controls temporal continuity
-   requires SQL authority
-   allows controlled boundary editing
-   does not permit freeform manipulation

## Split Temporal Model

### Overview

The Split domain represents a structural lifecycle pivot within OrchidApp.

A split transforms a single plant into two or more new plants, ending the parent lifecycle and creating new independent lifecycles for each child.

Split is a fully structural temporal operation and is SQL-authoritative.
It enforces strict invariants across plant lifecycle, location history, and lineage.

### Temporal Field

The split domain contains a single temporal field:

-   splitDateTime

#### splitDateTime

Represents the exact timestamp at which the split occurs.

Characteristics:

-   Mandatory
-   Fully specified as DATETIME
-   User-supplied
-   Must not precede the parent plant’s acquisitionDate
-   Acts as a structural lifecycle pivot
-   Drives all temporal alignment across related domains


### Structural Lifecycle Behaviour

A split operation performs an atomic transformation of lifecycle state.

#### Parent plant
-   endDate is set to splitDateTime
-   Parent lifecycle is permanently terminated
#### Child plants
-   New plant records are created
-   Each child:
   -   receives acquisitionDate = splitDateTime
   -   begins a new independent lifecycle
#### Lineage
-   A single plantsplit record represents the split event
-   One or more plantsplitchild records map children to the split
-   Each plant may be split at most once

### Temporal Alignment

Split enforces strict temporal adjacency:
````
parent.endDate == child.acquisitionDate == splitDateTime
````
This ensures:

-   no gaps in lineage
-   no overlap in lifecycle
-   continuity of biological history

### Location Interaction

Split is responsible for maintaining location timeline integrity.

When a split occurs:

-   Any open location interval for the parent plant is closed:
````
plantlocationhistory.endDateTime = splitDateTime
````
Child plants do not inherit location:

-   New location assignments must be explicitly created after split

### Transactional Behaviour

Split is executed via a single stored procedure (spSplitPlant) and is fully transactional.

System guarantees:

-   All lifecycle changes succeed or fail together
-   No partial split states exist
-   Lineage, lifecycle, and location remain consistent

### Structural Classification

Split is classified as a structural temporal pivot.

It:

-   defines lifecycle boundaries
-   enforces temporal adjacency
-   propagates changes across multiple domains
-   is not user-editable through general UI
-   is not narrative in nature

### Constraints and Invariants

The system enforces:

-   A plant may be split only once
-   A split must create at least two child plants
-   The parent plant must be active at time of split
-   splitDateTime must be greater than or equal to the parent lifecycle start
-   Child plants inherit taxonomy and are created as active records

### Narrative vs Structural Behaviour

Split has no narrative flexibility.

It is:

-   not editable through standard workflows
-   not reversible through standard workflows
-   not subject to user correction without specialised tooling

All temporal values produced by split become structural anchors.

### Future Temporal Considerations

Potential future capabilities include:

Controlled editing of splitDateTime
Automatic creation of repotting records during split
Additional validation rules for temporal relationships across domains

These capabilities must preserve existing structural invariants.