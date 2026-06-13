"""`Type` — a wrapper around `CXType`.

Stored as `InlineArray[CXType, 1]` plus a borrowed `CXTranslationUnit` so the
TU is reachable for further pointer-based queries.
"""
from src.libclang_raw import (
    CXType,
    CXTypeKind,
    CXTranslationUnit,
    c_uint,
    c_int,
    c_long_long,
    clang_getTypeSpelling_ref,
    clang_getCanonicalType_into,
    clang_getPointeeType_into,
    clang_getUnqualifiedType_into,
    clang_getNonReferenceType_into,
    clang_getResultType_into,
    clang_getElementType_into,
    clang_getArrayElementType_into,
    clang_getArgType_into,
    clang_Type_getNamedType_into,
    clang_Type_getClassType_into,
    clang_Type_getTemplateArgumentAsType_into,
    clang_getTypeDeclaration_into,
    clang_getTypedefName_ref,
    clang_isPODType_ref,
    clang_isConstQualifiedType_ref,
    clang_isVolatileQualifiedType_ref,
    clang_isRestrictQualifiedType_ref,
    clang_isFunctionTypeVariadic_ref,
    clang_getAddressSpace_ref,
    clang_getFunctionTypeCallingConv_ref,
    clang_getExceptionSpecificationType_ref,
    clang_getNumArgTypes_ref,
    clang_Type_getNumTemplateArguments_ref,
    clang_Type_getSizeOf_ref,
    clang_Type_getAlignOf_ref,
    clang_Type_getOffsetOf_ref,
    clang_getArraySize_ref,
    clang_getNumElements_ref,
    clang_Type_getCXXRefQualifier_ref,
    clang_equalTypes_ref,
)
from src.libclang.common import take_cxstring, _c_string
from src.libclang.cursor import Cursor
from std.memory import UnsafePointer


@fieldwise_init
struct Type(Copyable, Movable):
    """A `CXType` borrowed from a `TranslationUnit`."""

    var _tu: CXTranslationUnit
    var _raw: InlineArray[CXType, 1]

    def __init__(out self, tu: CXTranslationUnit):
        self._tu = tu
        self._raw = InlineArray[CXType, 1](
            fill=CXType(
                kind=CXTypeKind(c_uint(0)),
                data0=None,
                data1=None,
            ),
        )

    def _ptr(mut self) -> UnsafePointer[CXType, MutExternalOrigin]:
        return rebind[UnsafePointer[CXType, MutExternalOrigin]](
            self._raw.unsafe_ptr(),
        )

    def kind(mut self) raises -> CXTypeKind:
        return self._raw[0].kind

    def spelling(mut self) raises -> String:
        return take_cxstring(clang_getTypeSpelling_ref(self._ptr()))

    def get_canonical(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getCanonicalType_into(out._ptr(), self._ptr())
        return out^

    def get_pointee(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getPointeeType_into(out._ptr(), self._ptr())
        return out^

    def get_unqualified(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getUnqualifiedType_into(out._ptr(), self._ptr())
        return out^

    def get_non_reference(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getNonReferenceType_into(out._ptr(), self._ptr())
        return out^

    def get_result(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getResultType_into(out._ptr(), self._ptr())
        return out^

    def element_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getElementType_into(out._ptr(), self._ptr())
        return out^

    def get_array_element_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getArrayElementType_into(out._ptr(), self._ptr())
        return out^

    def get_array_size(mut self) raises -> c_long_long:
        return clang_getArraySize_ref(self._ptr())

    def element_count(mut self) raises -> c_long_long:
        return clang_getNumElements_ref(self._ptr())

    def num_arg_types(mut self) raises -> c_int:
        return clang_getNumArgTypes_ref(self._ptr())

    def get_arg_type(mut self, i: c_uint) raises -> Type:
        var out = Type(tu=self._tu)
        clang_getArgType_into(out._ptr(), self._ptr(), i)
        return out^

    def argument_types(mut self) raises -> List[Type]:
        var n = self.num_arg_types()
        var out = List[Type]()
        for i in range(c_uint(n)):
            out.append(self.get_arg_type(c_uint(i)))
        return out^

    def num_template_args(mut self) raises -> c_int:
        return clang_Type_getNumTemplateArguments_ref(self._ptr())

    def get_template_argument_type(mut self, i: c_uint) raises -> Type:
        var out = Type(tu=self._tu)
        clang_Type_getTemplateArgumentAsType_into(out._ptr(), self._ptr(), i)
        return out^

    def get_declaration(mut self) raises -> Optional[Cursor]:
        var out = Cursor(tu=self._tu)
        clang_getTypeDeclaration_into(out._ptr(), self._ptr())
        if out.is_null():
            return None
        return out^

    def get_named_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_Type_getNamedType_into(out._ptr(), self._ptr())
        return out^

    def get_class_type(mut self) raises -> Type:
        var out = Type(tu=self._tu)
        clang_Type_getClassType_into(out._ptr(), self._ptr())
        return out^

    def get_offset(mut self, fieldname: String) raises -> c_long_long:
        return clang_Type_getOffsetOf_ref(self._ptr(), _c_string(fieldname))

    def get_align(mut self) raises -> c_long_long:
        return clang_Type_getAlignOf_ref(self._ptr())

    def get_size(mut self) raises -> c_long_long:
        return clang_Type_getSizeOf_ref(self._ptr())

    def get_ref_qualifier(mut self) raises -> c_uint:
        return c_uint(clang_Type_getCXXRefQualifier_ref(self._ptr()))

    def get_exception_specification_kind(mut self) raises -> c_int:
        return clang_getExceptionSpecificationType_ref(self._ptr())

    def get_calling_conv(mut self) raises -> c_uint:
        return c_uint(clang_getFunctionTypeCallingConv_ref(self._ptr()))

    def address_space(mut self) raises -> c_uint:
        return clang_getAddressSpace_ref(self._ptr())

    def typedef_name(mut self) raises -> String:
        return take_cxstring(clang_getTypedefName_ref(self._ptr()))

    def is_const_qualified(mut self) raises -> Bool:
        return Bool(clang_isConstQualifiedType_ref(self._ptr()))

    def is_volatile_qualified(mut self) raises -> Bool:
        return Bool(clang_isVolatileQualifiedType_ref(self._ptr()))

    def is_restrict_qualified(mut self) raises -> Bool:
        return Bool(clang_isRestrictQualifiedType_ref(self._ptr()))

    def is_function_variadic(mut self) raises -> Bool:
        return Bool(clang_isFunctionTypeVariadic_ref(self._ptr()))

    def is_pod(mut self) raises -> Bool:
        return Bool(clang_isPODType_ref(self._ptr()))

    def __eq__(mut self, mut other: Self) raises -> Bool:
        return Bool(clang_equalTypes_ref(self._ptr(), other._ptr()))
