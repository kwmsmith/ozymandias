from __future__ import print_function

from collections import Mapping, Iterable

DEF SHIFT = 5U
DEF NN = (1U << SHIFT)

DEF NULL_HASH = -1
DEF UNHASHED = -2
DEF SAFEHASH = -3

# TODO: FIXME: http://docs.cython.org/src/userguide/extension_types.html#fast-instantiation
# Apply these ideas to Node() instantiation...

def map_hash(long h):
    return int(<uint32_t>h)

cdef extern from *:
    uint32_t popcount "__builtin_popcount"(uint32_t)

DEF NULL_HASH = -1
DEF UNHASHED = -2
DEF SAFEHASH = -3

cdef class APersistentMap:

    def __cinit__(self):
        self._hash = UNHASHED

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
            for k,v in self.items():
                try:
                    y = hash(k) ^ hash(v)
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

    def __repr__(self):
        d = dict(self.items())
        return "map(%s)" % d

    __str__ = __repr__

    def __contains__(self, k):
        try:
            self[k]
        except KeyError:
            return False
        else:
            return True

    cpdef get(self, k, d=None):
        try:
            return self[k]
        except KeyError:
            return d

    def __richcmp__(x, y, int op):
        assert (isinstance(x, APersistentMap) or isinstance(y, APersistentMap))
        if op == 2: # ==
            if (not isinstance(x, APersistentMap) or 
                not isinstance(y, APersistentMap)):
                # Both have to be the same type to be equal.
                return False
            else:
                return (<APersistentMap>x)._equals(<APersistentMap>y)
        elif op == 3: # !=
            return not x == y
        else:
            raise NotImplementedError()
    
    cdef bint _equals(self, APersistentMap obj):
        if self is obj:
            return True
        if len(self) != len(obj):
            return False
        for k, v in self.items():
            if k not in obj:
                return False
            if obj[k] != v:
                return False
        return True


Mapping.register(APersistentMap)


def map(*args, **kwargs):
    if len(args) > 1:
        raise TypeError("map expected at most 1 arguments, got %d." % len(args))
    ret = EMPTY.transient()
    if args:
        if isinstance(args[0], Mapping):
            for k, v in args[0].items():
                ret = ret.tassoc(k, v)
        else:
            for k, v in args[0]:
                ret = ret.tassoc(k, v)
    for k,v in kwargs.items():
        ret = ret.tassoc(k, v)
    return ret.persistent()


cdef Node NULL_ENTRY = Node()
cdef object NOT_FOUND = object()

cdef class PersistentHashMap(APersistentMap):

    def __cinit__(self, cnt, root):
        self._cnt = cnt
        self._root = root

    def __len__(self):
        return self._cnt

    def __getitem__(self, key):
        if self._root is NULL_ENTRY:
            raise KeyError("key %r not found." % key)
        val = self._root.find(0U, hash(key), key, NOT_FOUND)
        if val is NOT_FOUND:
            raise KeyError("key %r not found." % key)
        return val


    cpdef PersistentHashMap assoc(self, key, value):
        cdef Node newroot
        cdef bint added_leaf = 0
        if self._root is NULL_ENTRY:
            newroot = EMPTY_NODE
        else:
            newroot = self._root
        newroot = newroot.assoc(0, hash(key), key, value, &added_leaf)
        if newroot == self._root:
            return self
        return PersistentHashMap(self._cnt if added_leaf == 0 else self._cnt + 1,
                                 newroot)

    cpdef PersistentHashMap dissoc(self, key):
        cdef Node newroot
        if self._root is NULL_ENTRY:
            return self
        newroot = self._root.without(0, hash(key), key)
        if newroot is self._root:
            return self
        return PersistentHashMap(self._cnt - 1, newroot)

    def __iter__(self):
        return self.keys()
    
    cpdef keys(self):
        if self._root is NULL_ENTRY:
            return iter([])
        return self._root._iter(_KEY_)
    
    cpdef values(self):
        if self._root is NULL_ENTRY:
            return iter([])
        return self._root._iter(_VAL_)
    
    cpdef items(self):
        if self._root is NULL_ENTRY:
            return iter([])
        return self._root._iter(_ITEM_)
    
    cpdef TransientHashMap transient(self):
        return TransientHashMap.from_persistent(self)


cdef class TransientHashMap:

    def __cinit__(self, bint editable, Node root, Py_ssize_t count):
        self._editable = editable
        self._root = root
        self._cnt = count
    
    @classmethod
    def from_persistent(cls, PersistentHashMap m):
        return cls(True, m._root, m._cnt)

    def __len__(self):
        self.ensure_editable()
        return self._cnt

    def __getitem__(self, key):
        self.ensure_editable()
        if self._root is NULL_ENTRY:
            raise KeyError("key %r not found." % key)
        val = self._root.find(0U, hash(key), key, NOT_FOUND)
        if val is NOT_FOUND:
            raise KeyError("key %r not found." % key)
        return val

    cpdef get(self, k, d=None):
        # TODO: FIXME: make this the base method, and __getitem__ /
        # __contains__ call it instead.  # This is the cpdef (and therefore
        # faster) and defs should call it.
        self.ensure_editable()
        try:
            return self[k]
        except KeyError:
            return d

    def __contains__(self, k):
        try:
            self[k]
        except KeyError:
            return False
        else:
            return True
    
    cdef ensure_editable(self):
        if not self._editable:
            raise RuntimeError("Transient used after made persistent.")

    cpdef TransientHashMap tassoc(self, key, val):
        self.ensure_editable()
        cdef Node r, n
        if self._root is NULL_ENTRY:
            r = EMPTY_NODE
        else:
            r = self._root
        cdef bint added_leaf = False
        n = r.tassoc(self._editable, 0, hash(key), key, val, &added_leaf)
        if n != self._root:
            self._root = n
        if added_leaf:
            self._cnt += 1
        return self

    cpdef TransientHashMap tdissoc(self, key):
        self.ensure_editable()
        if self._root is NULL_ENTRY:
            return self
        cdef bint removed_leaf = False
        cdef Node n = self._root.twithout(self._editable, 0, hash(key), key, &removed_leaf)
        if n is not self._root:
            self._root = n
        if removed_leaf:
            self._cnt -= 1
        return self
    
    cpdef PersistentHashMap persistent(self):
        self._editable = False
        return PersistentHashMap(self._cnt, self._root)


EMPTY = PersistentHashMap(0, NULL_ENTRY)

cdef class Node:

    cdef Node assoc(self, uint32_t shift, uint32_t hash, key, val, bint *added_leaf):
        raise NotImplementedError("Node.assoc() not implemented.")

    cdef Node tassoc(self, bint editable, uint32_t shift, uint32_t hash, key, val, bint *added_leaf):
        raise NotImplementedError("Node.tassoc() not implemented.")

    cdef Node without(self, uint32_t shift, uint32_t hash, key):
        raise NotImplementedError("Node.without() not implemented.")

    cdef Node twithout(self, bint edit, uint32_t shift, uint32_t hash, key, bint *removed_leaf):
        raise NotImplementedError("Node.twithout() not implemented.")

    cdef find(self, uint32_t shift, uint32_t hash, key, not_found):
        raise NotImplementedError("Node.find() not implemented.")
    
    cdef NodeIter _iter(self, key_val_item_t kvi):
        raise NotImplementedError("Node._iter() not implemented.")

    cdef Node edit_and_remove_pair(self, bint edit, uint32_t bit, int i):
        raise NotImplementedError("Node.edit_and_remove_pair() not implemented.")

    cdef Node ensure_editable(self, bint editable):
        raise NotImplementedError("Node.ensure_editable() not implemented.")



cdef inline uint32_t index(uint32_t bitmap, uint32_t bit):
    return popcount(bitmap & (bit - 1))

cdef inline uint32_t mask(uint32_t hash, uint32_t shift):
    return (hash >> shift) & 0x01f

cdef inline uint32_t bitpos(uint32_t hash, uint32_t shift):
    return 1U << mask(hash, shift)

cdef list clone_and_set(list array, idx, val):
    cdef list clone = array[:]
    clone[idx] = val
    return clone

cdef list clone_and_set_2(list array, idx, val, idx2, val2):
    cdef list clone = array[:]
    clone[idx] = val
    clone[idx2] = val2
    return clone

cdef list remove_pair(list array, i):
    return array[:2*i] + array[2*(i+1):]

cdef Node create_node(uint32_t shift, key1, val1, uint32_t key2hash, key2, val2):
    cdef uint32_t key1hash = hash(key1)
    if key1hash == key2hash:
        return HashCollisionNode(key1hash, 2, [key1, val1, key2, val2])
    cdef bint added_leaf = 0
    return EMPTY_NODE.assoc(shift, key1hash, key1, val1, &added_leaf).assoc(shift, key2hash, key2, val2, &added_leaf)

cdef Node create_node_editable(bint edit, uint32_t shift, key1, val1, uint32_t key2hash, key2, val2):
    cdef uint32_t key1hash = hash(key1)
    if key1hash == key2hash:
        return HashCollisionNode(key1hash, 2, [key1, val1, key2, val2])
    cdef bint added_leaf = 0
    return (EMPTY_NODE
            .tassoc(edit, shift, key1hash, key1, val1, &added_leaf)
            .tassoc(edit, shift, key2hash, key2, val2, &added_leaf))


cdef BitmapIndexedNode EMPTY_NODE = BitmapIndexedNode(0, [])

cdef class BitmapIndexedNode(Node):

    cdef:
        uint32_t _bitmap
        list _array
        bint _editable

    def __cinit__(self, uint32_t bitmap, array, bint edit=False):
        self._bitmap = bitmap
        self._array = array
        self._editable = edit

    cdef Node assoc(self, uint32_t shift, uint32_t hash, key, val, bint *added_leaf):
        cdef list new_array
        cdef Node n
        cdef uint32_t pc
        cdef uint32_t bit = bitpos(<uint32_t>hash, shift)
        cdef uint32_t idx = index(self._bitmap, bit)
        if self._bitmap & bit:
            key_or_null = self._array[2*idx]
            val_or_node = self._array[2*idx+1]
            if key_or_null is NULL_ENTRY:
                n = (<Node>val_or_node).assoc(shift + SHIFT, hash, key, val, added_leaf)
                if n is val_or_node:
                    return self
                return BitmapIndexedNode(self._bitmap, clone_and_set(self._array, 2*idx+1, n))
            if key == key_or_null:
                if val == val_or_node:
                    return self
                return BitmapIndexedNode(self._bitmap, clone_and_set(self._array, 2*idx+1, val))
            added_leaf[0] = 1
            return BitmapIndexedNode(self._bitmap,
                                     clone_and_set_2(self._array,
                                                     2*idx,
                                                     NULL_ENTRY,
                                                     2*idx+1,
                                                     create_node(shift + SHIFT,
                                                                 key_or_null,
                                                                 val_or_node,
                                                                 hash,
                                                                 key,
                                                                 val)))
        else:
            pc = popcount(self._bitmap)
            added_leaf[0] = 1
            new_array = self._array[:2*idx] + [key, val] + self._array[2*idx:]
            # new_array = [None] * (2 * (pc + 1))
            # new_array[:2*idx] = self._array[:2*idx]
            # new_array[2*idx] = key
            # new_array[2*idx+1] = val
            # new_array[2*(idx+1):] = self._array[2*idx:]
            return BitmapIndexedNode(self._bitmap | bit, new_array)

    cdef Node tassoc(self, bint edit, uint32_t shift, uint32_t hash, key, val, bint *added_leaf):
        cdef Node n
        cdef uint32_t pc
        cdef uint32_t bit = bitpos(<uint32_t>hash, shift)
        cdef uint32_t idx = index(self._bitmap, bit)
        cdef BitmapIndexedNode editable
        if self._bitmap & bit:
            key_or_null = self._array[2*idx]
            val_or_node = self._array[2*idx+1]
            if key_or_null is NULL_ENTRY:
                n = (<Node>val_or_node).tassoc(edit, shift + SHIFT,
                                               hash, key, val, added_leaf)
                if n is val_or_node:
                    return self
                return self.edit_and_set(edit, 2*idx+1, n)
            if key == key_or_null:
                if val == val_or_node:
                    return self
                return self.edit_and_set(edit, 2*idx+1, val)
            added_leaf[0] = 1
            return self.edit_and_set_2(edit, 2*idx, NULL_ENTRY,
                                       2*idx+1, 
                                       create_node_editable(edit, shift + SHIFT,
                                                            key_or_null, val_or_node, hash, key, val))
        else:
            pc = popcount(self._bitmap)
            editable = self.ensure_editable(edit)
            added_leaf[0] = 1
            editable._array[2*idx:2*idx] = [key, val]
            editable._bitmap |= bit
            return editable

    cdef Node ensure_editable(self, bint editable):
        if self._editable == editable:
            return self
        return BitmapIndexedNode(self._bitmap, self._array[:], edit=editable)

    cdef find(self, uint32_t shift, uint32_t hash, key, not_found):
        cdef uint32_t bit = bitpos(<uint32_t>hash, shift)
        if (self._bitmap & bit) == 0:
            return not_found
        cdef uint32_t idx = index(self._bitmap, bit)
        key_or_null = self._array[2*idx]
        val_or_node = self._array[2*idx+1]
        if key_or_null is NULL_ENTRY:
            return (<Node>val_or_node).find(shift + SHIFT, hash, key, not_found)
        if key == key_or_null:
            return val_or_node
        return not_found

    cdef NodeIter _iter(self, key_val_item_t kvi):
        return NodeIter(self._array, kvi)
    
    cdef Node without(self, uint32_t shift, uint32_t hash, key):
        cdef uint32_t bit = bitpos(<uint32_t>hash, shift)
        if self._bitmap & bit == 0:
            return self
        cdef uint32_t idx = index(self._bitmap, bit)
        key_or_null = self._array[2*idx]
        val_or_node = self._array[2*idx+1]
        cdef Node n
        if key_or_null is NULL_ENTRY:
            n = (<Node>val_or_node).without(shift + SHIFT, hash, key)
            if n is val_or_node:
                return self
            if n is not NULL_ENTRY:
                return BitmapIndexedNode(self._bitmap, clone_and_set(self._array, 2*idx+1, n))
            if self._bitmap == bit:
                return NULL_ENTRY
            return BitmapIndexedNode(self._bitmap ^ bit,
                                     remove_pair(self._array, idx))
        if key == key_or_null:
            # TODO: collapse
            return BitmapIndexedNode(self._bitmap ^ bit, remove_pair(self._array, idx))
        return self

    cdef Node twithout(self, bint edit, uint32_t shift, uint32_t hash, key, bint *removed_leaf):
        cdef uint32_t bit = bitpos(<uint32_t>hash, shift)
        if self._bitmap & bit == 0:
            return self
        cdef uint32_t idx = index(self._bitmap, bit)
        key_or_null = self._array[2*idx]
        val_or_node = self._array[2*idx+1]
        cdef Node n
        if key_or_null is NULL_ENTRY:
            n = (<Node>val_or_node).twithout(edit, shift + SHIFT, hash, key, removed_leaf)
            if n is val_or_node:
                return self
            if n is not NULL_ENTRY:
                return self.edit_and_set(edit, 2*idx+1, n)
            if self._bitmap == bit:
                return <BitmapIndexedNode>NULL_ENTRY
            return self.edit_and_remove_pair(edit, bit, idx)
        if key == key_or_null:
            removed_leaf[0] = True
            # TODO: collapse.
            return self.edit_and_remove_pair(edit, bit, idx)
        return self


    cdef BitmapIndexedNode edit_and_set(self, bint edit, int i, a):
        cdef BitmapIndexedNode editable = self.ensure_editable(edit)
        editable._array[i] = a
        return editable

    cdef Node edit_and_remove_pair(self, bint edit, uint32_t bit, int i):
        if self._bitmap == bit:
            return NULL_ENTRY
        cdef BitmapIndexedNode editable = self.ensure_editable(edit)
        editable._bitmap ^= bit
        del editable._array[2*i:2*(i+1)]
        return editable

    cdef BitmapIndexedNode edit_and_set_2(self, bint edit, int i, a, int j, b):
        cdef BitmapIndexedNode editable = self.ensure_editable(edit)
        editable._array[i] = a
        editable._array[j] = b
        return editable


cdef class HashCollisionNode(Node):

    cdef:
        uint32_t _hash
        Py_ssize_t _cnt
        list _array

    def __cinit__(self, uint32_t hash, Py_ssize_t count, array):
        self._hash = hash
        self._cnt = count
        self._array = array

    cdef Node assoc(self, uint32_t shift, uint32_t hash, key, val, bint *added_leaf):
        cdef int idx
        if hash == self._hash:
            idx = self.find_index(key)
            if idx != -1:
                if self._array[idx+1] == val:
                    return self
                return HashCollisionNode(hash, self._cnt, clone_and_set(self._array, idx+1, val))
            new_array = self._array[:]
            new_array.extend([key, val])
            added_leaf[0] = 1
            return HashCollisionNode(hash, self._cnt + 1, new_array)
        return BitmapIndexedNode(bitpos(self._hash, shift),
                                 [NULL_ENTRY, self]).assoc(shift, hash,
                                                     key, val,
                                                     added_leaf)

    cdef int find_index(self, key):
        cdef int i
        for i in range(0, 2*self._cnt, 2):
            if self._array[i] == key:
                return i
        return -1

    cdef find(self, uint32_t shift, uint32_t hash, key, not_found):
        cdef int idx = self.find_index(key)
        if idx < 0:
            return not_found
        if key == self._array[idx]:
            return self._array[idx+1]
        return not_found

    cdef Node without(self, uint32_t shift, uint32_t hash, key):
        cdef int idx = self.find_index(key)
        if idx < 0:
            return self
        if self._cnt == 1:
            return NULL_ENTRY
        return HashCollisionNode(self._hash,
                                 self._cnt - 1,
                                 remove_pair(self._array, idx//2))
    
    cdef NodeIter _iter(self, key_val_item_t kvi):
        return NodeIter(self._array, kvi)


cdef object NODE_ITER_NULL = object()

cdef inline kvi(key_val_item_t kvi, key, val):
    if kvi == _KEY_:
        return key
    elif kvi == _VAL_:
        return val
    elif kvi == _ITEM_:
        return (key, val)


cdef class NodeIter:

    # TODO: FIXME: this is a direct translation from the Clojure Java source.
    # It's very java-ish, and quite convoluted.  There must be a better way!

    def __cinit__(self, array, kvi):
        self._i = 0
        self._array = array
        self._next_entry = NODE_ITER_NULL
        self._next_iter = None
        self._key_val_item = kvi

    cdef bint _advance(self):
        while self._i < len(self._array):
            key = self._array[self._i]
            val_or_node = self._array[self._i+1]
            self._i += 2
            if key is not NULL_ENTRY:
                self._next_entry = kvi(self._key_val_item, key, val_or_node)
                return True
            elif val_or_node is not NULL_ENTRY:
                it = (<Node>val_or_node)._iter(self._key_val_item)
                if it.has_next():
                    self._next_iter = it
                    return True
        return False

    cdef bint has_next(self):
        if self._next_entry is not NODE_ITER_NULL or self._next_iter is not None:
            return True
        return self._advance()

    def __iter__(self):
        return self
    
    def __next__(self):
        ret = self._next_entry
        if ret is not NODE_ITER_NULL:
            self._next_entry = NODE_ITER_NULL
            return ret
        elif self._next_iter is not None:
            ret = next(self._next_iter)
            if not self._next_iter.has_next():
                self._next_iter = None
            return ret
        elif self._advance():
            return next(self)
        raise StopIteration()
