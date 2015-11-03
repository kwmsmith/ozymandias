from libc.stdint cimport uint32_t

ctypedef enum key_val_item_t:
    _KEY_,
    _VAL_,
    _ITEM_

cdef class NodeIter:
    cdef:
        key_val_item_t _key_val_item
        Py_ssize_t _i
        list _array
        object _next_entry
        NodeIter _next_iter

    cdef bint _advance(self)
    cdef bint has_next(self)

cdef class Node:
    cdef Node assoc(self, uint32_t shift, long hash, key, val, bint *added_leaf)
    cdef Node without(self, uint32_t shift, long hash, key)
    cdef find(self, uint32_t shift, long hash, key, not_found)
    cdef NodeIter _iter(self, key_val_item_t kvi)

cdef class APersistentMap:
    cdef long _hash
    cdef bint _equals(self, APersistentMap obj)

cdef PersistentHashMap EMPTY

cdef class PersistentHashMap(APersistentMap):
    cdef:
        Py_ssize_t _cnt
        Node _root
