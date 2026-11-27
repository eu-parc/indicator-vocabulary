## Indicator Vocabulary Dropbox to Nanopublication Workflow

This repository implements a staged workflow for publishing PEH indicators as
I-ADOPT Variable nanopublications.

## Proposing a New Indicator

Add one or more `*.yaml` files to `dropbox/`. A minimal file looks like this:

```yaml
suggester: https://orcid.org/0000-0002-1825-0097

indicator_subclasses:
  - name: "Bloodgroup"
    ui_label: "Bloodgroup"
    indicator_type: observation
    short_name: bloodtype
    property: observation
    parent_indicators:
      - https://w3id.org/peh/terms/Indicator
    constraints:
      - constraint_id: https://example.org/constraint/human-subjects # constraint identifier is optional and should only be provided if you have minted an identifier. Otherwise a blank node will be used.
        name: "in human subjects"
        constrains: https://w3id.org/peh/terms/Person
      - name: "at baseline"
        constrains: https://w3id.org/peh/terms/Study
```

Identifiers are minted on the fly, so `id` is optional for new indicators. The
published assertion is the I-ADOPT variable view of the indicator.

The optional `suggester` field records who proposed the term. Set it once at the
top of the file as a default, or per entry to override.

## `indicator` Fields

Each item under `indicator_subclasses` describes one indicator proposal. Only
`name` is required in a new dropbox proposal. During the pipeline, the indicator
is assigned an `id`; that minted `id` is then required by the I-ADOPT projection
because it becomes the URI of the `iadopt:Variable`.

Use strings for human-readable text. Use IDs for references to existing or
minted resources; these should be full URIs or CURIEs where the consuming schema
allows CURIEs.

| Field | Required? | Expected value | What to put here |
| --- | --- | --- | --- |
| `id` | No for proposals; yes after minting | ID string | Indicator URI. Omit for a new proposal unless an identifier already exists. |
| `name` | Yes | String | Preferred human-readable label for the indicator. Serialized as `skos:prefLabel` in the I-ADOPT variable. |
| `short_name` | No | String | Short label or abbreviation. Serialized as an alternative label. |
| `ui_label` | No | String | Label optimized for forms or user interfaces. Serialized as an alternative label when it differs from `name`. |
| `description` | No | String | Definition or longer explanation. Serialized as `skos:definition`. |
| `remark` | No | String | Additional comment or usage note. Serialized as `rdfs:comment`. |
| `exact_matches` | No | List of ID strings | Equivalent external concepts, such as ontology term URIs. |
| `aliases` | No | List of strings | Unqualified alternative labels or synonyms. Serialized as alternative labels. |
| `context_aliases` | No | List of objects | Context-specific aliases. See `context_aliases` below. |
| `translations` | No | List of objects | Translations of labels or other text fields. Name translations are serialized as language-tagged preferred labels. See `translations` below. |
| `quantity_kind` | No | ID string | QUDT quantity kind or another property identifier. When present, this becomes `iadopt:hasProperty` and is typed as `iadopt:Property`. |
| `matrix` | No | ID string | Matrix or environmental/biological medium identifier. When present, this becomes `iadopt:hasMatrix` and is typed as `iadopt:Entity`. |
| `constraints` | No | List of objects | I-ADOPT constraints that qualify the variable. See `constraints` below. |
| `biochementity` | No | ID string | Object of interest identifier. When present, this becomes `iadopt:hasObjectOfInterest` and is typed as `iadopt:Entity`. |
| `parent_indicators` | No | List of ID strings | Broader indicator classes, commonly including `https://w3id.org/peh/terms/Indicator`. |
| `suggester` | No | ORCID URL string | Per-indicator ORCID of the proposer. Overrides the file-level `suggester`. |

### `constraints`

Each `constraints` entry describes one `iadopt:Constraint`. The constraint
object requires both a label and the entity it constrains. A constraint is used to add nuance to the indicator. For example, we meansure the concentration of lead in urine, and we add the constraint saying 'urine sample obtained in the morning'.

| Field | Required? | Expected value | What to put here |
| --- | --- | --- | --- |
| `constraint_id` | No | ID string | URI or CURIE for a reusable constraint. Omit for the usual blank-node constraint. |
| `name` | Yes | String | Human-readable constraint label, serialized as `rdfs:label`. |
| `description` | No | String | Longer explanation, serialized as `rdfs:comment`. |
| `constrains` | Yes | ID string | URI or CURIE of the entity being constrained, such as a study subject, matrix, or context. |

### Nested Helper Objects

| Object | Field | Required? | Expected value | What to put here |
| --- | --- | --- | --- | --- |
| `translations` | `property_name` | Yes | String | Field being translated, for example `name`. |
| `translations` | `language` | Yes | String | Language tag, for example `nl-be`. |
| `translations` | `translated_value` | Yes | String | Translated text. |
| `context_aliases` | `property_name` | Yes | String | Field the alias applies to, for example `name`. |
| `context_aliases` | `context` | No | String or ID | Scope where the alias is used, such as a project, community, or study. |
| `context_aliases` | `alias` | Yes | String | Alias used in that context. |

The full dropbox contract is in [schema/dropbox-indicator.schema.json](schema/dropbox-indicator.schema.json), with a worked example in [schema/dropbox-indicator.example.yaml](schema/dropbox-indicator.example.yaml).

## Folder Semantics

- `dropbox/`: incoming YAML vocabulary files
- `archive/`: processed combined YAML files with minted identifiers
- `unpublished/`: generated I-ADOPT Variable RDF assertions waiting for publish
- `published/`: assertions already published as nanopublications
- `redirect/`: term identifier to nanopub identifier mappings
- `build/`: transient build artifacts

The legacy `data/data.yaml` has been moved to `archive/data.yaml`.

## Local Usage

Install dependencies:

```bash
uv sync
```

Download a tagged `peh.yaml` snapshot into `schema/`:

```bash
make fetch-peh-schema
```

Process incoming YAML from `dropbox/`:

```bash
make pipeline
```

Validate a PR-style proposal without archiving:

```bash
make validate-pr
```

Dry-run nanopub minting:

```bash
make publish-defining DRY=--dry-run
```

Generate the vocabulary browser input from published nanopubs:

```bash
make assertions
```

## GitHub Workflows

- `consistency-check.yaml` (weekly, and on demand): checks the vocabulary as
  Nanodash shows it and as `published/` holds it. It fails on duplicate labels
  and on links to terms that are not current (withdrawn or not approved), and
  warns when `published/` is out of date, on links to deprecated terms and on
  terms that share an InChIKey or CAS number. Run it locally with
  `make check-consistency`.
