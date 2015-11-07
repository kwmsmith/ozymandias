import pytest

import collections
from set import set as pset, APersistentSet, PersistentHashSet

def test_set_register():
    assert issubclass(APersistentSet, collections.Set)
    assert issubclass(PersistentHashSet, collections.Set)
    assert not issubclass(APersistentSet, collections.MutableSet)
    assert not issubclass(PersistentHashSet, collections.MutableSet)

def test_empty():
    s = pset()
    assert len(s) == 0
    assert s == pset()

def test_creation():
    s0 = pset(range(100))
    s1 = pset(set(range(100)))
    s2 = pset(dict.fromkeys(range(100)))
    assert s0 == s1 == s2

def test_cons():
    s = pset()
    for i in range(100):
        assert len(s) == i
        s = s.cons(i)
        assert i in s

def test_disjoin():
    N = 32**3
    s = pset(str(i) for i in range(N))
    for i in range(N-1, -1, -1):
        si = str(i)
        assert si in s
        s = s.disjoin(si)
        assert si not in s
        assert len(s) == i
    assert s == pset()
