from vector import Vector
from random import shuffle

def test_creation_empty():
    v = Vector()
    assert len(v) == 0
    w = Vector([])
    assert len(w) == 0


def test_creation_non_empty():
    v = Vector([1, 2, 3])
    assert len(v) == 3


"""
def test_indexing_pos():
    v = Vector([1, 2, 3])
    assert v[0] == 1
    assert v[1] == 2
    assert v[2] == 3


def test_indexing_neg():
    v = Vector([1, 2, 3])
    assert v[-3] == 1
    assert v[-2] == 2
    assert v[-1] == 3


def test_equality_with_list_and_tuple():
    l = range(10, 20)
    t = tuple(l)
    v = Vector(l)
    assert l == v
    assert t == v


def test_conj():
    # Like list.append, except returns new vector w/ structural sharing.
    v0 = Vector()
    assert len(v0) == 0
    v1 = v0.conj(1)
    assert len(v0) == 0
    assert len(v1) == 1
    assert v1[0] == 1


def test_assoc():
    v0 = Vector([1, 2, 3])
    v1 = v0.assoc(0, 10)
    assert v0 == [1, 2, 3]
    assert v1 == [10, 2, 3]

    v2 = v1.assoc(1, 5)
    assert v2 == [10, 5, 3]


def test_pop():
    # TODO XXX: "pop" in clojure returns a new vec with the last element
    # removed.  Consider renaming to not collide with Python's list.pop.
    v0 = Vector([1, 2])
    v1 = v0.pop()
    assert v0 == [1, 2]
    assert v1 == [1]
    v2 = v1.pop()
    assert v2 == []
    v3 = v2.pop()
    assert v3 == v2 == []


def test_replace():
    # TODO XXX: think about this one...
    pass


def test_hash():
    v0 = Vector()
    assert isinstance(hash(v0), int)
    v1 = Vector()
    assert hash(v0) == hash(v1)
    vals = range(10)
    shuffle(vals)
    v0 = Vector(vals)
    v1 = Vector(vals)
    assert hash(v0) == hash(v1)


def test_iteration():
    l = [10, 11, 12]
    vec = Vector(l)
    nl = []
    for v in vec:
        nl.append(v)
    assert vec == nl == l


def test_slice():
    vec = Vector([1, 2, 3, 4])

    s0 = vec[:]
    assert s0 == vec
    
    s1 = vec[2:]
    assert s1 == [3, 4]

    s2 = vec[::2]
    assert s2 == [1, 3]

    s3 = vec[1::2]
    assert s3 == [2, 4]

   # TODO: test negative indices...


def test_coercion_to_list_tuple():
    vec = Vector(range(10))
    ll = list(vec)
    assert isinstance(ll, list)
    assert ll == range(10)
    tt = tuple(vec)
    assert isinstance(tt, tuple)
    assert tt == tuple(range(10))

def test_reduction():
    assert reduce(lambda seq, val: seq.conj(val+1),
                  range(10), 0) == range(1, 11)
"""
