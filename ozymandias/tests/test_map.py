import pytest

import collections
from ozymandias.map import map as phm, APersistentMap, PersistentHashMap

def test_mapping_register():
    assert issubclass(APersistentMap, collections.Mapping)
    assert issubclass(PersistentHashMap, collections.Mapping)

    assert not issubclass(APersistentMap, collections.MutableMapping)
    assert not issubclass(PersistentHashMap, collections.MutableMapping)

def test_creation():
    m = phm()
    assert len(m) == 0

def test_creation_kwargs():
    m = phm(a=1, b=2, c=3)
    assert m['a'] == 1
    assert m['b'] == 2
    assert m['c'] == 3

def test_creation_seq_of_tuples():
    m = phm([('a', 1), ('b', 2), ('c', 3)])
    assert m['a'] == 1
    assert m['b'] == 2
    assert m['c'] == 3

def test_creation_dict():
    m = phm({'a': 1, 'b': 2, 'c': 3})
    assert m['a'] == 1
    assert m['b'] == 2
    assert m['c'] == 3

def test_creation_mixed():
    m = phm([('a', 1)], b=2, c=3)
    assert m['a'] == 1
    assert m['b'] == 2
    assert m['c'] == 3

def test_creation_raises():
    with pytest.raises(TypeError):
        phm([('a', 1)], {'b': 2})
    with pytest.raises(TypeError):
        phm({'b': 2}, [('a', 1)])

def test_assoc():
    m = phm()
    m2 = m.assoc(None, None)
    assert len(m2) == 1
    for i in range(32**3):
        m = m.assoc(i, i)
        assert len(m) == i+1
        assert m[i] == i

def test_dissoc():
    N = 32**3
    m = phm((i, 0) for i in range(N))
    assert len(m) == N
    for i in range(N):
        m = m.dissoc(i)
        assert i not in m
    assert m == phm()
    assert phm().dissoc(10) == phm()

def test_getitem():
    m = phm()
    m2 = m.assoc(1, 42)
    assert m2[1] == 42

def test_key_error():
    m = phm()
    # Test path when root is None.
    with pytest.raises(KeyError):
        m[1]
    m = m.assoc(10, 20)
    # Test path when root is not None.
    with pytest.raises(KeyError):
        m[1]

def test_replace():
    m = phm()
    m = m.assoc(1, 2)
    assert m[1] == 2
    m2 = m.assoc(1, 10)
    assert m2[1] == 10
    assert m[1] == 2

class Pathological(object):
    '''Class with different objects that share the same hash.'''

    def __init__(self, a):
        self.a = a

    def __eq__(self, other):
        return self.a == other.a

    def __hash__(self):
        return 42


def test_pathological():
    m = phm()
    for i in range(100):
        m = m.assoc(Pathological(i), i)
    assert len(m) == 100
    for i in range(100):
        assert m[Pathological(i)] == i

def test_iteration():
    d = {i: i**2 for i in range(1000)}
    m = phm(d)
    assert set(m) == set(d)
    assert set(m.keys()) == set(d.keys())
    assert set(m.values()) == set(d.values())
    assert set(m.items()) == set(d.items())

def test_equals():
    assert phm() == phm()
    assert phm(a=1, b=2) == phm(b=2, a=1)
    assert phm(a=1, b=1) != phm(a=2, b=2)

def test_str():
    m = phm({i: i**2 for i in range(1000)})
    assert eval(str(m).replace('map', 'phm')) == m

def test_get():
    m = phm((i, i**2) for i in range(10))
    assert m.get(0) == 0
    assert m.get(8) == 8**2
    assert m.get('a') == None
    assert m.get('b', 'notfound') == 'notfound'

def test_hash():
    m = phm()
    assert isinstance(hash(m), int)
    a = phm((i, None) for i in range(100))
    b = phm((i, None) for i in range(99, -1, -1))
    assert a == b and hash(a) == hash(b)
    c = phm(((i,), phm(a=i, b=2*i)) for i in range(100))
    assert isinstance(hash(c), int)
    with pytest.raises(TypeError):
        hash(phm(a=[1,2,3]))

def test_transient():
    N = 32**3
    tm = phm().transient()
    for i in range(N):
        assert len(tm) == i
        tm = tm.tassoc(i, i)
        assert i in tm
        assert tm[i] == i
    for i in range(N):
        tm = tm.tdissoc(i)
        assert len(tm) == (N-i-1)
    pm = tm.persistent()
    assert len(pm) == 0
    assert isinstance(pm, PersistentHashMap)
    assert pm == phm()

class cs(object):

    def __init__(self, s):
        self.s = str(s)

    def __hash__(self):
        return hash(self.s) % 100

    def __eq__(self, other):
        return self.s == other.s

def test_transient_collisions():
    N = 32**3
    tm = phm((cs(i), None) for i in range(N)).transient()
    for i in range(N):
        si = cs(i)
        assert si in tm
        tm = tm.tdissoc(cs(i))
        assert si not in tm
    assert tm.persistent() == phm()

def test_transient_persistent():
    pm = phm({1:2})
    tm = pm.transient()
    assert len(pm) == len(tm) == 1
    assert pm[1] == tm[1] == 2
    pm2 = tm.persistent()
    assert pm2 == pm
    with pytest.raises(RuntimeError):
        len(tm)
    with pytest.raises(RuntimeError):
        tm[1]
