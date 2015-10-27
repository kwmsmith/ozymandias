import pytest

from map import map as phm

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
    for i in range(100):
        m = m.assoc(i, i)
    assert len(m) == 100

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
