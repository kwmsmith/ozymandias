
DEF NN = 32
DEF SHIFT = 5

cdef class Node:
    cdef list _array
    def __cinit__(self, array=None):
        if array is None:
            self._array = [None] * NN
        else:
            self._array = array

cdef Node EMPTY_NODE = Node()


cdef class Vector:

    cdef:
        int _cnt # TODO: NOTE: should this be a py_ssize_t or somesuch?
        int _shift
        Node _root
        list _tail

    def __init__(self, seq=None):
        seq = seq or []
        if not isinstance(seq, (list, tuple)):
            msg = "converting from types other than list or tuple not yet supported."
            raise NotImplementedError(msg)
        cnt = len(seq)
        if cnt < 32:
            self._init(cnt, SHIFT, EMPTY_NODE, list(seq))
        else:
            raise NotImplementedError("more than %d elements not yet supported." % NN)


    def _init(self, cnt, shift, Node root, list tail):
        self._cnt = cnt
        self._shift = shift
        self._root = root
        self._tail = tail

    def __len__(self):
        return self._cnt

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
