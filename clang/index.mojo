"""`Index` — shared owner handle for a `CXIndex` and parser of translation units."""

from clang._ffi import (
    CXIndex,
    CXIndexOptions,
    CXTranslationUnit,
    clang_createIndex,
    clang_createIndexWithOptions,
    clang_parseTranslationUnit2,
    clang_createTranslationUnit2,
    clang_CXIndex_setGlobalOptions,
    clang_CXIndex_getGlobalOptions,
    clang_CXIndex_setInvocationEmissionPathOption,
    clang_defaultEditingTranslationUnitOptions,
    c_uint,
    c_int,
)

from clang.enums import ErrorCode, TranslationUnitFlags

from clang.common import (
    UnsavedFile,
    CStringArray,
    UnsavedFileArena,
    _c_string,
    _alloc_c_string,
)

from clang.errors import TranslationUnitLoadError
from clang.state import IndexState
from clang.translation_unit import TranslationUnit

from std.memory import UnsafePointer, ArcPointer


struct Index(Copyable, Movable, Writable):
    """Shared owner handle for a `CXIndex`.

    ```
    The actual `CXIndex` is owned by `IndexState`, which is held behind
    `ArcPointer[IndexState]`.

    Translation units produced by this index receive a copy of `_state`, so
    the index cannot be disposed before the translation units created from it.
    """

    var _state: ArcPointer[IndexState]
    var _exclude_decls: Bool
    var _display_diagnostics: Bool

    def __init__(
        out self,
        exclude_decls: Bool = False,
        display_diagnostics: Bool = False,
    ) raises:
        var raw = clang_createIndex(
            c_int(1 if exclude_decls else 0),
            c_int(1 if display_diagnostics else 0),
        )

        if not raw:
            raise Error("IndexError: clang_createIndex returned null")

        self._state = ArcPointer(IndexState(raw))
        self._exclude_decls = exclude_decls
        self._display_diagnostics = display_diagnostics

    def __init__(out self, *, copy: Self):
        self._state = copy._state
        self._exclude_decls = copy._exclude_decls
        self._display_diagnostics = copy._display_diagnostics

    @staticmethod
    def create(
        exclude_decls: Bool = False,
        display_diagnostics: Bool = False,
    ) raises -> Self:
        return Self(exclude_decls, display_diagnostics)

    @staticmethod
    def create_with_options(raw_options: CXIndexOptions) raises -> Self:
        var options = raw_options.copy()
        var raw = clang_createIndexWithOptions(
            rebind[UnsafePointer[CXIndexOptions, ImmutUntrackedOrigin]](
                UnsafePointer[CXIndexOptions, MutAnyOrigin](to=options)
            )
        )
        if not raw:
            raise Error(
                "IndexError: clang_createIndexWithOptions returned null"
            )
        var out = Self(copy=Self())
        out._state = ArcPointer(IndexState(raw))
        out._exclude_decls = False
        out._display_diagnostics = False
        return out^

    def _shared_state(self) -> ArcPointer[IndexState]:
        """Return the shared index state.

        This is passed into `TranslationUnit`, so the translation unit keeps
        the index alive.
        """
        return self._state

    def _raw_handle(self) raises -> CXIndex:
        return self._state[].raw()

    def set_global_options(ref self, options: c_uint) raises:
        clang_CXIndex_setGlobalOptions(self._raw_handle(), options)

    def global_options(ref self) raises -> c_uint:
        return clang_CXIndex_getGlobalOptions(self._raw_handle())

    def set_invocation_emission_path(ref self, path: String) raises:
        var path_c = _alloc_c_string(path)
        clang_CXIndex_setInvocationEmissionPathOption(
            self._raw_handle(),
            _c_string(path_c),
        )
        path_c.free()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "Index(exclude_decls=",
            self._exclude_decls,
            ", display_diagnostics=",
            self._display_diagnostics,
            ")",
        )

    def default_editing_options(self) -> c_uint:
        """Return libclang's default editing translation-unit parse options."""
        return clang_defaultEditingTranslationUnitOptions()

    def parse(
        ref self,
        path: String,
        args: List[String] = List[String](),
        unsaved_files: List[UnsavedFile] = List[UnsavedFile](),
        options: TranslationUnitFlags = TranslationUnitFlags.NONE,
    ) raises -> TranslationUnit:
        """Parse a source file into a `TranslationUnit`.

        `CStringArray` and `UnsavedFileArena` keep command-line argument
        strings and unsaved-file strings alive until the libclang call returns.
        """
        var arg_arena = CStringArray(args)
        var unsaved_arena = UnsavedFileArena(unsaved_files)

        var out_tu: CXTranslationUnit = CXTranslationUnit()
        var out_ptr = UnsafePointer[CXTranslationUnit, MutAnyOrigin](
            to=out_tu,
        )
        var path_c = _alloc_c_string(path)

        var raw_err = clang_parseTranslationUnit2(
            self._raw_handle(),
            _c_string(path_c),
            arg_arena.ptr(),
            arg_arena.count(),
            unsaved_arena.ptr(),
            unsaved_arena.count(),
            options.as_c_uint(),
            rebind[UnsafePointer[CXTranslationUnit, MutUntrackedOrigin]](
                out_ptr,
            ),
        )

        path_c.free()

        var err = ErrorCode(raw_err)
        if err != ErrorCode.SUCCESS:
            raise TranslationUnitLoadError(
                "parse failed: error code=" + String(Int(err.as_c_uint())),
            )

        return TranslationUnit(self._shared_state(), out_tu)

    def read(ref self, path: String) raises -> TranslationUnit:
        """Read a serialized AST file into a `TranslationUnit`."""
        var path_c = _alloc_c_string(path)

        var out_tu: CXTranslationUnit = CXTranslationUnit()
        var out_ptr = UnsafePointer[CXTranslationUnit, MutAnyOrigin](
            to=out_tu,
        )

        var err = ErrorCode(
            clang_createTranslationUnit2(
                self._raw_handle(),
                _c_string(path_c),
                rebind[UnsafePointer[CXTranslationUnit, MutUntrackedOrigin]](
                    out_ptr,
                ),
            )
        )

        path_c.free()

        if err != ErrorCode.SUCCESS:
            raise TranslationUnitLoadError(
                "read failed: error code=" + String(Int(err.as_c_uint())),
            )

        return TranslationUnit(self._shared_state(), out_tu)


def _check_index_alive(state: ArcPointer[IndexState]) raises:
    if not state[].alive:
        raise Error("Index used after disposal")


def _index_raw(state: ArcPointer[IndexState]) raises -> CXIndex:
    _check_index_alive(state)
    return state[].raw()
