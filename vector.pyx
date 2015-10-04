DEF SHIFT = 5
DEF NN = 2**SHIFT

cdef class Node:

    cdef list _array

    def __cinit__(self, array=None):
        if array is None:
            self._array = [None] * NN
        else:
            self._array = array


cdef int _tailoff(cnt):
    # TODO: Check to make sure this works properly with C ints & C
    # semantics.
    # FIXME: Should self._cnt be unsigned, or py_ssize_t?  Use whatever is
    # used for Python List sizes...
    if cnt < NN:
        return 0
    # TODO: FIXME: 5 is a magic number here.  Should it be SHIFT instead?
    return ((cnt - 1) >> SHIFT) << SHIFT


cdef Node EMPTY_NODE = Node()

def vec(*args):
    if len(args) <= 1:
        seq = args[0] if len(args) == 1 else []
        return PersistentVector.from_sequence(seq)
    if len(args) == 4:
        return PersistentVector(*args)

cdef class PersistentVector:

    cdef:
        int _cnt # TODO: NOTE: should this be a py_ssize_t or somesuch?
        int _shift
        Node _root
        list _tail

    @classmethod
    def from_sequence(cls, seq):
        seq = seq or []
        if not isinstance(seq, (list, tuple)):
            msg = "converting from types other than list or tuple not yet supported."
            raise NotImplementedError(msg)
        cnt = len(seq)
        if cnt < 32:
            return cls(cnt, SHIFT, EMPTY_NODE, list(seq))
        else:
            raise NotImplementedError("more than %d elements not yet supported." % NN)

    def __init__(self, cnt, shift, Node root, list tail):
        self._cnt = cnt
        self._shift = shift
        self._root = root
        self._tail = tail

    def __len__(self):
        return self._cnt

    def __getitem__(self, i):
        cdef list node = self._array_for(i)
        return node[i & 0x01f]

    cdef list _array_for(self, int i):
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


    def cons(self, val):
        cdef:
            list newtail
            Node newroot, tailnode
            int newshift
        if self._cnt - _tailoff(self._cnt) < NN:
            newtail = self._tail + [val]
            return PersistentVector(self._cnt + 1, self._shift, self._root, newtail)
        tailnode = Node(self._tail)
        newshift = self._shift
        if (self._cnt >> 5) > (1 << self._shift):
            newroot = Node()
            newroot._array[0] = self._root
            newroot._array[1] = self._new_path(self._shift, tailnode)
            newshift += SHIFT
        else:
            newroot = self._push_tail(self._shift, self._root, tailnode)
        return PersistentVector(self._cnt + 1, newshift, newroot, [val])


    cdef Node _new_path(self, int level, Node node):
        if not level:
            return node
        cdef Node ret = Node()
        ret._array[0] = self._new_path(level - SHIFT, node)
        return ret


    cdef Node _push_tail(self, int level, Node parent, Node tailnode):
        cdef int subidx = ((self._cnt - 1) >> level) & 0x01f
        cdef Node ret = Node(parent._array[:])
        cdef Node node_to_insert, child
        if level == SHIFT:
            node_to_insert = tailnode
        else:
            child = parent._array[subidx]
            if child is not None:
                node_to_insert = self._push_tail(level-SHIFT, child, tailnode) 
            else:
                node_to_insert = self._new_path(level-SHIFT, tailnode)
        ret._array[subidx] = node_to_insert
        return ret


    def assoc(self, int i, val):
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
        cdef Node ret = Node(node._array[:])
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


cdef Node editable_root(Node root):
    return Node(root._array[:])

cdef list editable_tail(list tail):
    return tail[:]


cdef class TransientVector:

    cdef:
        int _cnt
        int _shift
        Node _root
        list _tail

    # @classmethod
    # def from_vector(cls, Vector v):
        # self._cnt = v._cnt
        # self._shift = v._shift
        # self._root = editable_root(v._root)
        # self._tail = editable_tail(v._tail)
    
    # def __init__(self, cnt, shift, Node root, list tail):
        # self._cnt = 


    def ensure_editable(self):
        # TODO: detect when editing after making it persistent...
        pass


    def conj(self, val):
        self.ensure_editable()
        if self._cnt - _tailoff(self._cnt) < NN:
            self._tail[self._cnt & 0x01f] = val
            self._cnt += 1
            return self
        cdef Node newroot
        cdef Node tailnode = Node(self._tail)
        self._tail = [None] * NN
        self._tail[0] = val
        cdef int newshift = self._shift
        if (self._cnt >> 5) > (1 << self._shift):
            newroot = Node()
            newroot._array[0] = self._root
            newroot.array[1] = self.new_path(self._shift, tailnode)
            newshift += 5
        else:
            newroot = self.push_tail(self._shift, self._root, tailnode)
        self._root = newroot
        self._shift = newshift
        self._cnt += 1
        return self


    def persistent(self):
        self.ensure_editable()
        assert False
