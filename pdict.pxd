DEF SIZE = 8

struct kv:
    # TODO: FIXME: use a proper integer type here...
    long hash    
    object k
    object v

cdef class PDict:

    cdef int _len
    cdef kv _kvs[8]
