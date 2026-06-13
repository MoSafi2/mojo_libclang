"""Cursor visitor helpers.

Wraps `clang_visitChildren` via the C-shim trampoline
`mojo_clang_visitChildren`. The trampoline calls back into Mojo with pointers
to `CXCursor` and `CXCursor`, so the by-value ABI corruption noted in
`raw_bindings.md` is avoided.
"""
from src.libclang_raw import (
    CXCursor,
    CXClientData,
    CXChildVisitResult,
    CXChildVisit_Break,
    CXChildVisit_Continue,
    clang_visitChildren_trampoline,
    MojoCursorVisitorFn,
    c_uint,
)
from src.libclang.cursor import Cursor
from std.memory import UnsafePointer, memcpy


comptime MAX_CHILDREN = 1024


@fieldwise_init
struct _Collector(Copyable, Movable):
    var buffer: UnsafePointer[CXCursor, MutAnyOrigin]
    var count: Int


def _visit_trampoline(
    cursor: UnsafePointer[CXCursor, MutExternalOrigin],
    parent: UnsafePointer[CXCursor, MutExternalOrigin],
    user_data: UnsafePointer[UInt8, MutExternalOrigin],
) abi("C") -> c_uint:
    if not user_data:
        return 0
    var collector = rebind[UnsafePointer[_Collector, MutAnyOrigin]](
        rebind[UnsafePointer[UInt8, MutAnyOrigin]](user_data),
    )
    if collector[].count < MAX_CHILDREN:
        # The pointer-based trampoline hands us a real, uncorrupted CXCursor.
        # We must byte-copy it because `CXCursor` is 32 bytes and the
        # by-value RegisterPassable spill corrupts fields beyond the first
        # scalar. Memcpy preserves the data verbatim.
        var src = rebind[UnsafePointer[UInt8, ImmutExternalOrigin]](cursor)
        var dst = rebind[UnsafePointer[UInt8, MutExternalOrigin]](
            collector[].buffer + collector[].count,
        )
        memcpy(dest=dst, src=src, count=32)  # sizeof(CXCursor) on Linux x86_64
        collector[].count += 1
    return 1  # CXChildVisit_Continue = 1


def collect_children(parent: Cursor) raises -> List[Cursor]:
    var buffer = alloc[CXCursor](MAX_CHILDREN)
    var collector_box = alloc[_Collector](1)
    collector_box[] = _Collector(buffer=buffer, count=0)
    var box_ptr = UnsafePointer[_Collector, MutAnyOrigin](to=collector_box[])
    var visitor_data = rebind[UnsafePointer[UInt8, MutExternalOrigin]](
        rebind[UnsafePointer[UInt8, MutAnyOrigin]](box_ptr),
    )
    var parent_ptr = rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
        parent._raw.unsafe_ptr(),
    )
    _ = clang_visitChildren_trampoline(parent_ptr, _visit_trampoline, visitor_data)
    var out = List[Cursor]()
    for i in range(collector_box[].count):
        var c = Cursor(tu=parent._tu)
        # Same byte-copy pattern to avoid the by-value ABI corruption.
        var src = rebind[UnsafePointer[UInt8, ImmutExternalOrigin]](buffer + i)
        var dst = rebind[UnsafePointer[UInt8, MutExternalOrigin]](c._raw.unsafe_ptr())
        memcpy(dest=dst, src=src, count=32)
        out.append(c^)
    collector_box.free()
    buffer.free()
    return out^


def walk_preorder(root: Cursor) raises -> List[Cursor]:
    var out = List[Cursor]()
    out.append(root.copy())
    var children = collect_children(root)
    for i in range(0, Int(children.__len__())):
        var grand = walk_preorder(children[i].copy())
        for j in range(0, Int(grand.__len__())):
            out.append(grand[j].copy())
    return out^
