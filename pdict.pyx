# NOTE: Since this is persistent, we can reorder things as we like.  Perhaps
# ordering on hash value would be useful to optimize __getitem__.

# NOTE: Another thing to try: keep two separate arrays, one for the hashes
# only, another for the k/v pairs.  The idea is that the hash-only array is
# more cache friendly, so operations on just the hashes may be faster.

cdef inline void _set_kv(kv* _kv, k, v):
    _kv.hash = hash(k)
    _kv.key = k
    _kv.value = v

cdef inline void _swap(kv* a, kv* b):

    cdef long tmp_hash = a.hash
    a.hash = b.hash
    b.hash = tmp_hash

    cdef PyObject* tmp_o = a.key
    a.key = b.key
    b.key = tmp_o

    tmp_o = a.value
    a.value = b.value
    b.value = tmp_o


cdef void _sort_kvs(kv* _kvs, const int len):
    cdef int i, nsorted = 1
    cdef kv* next = &_kvs[nsorted]
    while nsorted < len:
        for i in range(nsorted):
            if next.hash < _kvs[i].hash:
                # make room for next.
                for j in range(i, nsorted):
                    _swap(&_kvs[j], &_kvs[nsorted])
        nsorted += 1
        next = &_kvs[nsorted]


cdef class HashSortedPDict:

    def __init__(self, *kwargs):
        if len(kwargs) > SIZE:
           raise ValueError("Too much!")
        for idx, (k, v) in enumerate(kwargs.items()):
            _set_kv(&_kv[idx], k, v)
        self._len = len(kwargs)
        _sort_kvs(*self._kvs, self._len)

    def __getitem__(self, k):
        long h = hash(k)
        if (h < self._kvs[0].hash or
            h > self._kvs[SIZE-1].hash):
            raise KeyError(k)
        for i in range(self._len):
            # TODO: FIXME: what's the fast path here?  How should this if/elif
            # be reordered?
            if h < self._kvs[idx].hash:
                raise KeyError(k)
            elif h > self._kvs[idx].hash:
                continue
            elif (k is self._kvs[idx].key or
                  k == self._kvs[idx].key):
                return self._kvs[idx].value
        raise KeyError(k)


cdef class PDict:

    def __init__(self, *kwargs):
        if len(kwargs) > SIZE:
           raise ValueError("Too much!")
        for idx, (k, v) in enumerate(kwargs.items()):
            _set_kv(&_kv[idx], k, v)
        self._len = len(kwargs)

    def __getitem__(self, k):
        long h = hash(k)
        for i in range(self._len):
            if self._kvs[idx].hash != h:
                continue
            if (k is self._kvs[idx].key or
                k == self._kvs[idx].key):
                return self._kvs[idx].value
        raise KeyError(k)
