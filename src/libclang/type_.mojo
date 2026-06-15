"""`Type` — a wrapper around `CXType`.

Stored as `InlineArray[CXType, 1]` plus a borrowed `CXTranslationUnit` so the
TU is reachable for further pointer-based queries.
"""
from src._ffi import (
    CXType,
    CXTypeKind,
    CXTranslationUnit,
    CXCursor_FieldDecl,
    CXType_Int,
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
    clang_getArraySize,
    clang_getNumElements,
    clang_Type_getCXXRefQualifier,
    clang_equalTypes,
)
from src.libclang.common import _CXStringStorage
from src.libclang.cursor import Cursor
from std.memory import UnsafePointer, MutOpaquePointer


@fieldwise_init
struct Type(Copyable, Movable, Writable):
    """A `CXType` borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXType, 1]
    var _spelling: String

    def __init__(out self, tu: CXTranslationUnit):
        self._tu = tu
        self._raw = InlineArray[CXType, 1](
            fill=CXType(
                kind=CXTypeKind(c_uint(0)),
                data=InlineArray[
                    Optional[MutOpaquePointer[MutExternalOrigin]], 2
                ](fill=None),
            ),
        )
        self._spelling = String()

    def _ptr(mut self) -> UnsafePointer[CXType, MutExternalOrigin]:
        return rebind[UnsafePointer[CXType, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def _cache_spelling(mut self) raises:
        var cs = _CXStringStorage()
        clang_getTypeSpelling(cs.ptr_for_out(), self._ptr())
        self._spelling = cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Type(", self._spelling, ")")

    def kind(mut self) raises -> CXTypeKind:
        return self._raw[0].kind

    def spelling(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getTypeSpelling(cs.ptr_for_out(), self._ptr())
        return cs.take()

    def get_canonical(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getCanonicalType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_pointee(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getPointeeType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_unqualified(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getUnqualifiedType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_non_reference(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getNonReferenceType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_result(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getResultType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def element_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getElementType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_array_element_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getArrayElementType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_array_size(mut self) raises -> c_long_long:
        return clang_getArraySize(self._ptr())

    def element_count(mut self) raises -> c_long_long:
        return clang_getNumElements(self._ptr())

    def num_arg_types(mut self) raises -> c_int:
        return clang_getNumArgTypes(self._ptr())

    def get_arg_type(mut self, i: c_uint) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getArgType(out._ptr(), self._ptr(), i)
        out._cache_spelling()
        return out^

    def argument_types(mut self) raises -> List[Type]:
        var n = self.num_arg_types()
        var out = List[Type]()
        for i in range(c_uint(n)):
            out.append(self.get_arg_type(c_uint(i)))
        return out^

    def num_template_args(mut self) raises -> c_int:
        return clang_Type_getNumTemplateArguments(self._ptr())

    def get_template_argument_type(mut self, i: c_uint) raises -> Type:
        var out = Type(tu=self._tu)
        clang_Type_getTemplateArgumentAsType(out._ptr(), self._ptr(), i)
        out._cache_spelling()
        return out^

    def get_declaration(mut self) raises -> Optional[Cursor]:
        var out = Cursor(tu=self._tu)
        clang_getTypeDeclaration(out._ptr(), self._ptr())
        out._cache_spelling()
        if out.is_null():
            return None
        return Optional[Cursor](out^)

    def get_named_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_Type_getNamedType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_class_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_Type_getClassType(out._ptr(), self._ptr())
        out._cache_spelling()
        return out^

    def get_offset(mut self, fieldname: String) raises -> c_long_long:
        var decl = self.get_declaration()
        if not decl:
            raise Error("Type.get_offset: type has no declaration")
        var cursor = decl.value().copy()
        var children = cursor.get_children()
        var offset_bytes = 0
        for i in range(Int(children.__len__())):
            var child = children[i].copy()
            if child.kind() != CXCursor_FieldDecl:
                continue
            var field_type = child.type()
            var align = Int(field_type.get_align())
            if align > 0 and offset_bytes % align != 0:
                offset_bytes += align - (offset_bytes % align)
            if child.spelling() == fieldname:
                return c_long_long(offset_bytes * 8)
            var size = Int(field_type.get_size())
            if size < 0:
                raise Error("Type.get_offset: field has unknown size")
            offset_bytes += size
        raise Error("Type.get_offset: field not found: " + fieldname)

    def get_align(mut self) raises -> c_long_long:
        return clang_Type_getAlignOf(self._ptr())

    def get_size(mut self) raises -> c_long_long:
        return clang_Type_getSizeOf(self._ptr())

    def get_ref_qualifier(mut self) raises -> c_uint:
        return c_uint(clang_Type_getCXXRefQualifier(self._ptr()))

    def get_exception_specification_kind(mut self) raises -> c_int:
        return clang_getExceptionSpecificationType(self._ptr())

    def get_calling_conv(mut self) raises -> c_uint:
        return c_uint(clang_getFunctionTypeCallingConv(self._ptr()))

    def address_space(mut self) raises -> c_uint:
        return clang_getAddressSpace(self._ptr())

    def typedef_name(mut self) raises -> String:
        var cs = _CXStringStorage()
        clang_getTypedefName(cs.ptr(), self._ptr())
        return cs.take()

    def is_const_qualified(mut self) raises -> Bool:
        return Bool(clang_isConstQualifiedType(self._ptr()))

    def is_volatile_qualified(mut self) raises -> Bool:
        return Bool(clang_isVolatileQualifiedType(self._ptr()))

    def is_restrict_qualified(mut self) raises -> Bool:
        return Bool(clang_isRestrictQualifiedType(self._ptr()))

    def is_function_variadic(mut self) raises -> Bool:
        return Bool(clang_isFunctionTypeVariadic(self._ptr()))

    def is_pod(mut self) raises -> Bool:
        return Bool(clang_isPODType(self._ptr()))

    def __eq__(mut self, mut other: Self) raises -> Bool:
        return Bool(clang_equalTypes(self._ptr(), other._ptr()))


