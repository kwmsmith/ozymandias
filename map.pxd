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
    cdef Node assoc(self, uint32_t shift, uint32_t hash, key, val, bint *added_leaf)
    cdef Node tassoc(self, bint editable, uint32_t shift, uint32_t hash, key, val, bint *added_leaf)
    cdef Node without(self, uint32_t shift, uint32_t hash, key)
    cdef Node twithout(self, bint edit, uint32_t shift, uint32_t hash, key, bint *removed_leaf)
    cdef find(self, uint32_t shift, uint32_t hash, key, not_found)
    cdef NodeIter _iter(self, key_val_item_t kvi)
    cdef Node edit_and_remove_pair(self, bint edit, uint32_t bit, int i)
    cdef Node ensure_editable(self, bint editable)

cdef class APersistentMap:
    cdef uint32_t _hash
    cdef bint _equals(self, APersistentMap obj)

    cpdef get(self, k, d=?)

cdef PersistentHashMap EMPTY

cdef class TransientHashMap:
    cdef:
        bint _editable
        Node _root
        Py_ssize_t _cnt
    cdef ensure_editable(self)
    cpdef TransientHashMap tassoc(self, key, val)
    cpdef TransientHashMap tdissoc(self, key)
    cpdef PersistentHashMap persistent(self)
    cpdef get(self, k, d=?)

cdef class PersistentHashMap(APersistentMap):
    cdef:
        Py_ssize_t _cnt
        Node _root

    cpdef keys(self)
    cpdef values(self)
    cpdef items(self)
    cpdef PersistentHashMap assoc(self, key, value)
    cpdef PersistentHashMap dissoc(self, key)
    cpdef TransientHashMap transient(self)
