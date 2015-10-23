from libc.stdint cimport uint32_t

DEF SHIFT = 5U
DEF NN = (1U << SHIFT)

# TODO: FIXME: http://docs.cython.org/src/userguide/extension_types.html#fast-instantiation
# Apply these ideas to Node() instantiation...

cdef extern from *:
    uint32_t popcount "__builtin_popcount"(uint32_t)

cdef class APersistentHashMap:
    pass

def map(*args, **kwargs):
    return PersistentHashMap(0, EMPTY_NODE)

cdef PersistentHashMap EMPTY = PersistentHashMap(0, None)

cdef object NULL_ENTRY = object()
cdef object NOT_FOUND = object()

cdef class PersistentHashMap(APersistentHashMap):

    cdef:
        Py_ssize_t _cnt
        Node _root

    def __cinit__(self, cnt, root):
        self._cnt = cnt
        self._root = root

    def __len__(self):
        return self._cnt

    def __getitem__(self, key):
        if self._root is None:
            raise KeyError("key %s not found." % key)
        val = self._root.find(0U, hash(key), key, NOT_FOUND)
        if val is NOT_FOUND:
            raise KeyError("key %s not found." % key)
        return val


    def assoc(self, key, value):
        cdef Node newroot
        cdef bint added_leaf = 0
        if self._root is None:
            newroot = EMPTY_NODE
        else:
            newroot = self._root
        newroot = newroot.assoc(0, hash(key), key, value, &added_leaf)
        if newroot == self._root:
            return self
        return PersistentHashMap(self._cnt if added_leaf == 0 else self._cnt + 1,
                                 newroot)

cdef class Node:

    cdef Node assoc(self, uint32_t shift, long hash, key, val, bint *added_leaf):
        raise NotImplementedError("Node.assoc() not implemented.")

    cdef find(self, uint32_t shift, long hash, key, not_found):
        raise NotImplementedError("Node.find() not implemented.")


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

cdef Node create_node(uint32_t shift, key1, val1, long key2hash, key2, val2):
    cdef long key1hash = hash(key1)
    if key1hash == key2hash:
        return HashCollisionNode(key1hash, 2, [key1, val1, key2, val2])
    cdef bint added_leaf = 0
    return EMPTY_NODE.assoc(shift, key1hash, key1, val1, &added_leaf).assoc(shift, key2hash, key2, val2, &added_leaf)


cdef BitmapIndexedNode EMPTY_NODE = BitmapIndexedNode(0, [])

cdef class BitmapIndexedNode(Node):

    cdef:
        uint32_t _bitmap
        list _array

    def __cinit__(self, uint32_t bitmap, array):
        self._bitmap = bitmap
        self._array = array


    cdef Node assoc(self, uint32_t shift, long hash, key, val, bint *added_leaf):
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
            new_array = [None] * (2 * (pc + 1))
            new_array[:2*idx] = self._array[:2*idx]
            new_array[2*idx] = key
            added_leaf[0] = 1
            new_array[2*idx+1] = val
            new_array[2*(idx+1):] = self._array[2*idx:]
            return BitmapIndexedNode(self._bitmap | bit, new_array)


    cdef find(self, uint32_t shift, long hash, key, not_found):
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


cdef class HashCollisionNode(Node):

    cdef:
        long _hash
        Py_ssize_t _cnt
        list _array

    def __cinit__(self, long hash, Py_ssize_t count, array):
        self._hash = hash
        self._cnt = count
        self._array = array

    cdef Node assoc(self, uint32_t shift, long hash, key, val, bint *added_leaf):
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
        return BitmapIndexedNode(bitpos(<uint32_t>hash, shift),
                                 [None, self]).assoc(shift, hash,
                                                     key, val,
                                                     added_leaf)

    cdef int find_index(self, key):
        cdef int i
        for i in range(0, 2*self._cnt, 2):
            if self._array[i] == key:
                return i
        return -1

    cdef find(self, uint32_t shift, long hash, key, not_found):
        cdef int idx = self.find_index(key)
        if idx < 0:
            return not_found
        if key == self._array[idx]:
            return self._array[idx+1]
        return not_found
