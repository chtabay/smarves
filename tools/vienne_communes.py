#!/usr/bin/env python3
"""Construit communes/vienne.json : les communes actuelles de la Vienne, à leur vraie place.

C'est tools/departement_communes.py pour le seul département 86 : voir là pour les sources.

Usage : python3 tools/vienne_communes.py   (demande shapely : python3 -m pip install shapely)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from departement_communes import main  # noqa: E402

if __name__ == "__main__":
    sys.argv = [sys.argv[0], "86"]
    main()
