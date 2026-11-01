"""Layout-preserving normalization for libclang's native C calling convention.

Mojo bindgen treats Array fields as memory-only. Flatten fixed arrays in records
that cross the ABI by value, keeping each element's C type and clang offset.
Function signatures, callback signatures, and pointer-only records stay intact.
"""

from dataclasses import replace

from mojo_bindgen.analysis.traversal import iter_decl_types
from mojo_bindgen.analysis.type_walk import iter_type_nodes
from mojo_bindgen.ir import Array, Function, FunctionPtr, QualifiedType, Struct, StructRef, TypeRef, Unit


def unwrap(typ):
    while isinstance(typ, (TypeRef, QualifiedType)):
        typ = typ.canonical if isinstance(typ, TypeRef) else typ.unqualified
    return typ


def normalize_direct_abi(unit: Unit) -> Unit:
    records = {decl.name: decl for decl in unit.decls if isinstance(decl, Struct)}
    by_value: set[str] = set()

    def visit(typ):
        typ = unwrap(typ)
        if isinstance(typ, StructRef) and typ.name not in by_value:
            by_value.add(typ.name)
            record = records[typ.name]
            if record.is_union or any(field.is_bitfield for field in record.fields):
                raise ValueError(f"Unsupported by-value record: {typ.name}")
            for field in record.fields:
                visit(field.type)
        elif isinstance(typ, Array):
            visit(typ.element)
        elif isinstance(typ, FunctionPtr):
            visit(typ.ret)
            for param in typ.params:
                visit(param.type)

    for decl in unit.decls:
        if isinstance(decl, Function):
            visit(decl.ret)
            for param in decl.params:
                visit(param.type)
        for typ in iter_decl_types(decl):
            for node in iter_type_nodes(typ):
                if isinstance(node, FunctionPtr):
                    visit(node)

    def normalize(record):
        fields = []
        names = {field.name for field in record.fields}
        for field in record.fields:
            array = unwrap(field.type)
            if not isinstance(array, Array):
                fields.append(field)
                continue
            if not array.size or array.size_bytes % array.size:
                raise ValueError(f"Unsupported by-value array: {record.name}.{field.name}")
            stride = array.size_bytes // array.size
            for index in range(array.size):
                name = f"{field.name}_{index}"
                if name in names:
                    raise ValueError(f"Flattened field collision: {record.name}.{name}")
                fields.append(replace(field, name=name, source_name=name,
                                      type=array.element, size_bytes=stride,
                                      byte_offset=field.byte_offset + index * stride))
        return replace(record, fields=fields)

    return replace(unit, decls=[normalize(decl) if isinstance(decl, Struct) and decl.name in by_value
                               else decl for decl in unit.decls])
