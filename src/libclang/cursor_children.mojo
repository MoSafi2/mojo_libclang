"""Cursor visitor helpers.

Wraps `clang_visitChildren` via the C-shim trampoline
`mojo_clang_visitChildren`. The trampoline calls back into Mojo with pointers
to `CXCursor` and `CXCursor`, so the by-value ABI corruption noted in
`raw_bindings.md` is avoided.
"""
from src._ffi import (
    CXCursor,
    CXClientData,
    CXChildVisitResult,
    CXChildVisit_Continue,
    clang_visitChildren,
    c_uint,
)
from src.libclang.cursor import Cursor
from std.memory import UnsafePointer, MutOpaquePointer, memcpy


comptime MAX_CHILDREN = 1024


@fieldwise_init
struct _Collector(Copyable, Movable):
    var buffer: UnsafePointer[CXCursor, MutAnyOrigin]
    var count: Int


def _visit_trampoline(
    cursor: Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
    parent: Optional[UnsafePointer[CXCursor, MutExternalOrigin]],
    client_data: CXClientData,
) abi("C") -> CXChildVisitResult:
    var opaque = client_data.value()
    var user_bytes = rebind[UnsafePointer[UInt8, MutExternalOrigin]](opaque)
    var collector = rebind[UnsafePointer[_Collector, MutAnyOrigin]](
        rebind[UnsafePointer[UInt8, MutAnyOrigin]](user_bytes),
    )
    if collector[].count < MAX_CHILDREN:
        var src = rebind[UnsafePointer[UInt8, ImmutExternalOrigin]](
            cursor.value()
        )
        var dst = rebind[UnsafePointer[UInt8, MutExternalOrigin]](
            collector[].buffer + collector[].count,
        )
        memcpy(dest=dst, src=src, count=32)
        collector[].count += 1
    return CXChildVisit_Continue


def collect_children(parent: Cursor) raises -> List[Cursor]:
    var buffer = alloc[CXCursor](MAX_CHILDREN)
    var collector_box = alloc[_Collector](1)
    collector_box[] = _Collector(buffer=buffer, count=0)
    var box_ptr = UnsafePointer[_Collector, MutAnyOrigin](to=collector_box[])
    var client_data = CXClientData(
        rebind[MutOpaquePointer[MutExternalOrigin]](
            rebind[UnsafePointer[UInt8, MutExternalOrigin]](
                rebind[UnsafePointer[UInt8, MutAnyOrigin]](box_ptr),
            ),
        ),
    )
    # Use raw InlineArray like the working probe tests
    var raw_storage = InlineArray[CXCursor, 1](
        fill=CXCursor(
            kind=0,
            xdata=0,
            data=InlineArray[
                Optional[ImmutOpaquePointer[ImmutExternalOrigin]], 3
            ](fill=None),
        )
    )
    var raw_ptr = rebind[UnsafePointer[CXCursor, MutExternalOrigin]](
        raw_storage.unsafe_ptr()
    )
    var src = rebind[UnsafePointer[UInt8, ImmutExternalOrigin]](
        parent._raw.unsafe_ptr()
    )
    var dst = rebind[UnsafePointer[UInt8, MutExternalOrigin]](raw_ptr)
    memcpy(dest=dst, src=src, count=32)
    _ = clang_visitChildren(raw_ptr, _visit_trampoline, client_data)
    var out = List[Cursor]()
    for i in range(collector_box[].count):
        var c = Cursor(tu=parent._tu)
        var c_src = rebind[UnsafePointer[UInt8, ImmutExternalOrigin]](
            buffer + i
        )
        var c_dst = rebind[UnsafePointer[UInt8, MutExternalOrigin]](
            c._raw.unsafe_ptr()
        )
        memcpy(dest=c_dst, src=c_src, count=32)
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
