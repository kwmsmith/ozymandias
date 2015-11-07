from __future__ import print_function

# TODO: FIXME: http://docs.cython.org/src/userguide/extension_types.html#fast-instantiation
# Apply these ideas to Node() instantiation...

DEF SHIFT = 5U
DEF NN = (1U << SHIFT)


cdef class Node:

    cdef bint _editable
    cdef list _array

    def __cinit__(self, editable, array=None):
        self._editable = editable
        if array is None:
            self._array = [None] * NN
        else:
            self._array = array


cdef unsigned int _tailoff(unsigned int cnt):
    # TODO: Check to make sure this works properly with C ints & C
    # semantics.
    # FIXME: Should self._cnt be unsigned, or py_ssize_t?  Use whatever is
    # used for Python List sizes...
    if cnt < NN:
        return 0
    return ((cnt - 1) >> SHIFT) << SHIFT

cdef Node _new_path(bint editable, int level, Node node):
    if not level:
        return node
    cdef Node ret = Node(editable)
    ret._array[0] = _new_path(editable, level - SHIFT, node)
    return ret


cdef Node EMPTY_NODE = Node(editable=False)

def vec(*args):
    if len(args) <= 1:
        seq = args[0] if len(args) == 1 else []
        return PersistentVector.from_sequence(seq)
    msg = "vec() takes at most 1 argument (%d given)"
    raise TypeError(msg % len(args))

DEF NULL_HASH = -1
DEF UNHASHED = -2
DEF SAFEHASH = -3

cdef class APersistentVector:

    cdef long _hash

    def __cinit__(self):
        self._hash = UNHASHED

    def __repr__(self):
        if len(self):
            strs = []
            for item in self:
                strs.append(repr(item))
            return "vec([%s])" % ", ".join(strs)
        else:
            return "vec()"


    def __str__(self):
        return repr(self)


    def __richcmp__(x, y, int op):
        assert (isinstance(x, APersistentVector) or isinstance(y, APersistentVector))
        if op == 2: # ==
            if (not isinstance(x, APersistentVector) or 
                not isinstance(y, APersistentVector)):
                # Both have to be the same type to be equal.
                return False
            else:
                return (<APersistentVector>x)._equals(<APersistentVector>y)
        elif op == 3: # !=
            return not x == y
        else:
            raise NotImplementedError()


    def __contains__(self, obj):
        for v in self:
            if obj == v:
                return True
        return False


    def index(self, item, start=None, stop=None):
        cdef:
            int i
            int istart = start or 0
            int istop = stop or len(self)
        for i in range(istart, istop):
            # TODO: improve performance, shouldn't go through __getitem__.
            if self[i] == item:
                return i
        raise ValueError("%s is not in vec." % item)


    def count(self, value):
        cdef:
            int c = 0
        for v in self:
            if v == value:
                c += 1
        return c


    cdef bint _equals(self, APersistentVector obj):
        if self is obj:
            return True
        if len(self) != len(obj):
            return False
        for a, b in zip(self, obj):
            if a != b:
                return False
        return True


    def __hash__(self):
        cdef long y
        cdef long x = 0x345678L
        cdef Py_ssize_t ll = len(self)
        cdef long mult = 1000003L
        if self._hash != UNHASHED and self._hash != NULL_HASH:
            return self._hash
        if self._hash == NULL_HASH:
            raise TypeError("vec contains unhashable type.")
        elif self._hash == UNHASHED:
            for ob in self:
                try:
                    y = hash(ob)
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

from collections import Sequence
Sequence.register(APersistentVector)

cdef PersistentVector EMPTY = PersistentVector(0, SHIFT, EMPTY_NODE, [])

cdef class PersistentVector(APersistentVector):

    cdef:
        Py_ssize_t _cnt
        int _shift
        Node _root
        list _tail

    @classmethod
    def from_sequence(cls, seq):
        it = iter(seq or [])
        ret = EMPTY
        for item in it:
            ret = ret.cons(item)
        return ret


    def __cinit__(self, cnt, shift, Node root, list tail):
        self._cnt = cnt
        self._shift = shift
        self._root = root
        self._tail = tail

    def __len__(self):
        return self._cnt

    cdef _get_item(self, int i):
        cdef list node = self.array_for(i)
        return node[i & 0x01f]

    cdef _get_slice(self, slice sl):
        cdef:
            int start, stop, stride
        start, stop, stride = sl.indices(len(self))
        if stride != 1:
            raise NotImplementedError("non unitary stride not yet supported.")
        return SubVector(self, start, stop)

    def __getitem__(self, i_or_slice):
        if isinstance(i_or_slice, int):
            return self._get_item(i_or_slice)
        elif isinstance(i_or_slice, slice):
            return self._get_slice(i_or_slice)

    cdef list array_for(self, int i):
        cdef Node node
        cdef int level
        if 0 <= i < self._cnt:
            if i >= _tailoff(self._cnt):
                return self._tail
            node = self._root        
            level = self._shift
            while level > 0:
                node = node._array[(i >> level) & 0x01f]
                level -= SHIFT
            return node._array
        raise IndexError()

    cpdef cons(self, val):
        cdef:
            list newtail
            Node newroot, tailnode
            int newshift
        if self._cnt - _tailoff(self._cnt) < NN:
            newtail = self._tail + [val]
            return PersistentVector(self._cnt + 1, self._shift, self._root, newtail)
        tailnode = Node(self._root._editable, self._tail)
        newshift = self._shift
        if (self._cnt >> 5) > (1 << self._shift):
            newroot = Node(self._root._editable)
            newroot._array[0] = self._root
            newroot._array[1] = _new_path(self._root._editable, self._shift, tailnode)
            newshift += SHIFT
        else:
            newroot = self._push_tail(self._shift, self._root, tailnode)
        return PersistentVector(self._cnt + 1, newshift, newroot, [val])

    cdef Node _push_tail(self, int level, Node parent, Node tailnode):
        cdef int subidx = ((self._cnt - 1) >> level) & 0x01f
        cdef Node ret = Node(parent._editable, parent._array[:])
        cdef Node node_to_insert, child
        if level == SHIFT:
            node_to_insert = tailnode
        else:
            child = parent._array[subidx]
            if child is not None:
                node_to_insert = self._push_tail(level-SHIFT, child, tailnode) 
            else:
                node_to_insert = _new_path(self._root._editable, level-SHIFT, tailnode)
        ret._array[subidx] = node_to_insert
        return ret

    cpdef assoc(self, int i, val):
        cdef list newtail
        if 0 <= i < self._cnt:
            if i >= _tailoff(self._cnt):
                newtail = self._tail[:]
                newtail[i & 0x01f] = val
                return PersistentVector(self._cnt, self._shift, self._root, newtail)
            return PersistentVector(self._cnt,
                                    self._shift,
                                    self._do_assoc(self._shift, self._root, i, val),
                                    self._tail)
        raise IndexError()

    cdef Node _do_assoc(self, int level, Node node, int i, val):
        cdef Node ret = Node(node._editable, node._array[:])
        cdef int subidx
        if not level:
            ret._array[i & 0x01f] = val
        else:
            subidx = (i >> level) & 0x01f
            ret._array[subidx] = self._do_assoc(level - SHIFT,
                                                <Node>(node._array[subidx]),
                                                i,
                                                val)
        return ret

    def __iter__(self):
        return ChunkedIter(self)


cdef Node editable_root(Node root):
    return Node(True, root._array[:])

cdef list editable_tail(list tail):
    return tail[:] + [None] * (NN - len(tail))


cdef class ChunkedIter:

    cdef:
        PersistentVector _vec
        list _chunk
        int _i, _offset

    def __cinit__(self, vec):
        self._vec = vec
        self._i = 0 # global index into entire vec.
        self._offset = 0 # local index into chunk.
        if len(self._vec):
            self._chunk = self._vec.array_for(self._i)
        else:
            self._chunk = []

    def __next__(self):
        if self._i >= len(self._vec):
            raise StopIteration()
        ret = self._chunk[self._offset]
        self._i += 1
        if self._i < len(self._vec):
            if self._offset + 1 < len(self._chunk):
                self._offset += 1
            else:
                self._chunk = self._vec.array_for(self._i)
                self._offset = 0
        return ret

    def __iter__(self):
        return self


cdef class SubVector(APersistentVector):

    cdef:
        PersistentVector _vec
        int _start
        int _end

    def __cinit__(self, vec, int start, int end):
        if isinstance(vec, PersistentVector):
            self._vec = vec
        elif isinstance(vec, SubVector):
            self._vec = vec._vec
            start += vec._start
            end += vec._start
        self._start = start
        self._end = end

    def __getitem__(self, index):
        if self._start + index >= self._end or index < 0:
            raise IndexError()
        return self._vec[self._start + index]

    def assoc(self, int i, val):
        if self._start + i > self._end:
            raise IndexError()
        return SubVector(self._vec.assoc(self._start + i, val), self._start, self._end)

    def __len__(self):
        return self._end - self._start

    def cons(self, val):
        return SubVector(self._vec.assoc(self._end, val), self._start, self._end + 1)

cdef class TransientVector:

    cdef:
        Py_ssize_t _cnt
        int _shift
        Node _root
        list _tail

    def __cinit__(self, cnt, shift, root, tail):
        self._cnt = cnt
        self._shift = shift
        self._root = root
        self._tail = tail

    @classmethod
    def from_persistent(cls, PersistentVector pvec):
        return cls(pvec._cnt, pvec._shift, editable_root(pvec._root), editable_tail(pvec._tail))

    cdef Node ensure_editable(self, Node node):
        if node._editable == self._root._editable:
            return node
        return Node(self._root._editable, node._array[:])

    def ensure_editable_root(self):
        if not self._root._editable:
            raise RuntimeError("Transient used after made persistent.")

    def __len__(self):
        self.ensure_editable_root()
        return self._cnt

    cpdef PersistentVector persistent(self):
        self.ensure_editable_root()
        self._root._editable = False
        cdef list newtail = self._tail[:self._cnt - _tailoff(self._cnt)]
        return PersistentVector(self._cnt, self._shift, self._root, newtail)

    cpdef TransientVector conj(self, val):
        self.ensure_editable_root()
        cdef Py_ssize_t i = self._cnt
        if i - _tailoff(self._cnt) < NN:
            self._tail[i & 0x01F] = val
            self._cnt += 1
            return self
        cdef Node newroot
        cdef Node tailnode = Node(self._root._editable, self._tail)
        self._tail = [None] * NN
        self._tail[0] = val
        cdef int newshift = self._shift
        if (self._cnt >> SHIFT) > ( 1U << self._shift):
            newroot = Node(self._root._editable)
            newroot._array[0] = val
            newroot._array[1] = _new_path(self._root._editable, self._shift, tailnode)
            newshift += SHIFT
        else:
            newroot = self._push_tail(self._shift, self._root, tailnode)
        self._root = newroot
        self._shift = newshift
        self._cnt += 1
        return self

    cdef Node _push_tail(self, int level, Node parent, Node tailnode):
        parent = self.ensure_editable(parent)
        cdef int subidx = ((self._cnt - 1) >> level) & 0x01f
        cdef Node child
        cdef Node ret = parent
        cdef Node node_to_insert
        if level == SHIFT:
            node_to_insert = tailnode
        else:
            child = <Node>parent._array[subidx]
            if child is None:
                node_to_insert = _new_path(self._root._editable, level - SHIFT, tailnode)
            else:
                node_to_insert = self._push_tail(level - SHIFT, child, tailnode)
        ret._array[subidx] = node_to_insert
        return ret
