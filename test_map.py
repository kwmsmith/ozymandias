import pytest

from map import map as phm

def test_creation():
    m = phm()
    assert len(m) == 0

def test_assoc():
    m = phm()
    m2 = m.assoc(None, None)
    assert len(m2) == 1
    for i in range(100):
        m = m.assoc(i, i)
    assert len(m) == 100

def test_getitem():
    m = phm()
    m2 = m.assoc(1, 42)
    assert m2[1] == 42
