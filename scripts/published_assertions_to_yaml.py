#!/usr/bin/env python3
"""Build a schema-shaped YAML dump from published indicator assertions.

This is the inverse of _scripts/indicator2iadopt.py: an entry copied from
published-yaml/ and re-submitted through dropbox/ projects to the same I-ADOPT
Variable assertion. The projection keeps only part of a dropbox entry, so:

- `short_name`, `aliases` and a `ui_label` that differs from `name` all become
  skos:altLabel; they come back as `aliases`;
- fields the projection doesn't publish (for example `exact_matches`,
  `context_aliases`, `parent_indicators`, `indicator_type`, `property`) can't be
  exported.

Blank nodes appear in published nanopubs as `<nanopub URI>/_…` URIs; a
constraint with such a URI is exported without a `constraint_id`, as it was
submitted.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

import yaml
from rdflib import Graph, Literal, Namespace, RDF, RDFS, URIRef
from rdflib.namespace import SKOS

IADOPT = Namespace("https://w3id.org/iadopt/ont/")
SKOLEM = re.compile(r"^https://w3id\.org/np/RA[A-Za-z0-9_-]{43}[/#]_")

SINGLE_SLOTS = {
    SKOS.definition: "description",
    RDFS.comment: "remark",
    IADOPT.hasProperty: "quantity_kind",
    IADOPT.hasMatrix: "matrix",
    IADOPT.hasObjectOfInterest: "biochementity",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assertion-folder", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def warn(subject: Any, message: str) -> None:
    print(f"WARNING {subject}: {message}", file=sys.stderr)


def single(graph: Graph, subject: Any, predicate: URIRef, slot: str) -> str | None:
    values = sorted(str(v) for v in graph.objects(subject, predicate) if not getattr(v, "language", None))
    if len(values) > 1:
        warn(subject, f"{slot} has more than one value; exported only {values[0]!r}")
    return values[0] if values else None


def constraint(graph: Graph, node: Any) -> dict[str, str]:
    item: dict[str, str] = {}
    if isinstance(node, URIRef) and not SKOLEM.match(str(node)):
        item["constraint_id"] = str(node)
    for key, predicate in (("name", RDFS.label), ("description", RDFS.comment), ("constrains", IADOPT.constrains)):
        if (value := single(graph, node, predicate, f"constraint {key}")) is not None:
            item[key] = value
    return item


def record_for(graph: Graph, subject: Any) -> dict[str, Any]:
    record: dict[str, Any] = {"id": str(subject)}
    if (name := single(graph, subject, SKOS.prefLabel, "name")) is not None:
        record["name"] = name
    translations = sorted(
        (
            {"property_name": "name", "language": v.language, "translated_value": str(v)}
            for v in graph.objects(subject, SKOS.prefLabel)
            if isinstance(v, Literal) and v.language
        ),
        key=lambda t: (t["language"], t["translated_value"]),
    )
    if translations:
        record["translations"] = translations
    for predicate, slot in SINGLE_SLOTS.items():
        if (value := single(graph, subject, predicate, slot)) is not None:
            record[slot] = value
    for predicate in (SKOS.definition, RDFS.comment, SKOS.altLabel):
        for value in graph.objects(subject, predicate):
            if isinstance(value, Literal) and value.language:
                warn(subject, f"{value!r}: exported without its language tag")
    if aliases := sorted({str(v) for v in graph.objects(subject, SKOS.altLabel)}):
        record["aliases"] = aliases
    constraints = [constraint(graph, node) for node in graph.objects(subject, IADOPT.hasConstraint)]
    if constraints:
        record["constraints"] = sorted(constraints, key=lambda c: (c.get("name", ""), c.get("constrains", "")))
    return record


def main() -> None:
    args = parse_args()
    graph = Graph()
    for ttl_file in sorted(args.assertion_folder.glob("*.ttl")):
        graph.parse(ttl_file, format="turtle")

    records = [record_for(graph, s) for s in sorted(set(graph.subjects(RDF.type, IADOPT.Variable)), key=str)]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as stream:
        yaml.safe_dump({"indicator_subclasses": records}, stream, allow_unicode=True, sort_keys=False)
    print(f"Wrote {len(records)} indicator(s) to {args.output}")


if __name__ == "__main__":
    main()
