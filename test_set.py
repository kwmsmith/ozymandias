import pytest

import collections
from set import set as pset, APersistentSet, PersistentHashSet

N = 4 * 32**3

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
    s0 = pset(range(N))
    s1 = pset(set(range(N)))
    s2 = pset(dict.fromkeys(range(N)))
    assert s0 == s1 == s2

def test_cons():
    s = pset()
    for i in range(N):
        assert len(s) == i
        si = str(i)
        s = s.cons(si)
        assert si in s

def test_disjoin():
    s = pset(str(i) for i in range(N))
    assert len(s) == N
    for i in range(N-1, -1, -1):
        si = str(i)
        assert si in s
        s = s.disjoin(si)
        assert si not in s
        assert len(s) == i
    assert s == pset()
