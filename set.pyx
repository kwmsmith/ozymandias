cimport map

from collections import Set

def set(*args):
    if len(args) > 1:
        raise TypeError("set expected at most 1 argument, got %d" % len(args))
    ret = EMPTY.transient()
    if args:
        for obj in args[0]:
            ret = ret.tconj(obj)
    return ret.persistent()

DEF NULL_HASH = -1
DEF UNHASHED = -2
DEF SAFEHASH = -3

cdef class APersistentSet:
    cdef:
        long _hash
        map.APersistentMap _impl

    def __cinit__(self, map.APersistentMap impl):
        self._hash = UNHASHED
        self._impl = impl

    def __repr__(self):
        return "set({" + ", ".join(repr(o) for o in self) + "})"

    __str__ = __repr__

    def __hash__(self):
        cdef long y
        cdef long x = 0x345678L
        cdef Py_ssize_t ll = len(self)
        cdef long mult = 1000003L
        if self._hash != UNHASHED and self._hash != NULL_HASH:
            return self._hash
        if self._hash == NULL_HASH:
            raise TypeError("map contains unhashable type.")
        elif self._hash == UNHASHED:
            for obj in self:
                try:
                    y = hash(obj)
                except TypeError:
                    self._hash = NULL_HASH
                    raise
                x = (x ^ y) * mult
                mult += <long>(82520L + ll + ll)
            x += 97531L
            if x == NULL_HASH or x == UNHASHED:
                x = SAFEHASH
            self._hash = x
        return self._hash

    def __contains__(self, obj):
        return obj in self._impl
    
    def __len__(self):
        return len(self._impl)

    def __richcmp__(x, y, int op):
        assert (isinstance(x, APersistentSet) 
                or isinstance(y, APersistentSet))
        if op == 2: # ==
            if (not isinstance(x, APersistentSet) or 
                not isinstance(y, APersistentSet)):
                # Both have to be the same type to be equal.
                return False
            else:
                return (<APersistentSet>x)._equals(<APersistentSet>y)
        elif op == 3: # !=
            return not x == y
        else:
            raise NotImplementedError()

    cdef bint _equals(self, APersistentSet obj):
        if self is obj:
            return True
        if len(self) != len(obj):
            return False
        for k in self:
            if k not in obj:
                return False
        return True
    
    def __iter__(self):
        return iter(self._impl)

Set.register(APersistentSet)

cdef PersistentHashSet EMPTY = PersistentHashSet(map.EMPTY)

cdef class PersistentHashSet(APersistentSet):
    cpdef PersistentHashSet cons(self, obj):
        if obj in self:
            return self
        return PersistentHashSet(self._impl.assoc(obj, obj))
    
    cpdef PersistentHashSet disjoin(self, obj):
        if obj in self:
            return PersistentHashSet(self._impl.dissoc(obj))
        return self
    
    cpdef TransientHashSet transient(self):
        return TransientHashSet(self._impl.transient())


cdef class TransientHashSet:
    cdef map.TransientHashMap _impl
    
    def __cinit__(self, map.TransientHashMap impl):
        self._impl = impl

    def __len__(self):
        return len(self._impl)

    cpdef TransientHashSet tconj(self, val):
        cdef map.TransientHashMap m = self._impl.tassoc(val, val)
        if not m is self._impl:
            self._impl = m
        return self

    # cpdef TransientHashSet disjoin(self, val):
        # cdef map.TransientHashMap m = self._impl.tdissoc(val, val)
        # if not m is self._impl:
            # self._impl = m
        # return self

    def __contains__(self, obj):
        return obj in self._impl
    
    cpdef persistent(self):
        return PersistentHashSet(self._impl.persistent())
