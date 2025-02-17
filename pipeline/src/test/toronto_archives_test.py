import sys

from nose.tools import eq_

sys.path.append("pipeline/src")
from toronto_archives import get_citation_hierarchy  # noqa: E402


def test_get_citation_hierarchy():
    eq_(
        ["Fonds 200, Series 123", "Fonds 200"],
        get_citation_hierarchy("Fonds 200, Series 123, Item 456"),
    )

    eq_(
        ["Fonds 257, Series 12, File 1983", "Fonds 257, Series 12", "Fonds 257"],
        get_citation_hierarchy('Fonds 257, Series 12, File 1983,  52","'),
    )
