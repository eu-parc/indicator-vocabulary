from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

from rdflib import BNode, Graph, URIRef
from rdflib.compare import isomorphic

ROOT = Path(__file__).resolve().parents[1]


def _load(name: str, path: Path):
    spec = spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


projection = _load("indicator2iadopt", ROOT / "_scripts" / "indicator2iadopt.py")
export = _load("published_assertions_to_yaml", ROOT / "scripts" / "published_assertions_to_yaml.py")

ENTRY = {
    "id": "https://w3id.org/peh/indicators/RAexample",
    "name": "Lead in urine",
    "ui_label": "Urinary lead",
    "short_name": "Pb-U",
    "aliases": ["lead (urine)"],
    "description": "Concentration of lead in a urine sample.",
    "remark": "A remark.",
    "quantity_kind": "http://qudt.org/vocab/quantitykind/MassConcentration",
    "matrix": "https://w3id.org/peh/matrices/RAurine",
    "biochementity": "https://w3id.org/peh/biochementities/RAlead",
    "translations": [{"property_name": "name", "language": "nl-be", "translated_value": "Lood in urine"}],
    "constraints": [
        {"constraint_id": "https://example.org/constraint/morning", "name": "morning sample",
         "constrains": "https://w3id.org/peh/matrices/RAurine"},
        {"name": "at baseline", "description": "First visit.", "constrains": "https://w3id.org/peh/terms/Study"},
    ],
}


def test_exported_entry_projects_to_the_same_assertion() -> None:
    published = projection.build_graph(ENTRY)

    record = export.record_for(published, URIRef(ENTRY["id"]))

    assert record["aliases"] == ["Pb-U", "Urinary lead", "lead (urine)"]
    assert isomorphic(projection.build_graph(record), published)


def test_skolemized_constraint_comes_back_without_an_id() -> None:
    # Published nanopubs carry blank nodes as <nanopub URI>/_… URIs.
    skolem = URIRef("https://w3id.org/np/RA" + "a" * 43 + "/_b1")
    trig_assertion = Graph()
    for triple in projection.build_graph(ENTRY):
        trig_assertion.add(tuple(skolem if isinstance(t, BNode) else t for t in triple))

    record = export.record_for(trig_assertion, URIRef(ENTRY["id"]))

    ids = [c.get("constraint_id") for c in record["constraints"]]
    assert ids == [None, "https://example.org/constraint/morning"]
