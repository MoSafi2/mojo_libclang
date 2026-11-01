"""`Type` — a wrapper around `CXType`.

A `Type` is a copied `CXType` value plus an ARC keepalive reference to the
owning `TranslationUnitState`.

Important:

* The raw `CXType` value is stored in `Array[CXType, 1]`.
* The owning translation unit is kept alive through `ArcPointer[TranslationUnitState]`.
* The type becomes stale after `TranslationUnit.reparse()` if the generation changes.
* FFI calls pass `CXType` values using the native C calling convention.

Typical usage:

```mojo
from clang.cindex import TranslationUnit

def main() raises:
    var tu = TranslationUnit.from_source("test/fixtures/test_fixture.c")
    var typ = tu.cursor().type()
    print(typ.kind(), typ.spelling())
```
"""

import clang.translation_unit as tu_module
import clang.cursor as cursor_types
import clang.enums as enums_types


from clang._ffi import (
    CXCursor,
    CXType,
    CXTypeKind,
    CXTypeNullabilityKind,
    c_char,
    c_uint,
    c_int,
    c_long_long,
    clang_getTypeSpelling,
    clang_getCanonicalType,
    clang_getPointeeType,
    clang_getUnqualifiedType,
    clang_getNonReferenceType,
    clang_getResultType,
    clang_getElementType,
    clang_getArrayElementType,
    clang_getArgType,
    clang_Type_getNamedType,
    clang_Type_getClassType,
    clang_Type_getTemplateArgumentAsType,
    clang_getTypeDeclaration,
    clang_getTypedefName,
    clang_isPODType,
    clang_isConstQualifiedType,
    clang_isVolatileQualifiedType,
    clang_isRestrictQualifiedType,
    clang_isFunctionTypeVariadic,
    clang_getAddressSpace,
    clang_getFunctionTypeCallingConv,
    clang_getExceptionSpecificationType,
    clang_getNumArgTypes,
    clang_Type_getNumTemplateArguments,
    clang_Type_getSizeOf,
    clang_Type_getAlignOf,
    clang_Type_getOffsetOf,
    clang_Type_getValueType,
    clang_getArraySize,
    clang_getNumElements,
    clang_Type_getCXXRefQualifier,
    clang_Type_getObjCEncoding,
    clang_Type_getObjCObjectBaseType,
    clang_Type_getNumObjCProtocolRefs,
    clang_Type_getObjCProtocolDecl,
    clang_Type_getNumObjCTypeArgs,
    clang_Type_getObjCTypeArg,
    clang_Type_isTransparentTagTypedef,
    clang_Type_getNullability,
    clang_Type_getModifiedType,
    CXFieldVisitor,
    CXClientData,
    CXVisit_Continue,
    clang_Type_visitFields,
    clang_equalTypes,
)

from clang.enums import (
    TypeKind,
    TypeNullabilityKind,
    RefQualifierKind,
    CallingConv,
    ExceptionSpecificationKind,
    CursorKind,
)
from clang.common import _CXStringStorage, _borrow_c_string
from clang.printing_policy import PrintingPolicy
from clang.state import TranslationUnitState

from std.memory.alloc import unsafe_alloc
from std.memory import ArcPointer, Pointer


@fieldwise_init
struct Type(Copyable, Movable, Writable):
    """A `CXType` borrowed from a `TranslationUnit`.

    This object keeps the underlying translation unit alive by storing
    `ArcPointer[TranslationUnitState]`.

    Example:

    ```mojo
    var typ = cursor.type()
    print(typ.spelling())
    print(typ.canonical().spelling())
    ```
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: Array[CXType, 1]
    var _spelling: String

    def __init__(out self, tu: tu_module.TranslationUnit) raises:
        """Create a null type tied to `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = Array[CXType, 1](
            fill=_zero_type(),
        )
        self._spelling = String()

    def __init__(
        out self,
        tu: tu_module.TranslationUnit,
        raw: CXType,
    ) raises:
        """Create a type wrapper from a copied raw type tied to `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = Array[CXType, 1](fill=raw)
        self._spelling = String()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ):
        """Create a null type tied to a shared translation-unit state."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = Array[CXType, 1](
            fill=_zero_type(),
        )
        self._spelling = String()

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXType,
    ):
        """Create a type wrapper from a copied raw type."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = Array[CXType, 1](fill=raw)
        self._spelling = String()

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("Type used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("Type used after TranslationUnit.reparse()")

    def _ptr[origin: Origin, //](ref[origin] self) -> Pointer[CXType, origin]:
        return Pointer(to=self._raw[0]).unsafe_origin_cast[origin]()

    def _cache_spelling(mut self) raises:
        self._check_valid()

        var cs = _CXStringStorage()
        (cs.ptr_for_out())[] = clang_getTypeSpelling((self._ptr())[])
        self._spelling = cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Type(", self._spelling, ")")

    def _raw_value(self) raises -> CXType:
        """Return a copied raw `CXType` value."""
        self._check_valid()
        return self._raw[0].copy()

    def kind(ref self) raises -> TypeKind:
        """Return the libclang type kind."""
        self._check_valid()
        return TypeKind(self._raw[0].kind)

    def spelling(ref self) raises -> String:
        """Return libclang's spelling for this type."""
        self._check_valid()

        var cs = _CXStringStorage()
        (cs.ptr_for_out())[] = clang_getTypeSpelling((self._ptr())[])
        return cs.take()

    def canonical(ref self) raises -> Type:
        """Return the canonical form of this type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getCanonicalType((self._ptr())[])
        out._cache_spelling()
        return out^

    def pointee(ref self) raises -> Type:
        """Return the pointee type of this type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getPointeeType((self._ptr())[])
        out._cache_spelling()
        return out^

    def unqualified(ref self) raises -> Type:
        """Return this type with top-level qualifiers removed."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getUnqualifiedType((self._ptr())[])
        out._cache_spelling()
        return out^

    def non_reference(ref self) raises -> Type:
        """Return this type with reference sugar removed."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getNonReferenceType((self._ptr())[])
        out._cache_spelling()
        return out^

    def result(ref self) raises -> Type:
        """Return the result type of a function type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getResultType((self._ptr())[])
        out._cache_spelling()
        return out^

    def element_type(ref self) raises -> Type:
        """Return the element type of a vector, array, or complex type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getElementType((self._ptr())[])
        out._cache_spelling()
        return out^

    def array_element_type(ref self) raises -> Type:
        """Return the element type of an array type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getArrayElementType((self._ptr())[])
        out._cache_spelling()
        return out^

    def array_size(ref self) raises -> Int:
        """Return the array size reported by libclang."""
        self._check_valid()
        return Int(clang_getArraySize((self._ptr())[]))

    def element_count(ref self) raises -> Int:
        """Return the number of elements reported by libclang."""
        self._check_valid()
        return Int(clang_getNumElements((self._ptr())[]))

    def num_arg_types(ref self) raises -> Int:
        """Return the number of function argument types."""
        self._check_valid()
        return Int(clang_getNumArgTypes((self._ptr())[]))

    def arg_type(ref self, i: Int) raises -> Type:
        """Return function argument type `i`."""
        self._check_valid()
        if i < 0:
            raise Error("Type.arg_type: index out of range")

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_getArgType((self._ptr())[], c_uint(i))
        out._cache_spelling()
        return out^

    def argument_types(ref self) raises -> List[Type]:
        """Return all function argument types."""
        self._check_valid()

        var n = self.num_arg_types()
        if n < 0:
            raise Error("Type.argument_types: type has no argument list")

        var out = List[Type]()
        for i in range(n):
            out.append(self.arg_type(i))

        return out^

    def num_template_args(ref self) raises -> Int:
        """Return the number of template type arguments."""
        self._check_valid()
        return Int(clang_Type_getNumTemplateArguments((self._ptr())[]))

    def template_argument_type(ref self, i: Int) raises -> Type:
        """Return template type argument `i`."""
        self._check_valid()
        if i < 0:
            raise Error("Type.template_argument_type: index out of range")

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_Type_getTemplateArgumentAsType(
            (self._ptr())[], c_uint(i)
        )
        out._cache_spelling()
        return out^

    def declaration(ref self) raises -> Optional[cursor_types.Cursor]:
        """Return the declaration cursor for this type, if any."""
        from clang.cursor import Cursor

        self._check_valid()

        var out = Cursor(tu=self._tu)
        (out._ptr())[] = clang_getTypeDeclaration((self._ptr())[])

        if out.is_null():
            return None

        return Optional[cursor_types.Cursor](out^)

    def named_type(ref self) raises -> Type:
        """Return the named type underlying a typedef or elaborated type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_Type_getNamedType((self._ptr())[])
        out._cache_spelling()
        return out^

    def class_type(ref self) raises -> Type:
        """Return the class type associated with a member pointer type."""
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_Type_getClassType((self._ptr())[])
        out._cache_spelling()
        return out^

    def value_type(ref self) raises -> Optional[Type]:
        """Return the modified value type for wrappers like ``_Atomic(T)``.

        Wraps ``clang_Type_getValueType``. Returns ``None`` when the type has
        no value type (the result is ``CXType_Invalid``).
        """
        self._check_valid()

        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_Type_getValueType((self._ptr())[])

        if out.kind() == TypeKind.INVALID:
            return None

        out._cache_spelling()
        return Optional[Type](out^)

    def modified_type(ref self) raises -> Optional[Type]:
        """Return the modified type for attributed-wrapper types, if any."""
        self._check_valid()
        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_Type_getModifiedType((self._ptr())[])
        if out.kind() == TypeKind.INVALID:
            return None
        out._cache_spelling()
        return Optional[Type](out^)

    def offset(ref self, var fieldname: String) raises -> Int:
        """Return field offset in bits.

        Wraps ``clang_Type_getOffsetOf``.
        """
        self._check_valid()

        var result = clang_Type_getOffsetOf(
            (self._ptr())[], _borrow_c_string(fieldname)
        )

        if result < c_long_long(0):
            raise Error(
                t"Type.offset: layout error "
                t"{Int(result)} for field '{fieldname}'"
            )

        return Int(result)

    def align(ref self) raises -> Int:
        """Return the alignment of this type in bytes."""
        self._check_valid()
        return Int(clang_Type_getAlignOf((self._ptr())[]))

    def size(ref self) raises -> Int:
        """Return the size of this type in bytes."""
        self._check_valid()
        return Int(clang_Type_getSizeOf((self._ptr())[]))

    def translation_unit(ref self) raises -> tu_module.TranslationUnit:
        """Return the TranslationUnit to which this type belongs."""
        from clang.translation_unit import TranslationUnit

        self._check_valid()
        return TranslationUnit(self._tu)

    def ref_qualifier(ref self) raises -> RefQualifierKind:
        """Return the C++ ref-qualifier kind for a function type."""
        self._check_valid()
        return RefQualifierKind(clang_Type_getCXXRefQualifier((self._ptr())[]))

    def exception_specification_kind(
        ref self,
    ) raises -> enums_types.ExceptionSpecificationKind:
        """Return the exception-specification kind for a function type."""
        self._check_valid()
        return ExceptionSpecificationKind(
            c_uint(clang_getExceptionSpecificationType((self._ptr())[])),
        )

    def calling_conv(ref self) raises -> CallingConv:
        """Return the calling convention for a function type."""
        self._check_valid()
        return CallingConv(clang_getFunctionTypeCallingConv((self._ptr())[]))

    def address_space(ref self) raises -> Int:
        """Return the address space number for this type."""
        self._check_valid()
        return Int(clang_getAddressSpace((self._ptr())[]))

    def nullability(ref self) raises -> TypeNullabilityKind:
        """Return the nullability annotation for this type."""
        self._check_valid()
        return TypeNullabilityKind(
            c_uint(clang_Type_getNullability((self._ptr())[]))
        )

    def typedef_name(ref self) raises -> String:
        """Return the typedef name for this type, if it is a typedef."""
        self._check_valid()

        var cs = _CXStringStorage()
        (cs.ptr_for_out())[] = clang_getTypedefName((self._ptr())[])
        return cs.take()

    def objc_encoding(ref self) raises -> String:
        """Return the Objective-C encoding for this type."""
        self._check_valid()
        var cs = _CXStringStorage()
        (cs.ptr_for_out())[] = clang_Type_getObjCEncoding((self._ptr())[])
        return cs.take()

    def is_const_qualified(ref self) raises -> Bool:
        """Return true if this type has a top-level `const` qualifier."""
        self._check_valid()
        return Bool(clang_isConstQualifiedType((self._ptr())[]))

    def is_volatile_qualified(ref self) raises -> Bool:
        """Return true if this type has a top-level `volatile` qualifier."""
        self._check_valid()
        return Bool(clang_isVolatileQualifiedType((self._ptr())[]))

    def is_restrict_qualified(ref self) raises -> Bool:
        """Return true if this type has a top-level `restrict` qualifier."""
        self._check_valid()
        return Bool(clang_isRestrictQualifiedType((self._ptr())[]))

    def is_function_variadic(ref self) raises -> Bool:
        """Return true if this is a variadic function type."""
        self._check_valid()
        return Bool(clang_isFunctionTypeVariadic((self._ptr())[]))

    def is_pod(ref self) raises -> Bool:
        """Return true if libclang classifies this type as POD."""
        self._check_valid()
        return Bool(clang_isPODType((self._ptr())[]))

    def is_transparent_tag_typedef(ref self) raises -> Bool:
        """Return true if this typedef is a transparent tag typedef."""
        self._check_valid()
        return Bool(clang_Type_isTransparentTagTypedef((self._ptr())[]))

    def fields(ref self) raises -> List[cursor_types.Cursor]:
        """Return field declaration cursors for this record type."""
        from clang.cursor import Cursor

        self._check_valid()
        var collector_box = unsafe_alloc[_TypeFieldCollector](1)
        collector_box.unsafe_write(
            _TypeFieldCollector(
                tu=self._tu,
                out=List[cursor_types.Cursor](),
            )
        )
        var client_data = CXClientData(
            rebind[OpaquePointer[mut=True, MutUntrackedOrigin]](
                rebind[Pointer[UInt8, MutUntrackedOrigin]](
                    rebind[Pointer[UInt8, MutUntrackedOrigin]](collector_box)
                )
            )
        )
        _ = clang_Type_visitFields(
            (self._ptr())[], _field_visitor_trampoline, client_data
        )
        var out = List[cursor_types.Cursor]()
        for i in range(len(collector_box[].out)):
            out.append(collector_box[].out[i].copy())
        collector_box.unsafe_free()
        return out^

    def objc_object_base_type(ref self) raises -> Optional[Type]:
        """Return the Objective-C object base type, if any."""
        self._check_valid()
        var out = Type(tu=self._tu)
        (out._ptr())[] = clang_Type_getObjCObjectBaseType((self._ptr())[])
        if out.kind() == TypeKind.INVALID:
            return None
        out._cache_spelling()
        return Optional[Type](out^)

    def objc_protocol_decls(ref self) raises -> List[cursor_types.Cursor]:
        """Return Objective-C protocol declaration cursors referenced by this type.
        """
        from clang.cursor import Cursor

        self._check_valid()
        var out = List[cursor_types.Cursor]()
        var count = clang_Type_getNumObjCProtocolRefs((self._ptr())[])
        for i in range(Int(count)):
            var cursor = cursor_types.Cursor(tu=self._tu)
            (cursor._ptr())[] = clang_Type_getObjCProtocolDecl(
                (self._ptr())[], c_uint(i)
            )
            if not cursor.is_null():
                out.append(cursor^)
        return out^

    def objc_type_args(ref self) raises -> List[Type]:
        """Return Objective-C type arguments referenced by this type."""
        self._check_valid()
        var out = List[Type]()
        var count = clang_Type_getNumObjCTypeArgs((self._ptr())[])
        for i in range(Int(count)):
            var typ = Type(tu=self._tu)
            (typ._ptr())[] = clang_Type_getObjCTypeArg(
                (self._ptr())[], c_uint(i)
            )
            if typ.kind() != TypeKind.INVALID:
                typ._cache_spelling()
                out.append(typ^)
        return out^

    def __eq__(ref self, ref other: Self) raises -> Bool:
        self._check_valid()
        other._check_valid()

        if self._generation != other._generation:
            return False

        if self._tu[].raw() != other._tu[].raw():
            return False

        return Bool(clang_equalTypes((self._ptr())[], (other._ptr())[]))

    def __ne__(ref self, ref other: Self) raises -> Bool:
        return not self.__eq__(other)


def _zero_type() -> CXType:
    return CXType(kind=CXTypeKind(c_uint(0)), data_0=None, data_1=None)


@fieldwise_init
struct _TypeFieldCollector(Movable):
    var tu: ArcPointer[TranslationUnitState]
    var out: List[cursor_types.Cursor]


def _field_visitor_trampoline(
    raw_cursor: CXCursor,
    client_data: CXClientData,
) abi("C") -> c_uint:
    var collector = rebind[Pointer[_TypeFieldCollector, MutUntrackedOrigin]](
        rebind[Pointer[UInt8, MutUntrackedOrigin]](
            rebind[Pointer[UInt8, MutUntrackedOrigin]](client_data.value())
        )
    )

    var cursor = cursor_types.Cursor(tu=collector[].tu, raw=raw_cursor.copy())
    collector[].out.append(cursor^)

    return CXVisit_Continue
