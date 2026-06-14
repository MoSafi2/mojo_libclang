"""`Index` — owns a `CXIndex` and parses translation units."""
from src._ffi import (
    CXIndex,
    CXTranslationUnit,
    CXUnsavedFile,
    CXErrorCode,
    CXError_Success,
    clang_createIndex,
    clang_disposeIndex,
    clang_parseTranslationUnit2,
    clang_createTranslationUnit2,
    clang_defaultEditingTranslationUnitOptions,
    c_uint,
    c_int,
    c_ulong,
)
from src.libclang.support import UnsavedFile
from src.libclang.common import _c_string
from src.libclang.translation_unit import TranslationUnit
from std.memory import UnsafePointer
from std.ffi import c_char


struct Index(Writable):
    """Owns a `CXIndex` and produces `TranslationUnit` values."""

    var _raw: CXIndex
    var _exclude_decls: Bool
    var _display_diagnostics: Bool

    def __init__(
        out self,
        exclude_decls: Bool = False,
        display_diagnostics: Bool = False,
    ) raises:
        self._raw = clang_createIndex(
            c_int(1 if exclude_decls else 0),
            c_int(1 if display_diagnostics else 0),
        )
        self._exclude_decls = exclude_decls
        self._display_diagnostics = display_diagnostics

    @staticmethod
    def create(
        exclude_decls: Bool = False,
        display_diagnostics: Bool = False,
    ) raises -> Self:
        return Self(exclude_decls, display_diagnostics)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "Index(exclude_decls=", self._exclude_decls,
            ", display_diagnostics=", self._display_diagnostics, ")",
        )

    def __del__(deinit self):
        try:
            clang_disposeIndex(self._raw)
        except:
            pass

    def parse(
        mut self,
        path: String,
        args: List[String] = List[String](),
        unsaved_files: List[UnsavedFile] = List[UnsavedFile](),
        options: c_uint = 0,
    ) raises -> TranslationUnit:
        var arg_ptrs = _build_arg_ptrs(args)
        var unsaved = _build_unsaved_files(unsaved_files)
        var out_tu: CXTranslationUnit = CXTranslationUnit()
        var out_ptr = UnsafePointer[CXTranslationUnit, MutAnyOrigin](to=out_tu)
        var err = clang_parseTranslationUnit2(
            self._raw,
            _c_string(path),
            arg_ptrs[0],
            arg_ptrs[1],
            unsaved[0],
            unsaved[1],
            options,
            rebind[UnsafePointer[CXTranslationUnit, MutExternalOrigin]](out_ptr),
        )
        if err != CXError_Success:
            raise Error(
                "TranslationUnit parse failed: error code="
                + String(Int(err)),
            )
        return TranslationUnit(out_tu)

    def read(mut self, path: String) raises -> TranslationUnit:
        var out_tu: CXTranslationUnit = CXTranslationUnit()
        var out_ptr = UnsafePointer[CXTranslationUnit, MutAnyOrigin](to=out_tu)
        var err = clang_createTranslationUnit2(
            self._raw,
            _c_string(path),
            rebind[UnsafePointer[CXTranslationUnit, MutExternalOrigin]](out_ptr),
        )
        if err != CXError_Success:
            raise Error(
                "TranslationUnit read failed: error code="
                + String(Int(err)),
            )
        return TranslationUnit(out_tu)


def _build_arg_ptrs(
    args: List[String],
) -> Tuple[
    Optional[
        UnsafePointer[
            Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
            ImmutExternalOrigin,
        ]
    ],
    c_int,
]:
    if len(args) == 0:
        return (None, c_int(0))
    var slot = alloc[Optional[UnsafePointer[c_char, ImmutExternalOrigin]]](
        len(args),
    )
    for i in range(len(args)):
        slot[i] = Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
            _c_string(args[i]),
        )
    return (
        rebind[
            UnsafePointer[
                Optional[UnsafePointer[c_char, ImmutExternalOrigin]],
                ImmutExternalOrigin,
            ]
        ](slot),
        c_int(len(args)),
    )


def _build_unsaved_files(
    files: List[UnsavedFile],
) -> Tuple[Optional[UnsafePointer[CXUnsavedFile, MutExternalOrigin]], c_uint]:
    if len(files) == 0:
        return (None, c_uint(0))
    var slot = alloc[CXUnsavedFile](len(files))
    for i in range(len(files)):
        var f = files[i].copy()
        slot[i] = CXUnsavedFile(
            Filename=Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                _c_string(f.filename),
            ),
            Contents=Optional[UnsafePointer[c_char, ImmutExternalOrigin]](
                rebind[UnsafePointer[c_char, ImmutExternalOrigin]](
                    _c_string(f.contents),
                ),
            ),
            Length=c_ulong(f.contents.byte_length()),
        )
    return (slot, c_uint(len(files)))
