"""`Index` — shared owner handle for a `CXIndex` and parser of translation units.

Typical usage:

```mojo
from clang.cindex import Index

def main() raises:
    var index = Index()
    var tu = index.parse("test/fixtures/test_fixture.c")
    print(tu.spelling())
```
"""

from std.ffi import c_char

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
    UnsavedFileArena,
    _borrow_c_string,
    _alloc_c_string,
    _c_string,
)

from clang.errors import TranslationUnitLoadError
from clang.state import IndexState
from clang.translation_unit import TranslationUnit

from std.collections import List
from std.memory import UnsafePointer, ArcPointer, alloc
from std.memory.unsafe_pointer import unsafe_cast


struct Index(Copyable, Movable, Writable):
    """Shared owner handle for a `CXIndex`.

    The actual `CXIndex` is owned by `IndexState`, which is held behind
    `ArcPointer[IndexState]`.

    Translation units produced by this index receive a copy of `_state`, so
    the index cannot be disposed before the translation units created from it.

    Example:

    ```mojo
    var index = Index()
    var tu = index.parse("test/fixtures/test_fixture.c")
    print(len(tu))
    ```
    """

    var _state: ArcPointer[IndexState]
    var _exclude_decls: Bool
    var _display_diagnostics: Bool

    def __init__(
        out self,
        exclude_decls: Bool = False,
        display_diagnostics: Bool = False,
    ) raises:
        """Create a libclang index with Python-binding compatible options."""
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
        """Create an `Index` with the default libclang constructor."""
        return Self(exclude_decls, display_diagnostics)

    @staticmethod
    def create_with_options(raw_options: CXIndexOptions) raises -> Self:
        """Create an `Index` from a raw `CXIndexOptions` value."""
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

    def set_global_options(ref self, options: Int) raises:
        """Set libclang global options for this index."""
        if options < 0:
            raise Error("Index.set_global_options: options must be >= 0")
        clang_CXIndex_setGlobalOptions(self._raw_handle(), c_uint(options))

    def global_options(ref self) raises -> Int:
        """Return libclang global options for this index."""
        return Int(clang_CXIndex_getGlobalOptions(self._raw_handle()))

    def set_invocation_emission_path(ref self, path: String) raises:
        """Set the directory used for libclang invocation emission files."""
        clang_CXIndex_setInvocationEmissionPathOption(
            self._raw_handle(),
            _borrow_c_string(path),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "Index(exclude_decls=",
            self._exclude_decls,
            ", display_diagnostics=",
            self._display_diagnostics,
            ")",
        )

    def default_editing_options(self) -> TranslationUnitFlags:
        """Return libclang's default editing translation-unit parse options."""
        return TranslationUnitFlags(clang_defaultEditingTranslationUnitOptions())

    def parse(
        ref self,
        path: String,
        args: List[String] = List[String](),
        unsaved_files: List[UnsavedFile] = List[UnsavedFile](),
        options: TranslationUnitFlags = TranslationUnitFlags.NONE,
    ) raises -> TranslationUnit:
        """Parse a source file into a `TranslationUnit`.

        `UnsavedFileArena` keeps unsaved-file strings alive until the call
        returns. argv strings and slot buffer are allocated and freed inline.

        Note: Manual argv build avoids a Mojo compiler bug where
        Optional[UnsafePointer[...]] values produced across a function
        boundary are corrupted when passed to _bindgen_function wrappers
        with many parameters.
        """
        var unsaved_arena = UnsavedFileArena(unsaved_files)

        var n = len(args)
        var c_strings = List[UnsafePointer[c_char, MutAnyOrigin]]()
        var argv_buf: Optional[
            UnsafePointer[
                UnsafePointer[c_char, ImmutUntrackedOrigin],
                MutAnyOrigin,
            ]
        ] = None
        if n > 0:
            var raw = alloc[
                UnsafePointer[c_char, ImmutUntrackedOrigin]
            ](n)
            argv_buf = raw
            for i in range(n):
                var s = _alloc_c_string(args[i])
                c_strings.append(s)
                raw[i] = _c_string(s)

        var out_tu: CXTranslationUnit = CXTranslationUnit()
        var out_ptr = UnsafePointer[CXTranslationUnit, MutAnyOrigin](
            to=out_tu,
        )

        var c_path = _borrow_c_string(path)
        var arg_ptr: Optional[
            UnsafePointer[
                Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]],
                ImmutUntrackedOrigin,
            ]
        ] = unsafe_cast[
            Type=Optional[UnsafePointer[c_char, ImmutUntrackedOrigin]],
            origin=ImmutUntrackedOrigin,
        ](argv_buf)
        var arg_count = c_int(n)
        var unsaved_ptr = unsaved_arena.ptr()
        var unsaved_count = unsaved_arena.count()
        var raw_opts = options.as_c_uint()
        var out_raw = rebind[
            UnsafePointer[CXTranslationUnit, MutUntrackedOrigin]
        ](out_ptr)
        var raw_err = clang_parseTranslationUnit2(
            self._raw_handle(),
            c_path,
            arg_ptr,
            arg_count,
            unsaved_ptr,
            unsaved_count,
            raw_opts,
            out_raw,
        )

        for i in range(len(c_strings)):
            c_strings[i].free()
        if n > 0:
            argv_buf.value().free()

        var err = ErrorCode(raw_err)
        if err != ErrorCode.SUCCESS:
            raise TranslationUnitLoadError(
                "parse failed: error code=" + String(Int(err.as_c_uint())),
            )

        return TranslationUnit(self._shared_state(), out_tu)

    def read(ref self, path: String) raises -> TranslationUnit:
        """Read a serialized AST file into a `TranslationUnit`."""
        var out_tu: CXTranslationUnit = CXTranslationUnit()
        var out_ptr = UnsafePointer[CXTranslationUnit, MutAnyOrigin](
            to=out_tu,
        )

        var err = ErrorCode(
            clang_createTranslationUnit2(
                self._raw_handle(),
                _borrow_c_string(path),
                rebind[UnsafePointer[CXTranslationUnit, MutUntrackedOrigin]](
                    out_ptr,
                ),
            )
        )

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
