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

def test_conj():
    s = pset()
    for i in range(N):
        assert len(s) == i
        si = str(i)
        s = s.conj(si)
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

def test_transient():
    ps = pset()
    ts = ps.transient()
    ps2 = ts.persistent()
    assert ps == ps2

def test_tconj_tdisjoin():
    ps = pset()
    ts = ps.transient()
    for i in range(N//2):
        assert len(ts) == i
        si = str(i)
        assert si not in ts
        assert si not in ps
        ts = ts.tconj(si)
        ps = ps.conj(si)
        assert si in ts
        assert si in ps
    for i in range(N//2):
        si = str(i)
        ts = ts.tdisjoin(si)
        ps = ps.disjoin(si)
        assert si not in ts
        assert si not in ps
        assert len(ts) == len(ps) == (N//2 - i - 1)
    assert ps == ts.persistent()

def test_hash():
    s = pset()
    for i in range(100):
        assert isinstance(hash(s), int)
        s = s.conj(i)
