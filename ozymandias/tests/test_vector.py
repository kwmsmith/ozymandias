from __future__ import print_function
import sys
import pytest

from six.moves import range, xrange

import collections

import ozymandias.vector as vector
from ozymandias.vector import vec, TransientVector
from random import shuffle

def test_sequence_register():
    assert issubclass(vector.APersistentVector, collections.Sequence)
    assert issubclass(vector.PersistentVector, collections.Sequence)
    assert issubclass(vector.SubVector, collections.Sequence)

    assert not issubclass(vector.APersistentVector, collections.MutableSequence)
    assert not issubclass(vector.PersistentVector, collections.MutableSequence)
    assert not issubclass(vector.SubVector, collections.MutableSequence)

def test_creation_empty():
    v = vec()
    assert len(v) == 0
    w = vec([])
    assert len(w) == 0


def test_creation_non_empty():
    v = vec([1, 2, 3])
    assert len(v) == 3


def test_creation_large():
    N = 32**3 + 1
    v_range = vec(range(N))
    v_tuple = vec(tuple(xrange(N)))
    v_gen = vec(i for i in xrange(N))
    assert v_range == v_gen == v_tuple


def test_cons():
    # Like list.append, except returns new vector w/ structural sharing.
    v0 = vec()
    assert len(v0) == 0
    v1 = v0.cons(1)
    assert len(v0) == 0
    assert len(v1) == 1
    assert v1[0] == 1


def test_cons_128():
    N = 128
    v = vec()
    for i in xrange(N):
        v = v.cons(i)
    assert len(v) == N
    for i in xrange(N):
        assert v[i] == i

def test_cons_large():
    N = 32**3 + 1
    v = vec()
    for i in xrange(N):
        v = v.cons(i)
    assert len(v) == N
    for i in xrange(N):
        assert v[i] == i

def test_conj_large():
    N = 1048576 + 32
    tv = vec().transient()
    for i in xrange(N):
        tv = tv.conj(i)
    v = tv.persistent()
    assert len(v) == N
    for i in xrange(N):
        assert v[i] == i


def test_indexing_pos():
    v = vec([1, 2, 3])
    assert v[0] == 1
    assert v[1] == 2
    assert v[2] == 3
    

def test_assoc():
    # TODO: FIXME: test with a big vector, bigger than 32, 32**2, 32**3, etc...
    N = 32**3
    a = vec(range(N))
    b = a.assoc(0, 10)
    assert a[0] == 0
    assert b[0] == 10
    assert a[1] == b[1]
    assert a[2] == b[2]
    c = b.assoc(1, 5)
    assert c[1] == 5


def test_iteration_empty():
    a = vec()
    for i in a:
        assert False


def test_iteration():
    N = 32**3
    a = vec(range(N))
    b = 0
    for i in a:
        b += i
    assert b == N * (N - 1) / 2


def test_containment():
    N = 32**2
    a = vec(range(N))
    for i in xrange(N):
        assert i in a
    assert N not in a


def test_count():
    ll = [1, 2, 2, 3, 3, 3]
    shuffle(ll)
    a = vec(ll)
    assert a.count(1) == ll.count(1)
    assert a.count(2) == ll.count(2)
    assert a.count(3) == ll.count(3)
    assert a.count('a') == ll.count('a')


def test_index():
    ll = list(range(32**2))
    shuffle(ll)
    v = vec(ll)
    for i in ll:
        assert ll.index(i) == v.index(i)
    with pytest.raises(ValueError):
        v.index(len(ll))


def test_slice():
    ll = list(range(100))
    l2 = ll[5:10]
    v = vec(ll)
    v2 = v[5:10]
    assert len(l2) == len(v2)
    for a, b in zip(l2, v2):
        assert a == b
    with pytest.raises(NotImplementedError):
        v[::2]


def test_str_repr():
    ll = list(range(100))
    shuffle(ll)
    v = vec(ll)
    assert "vec(%s)" % str(ll) == str(v)
    assert str(v) == repr(v)
    assert str(v[:]) == str(v)
    assert str(vec()) == "vec()"


def test_boolean():
    assert bool(vec()) == False
    assert bool(vec([])) == False
    assert bool(vec([0])) == True


def test_equality():
    assert vec() == vec()
    assert vec(range(100)) == vec(range(100))
    assert vec(range(100)) != range(100)
    assert vec([1, 2, 4]) != vec([1, 2, 3])


def test_hash():
    assert isinstance(hash(vec()), int)
    assert hash(vec()) == hash(())
    # TODO: FIXME: why don't these hash equally?  We implemented vec's __hash__
    # to be the same as tuple's __hash__...
    # assert hash(vec(range(10))) == hash(tuple(range(10)))

    assert hash(vec([()])) # vec of hashable type.

    v = vec([[1]]) # vec of unhashable type.
    with pytest.raises(TypeError):
        hash(v)

def test_hash2():
    v0 = vec()
    assert isinstance(hash(v0), int)
    v1 = vec()
    assert hash(v0) == hash(v1)
    vals = list(range(10))
    shuffle(vals)
    v0 = vec(vals)
    v1 = vec(vals)
    assert hash(v0) == hash(v1)

def test_listify_and_tupleify():
    N = 100
    assert list(vec(range(N))) == list(range(N))
    assert list(vec()) == []
    assert tuple(vec(range(N))) == tuple(range(N))
    assert tuple(vec()) == ()

def test_creation_from_generator():
    N = 100
    v = vec(i for i in xrange(N))
    assert len(v) == N

def test_transient():
    v = vec(range(100))
    trans = TransientVector.from_persistent(v)
    assert len(trans) == len(v)
    v2 = trans.persistent()
    assert v == v2
    with pytest.raises(RuntimeError):
        len(trans)

def test_transient_conj():
    N = 32**3
    t = vec().transient()
    for i in xrange(N):
        assert len(t) == i
        t = t.conj(i)
    p = t.persistent()
    assert len(p) == N

def test_transient_assoc():
    N = 32**3
    t = vec(range(N)).transient()
    for i in xrange(0, N, N//100):
        t = t.assoc(i, None)
        assert t[i] == None

def test_transient_persistent_etc():
    pv = vec()
    tv = pv.transient()
    pv2 = tv.persistent()
    with pytest.raises(RuntimeError):
        len(tv)
    tv2 = pv2.transient()

"""

def test_big_vector():
    # TODO: test a vector that pushes the limits of len(), etc.
    # See if we can get it to break when using a list over the maxint size.
    pass


def test_indexing_neg():
    v = vec([1, 2, 3])
    assert v[-3] == 1
    assert v[-2] == 2
    assert v[-1] == 3



def test_pop():
    # TODO XXX: "pop" in clojure returns a new vec with the last element
    # removed.  Consider renaming to not collide with Python's list.pop.
    v0 = vec([1, 2])
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


def test_slice():
    vv = vec([1, 2, 3, 4])

    s0 = vv[:]
    assert s0 == vec
    
    s1 = vv[2:]
    assert s1 == [3, 4]

    s2 = vv[::2]
    assert s2 == [1, 3]

    s3 = vv[1::2]
    assert s3 == [2, 4]

   # TODO: test negative indices...


def test_reduction():
    assert reduce(lambda seq, val: seq.conj(val+1),
                  range(10), 0) == range(1, 11)
"""
