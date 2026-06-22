"""Source-to-source rewriting wrapper.

Mirrors the Python ``Rewriter`` class built on top of ``CXRewriter``.
"""

from clang._ffi import (
    CXRewriter,
    CXSourceLocation,
    CXSourceRange,
    clang_CXRewriter_create,
    clang_CXRewriter_dispose,
    clang_CXRewriter_insertTextBefore,
    clang_CXRewriter_replaceText,
    clang_CXRewriter_removeText,
    clang_CXRewriter_overwriteChangedFiles,
    clang_CXRewriter_writeMainFileToStdOut,
)

from clang.common import _borrow_c_string
from clang.state import TranslationUnitState
from clang.source_location import SourceLocation
from clang.source_range import SourceRange

from std.memory import ArcPointer, UnsafePointer


struct Rewriter(Movable, Writable):
    """Owning wrapper around ``CXRewriter``.

    Locations and ranges passed to this wrapper must belong to the same
    translation unit generation used to create the rewriter.
    """

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXRewriter

    def __init__(out self, tu: TranslationUnit) raises:
        """Create a rewriter for `tu`."""
        self._tu = tu._shared_state()
        self._generation = self._tu[].generation
        self._raw = clang_CXRewriter_create(self._tu[].raw())

        if not self._raw:
            raise Error("Rewriter: clang_CXRewriter_create returned null")

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
    ) raises:
        """Create a rewriter for a shared translation unit state."""
        self._tu = tu
        self._generation = tu[].generation
        self._raw = clang_CXRewriter_create(tu[].raw())

        if not self._raw:
            raise Error("Rewriter: clang_CXRewriter_create returned null")

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error("Rewriter used after TranslationUnit disposal")

        if self._generation != self._tu[].generation:
            raise Error("Rewriter used after TranslationUnit.reparse()")

    def __del__(deinit self):
        if self._raw:
            clang_CXRewriter_dispose(self._raw)

    def insert_text_before(
        ref self,
        loc: SourceLocation,
        text: String,
    ) raises:
        """Insert `text` before `loc`."""
        self._check_valid()
        var loc_copy = loc.copy()
        clang_CXRewriter_insertTextBefore(
            self._raw,
            rebind[UnsafePointer[CXSourceLocation, MutUntrackedOrigin]](
                loc_copy._raw.unsafe_ptr()
            ),
            _borrow_c_string(text),
        )

    def replace_text(
        ref self,
        extent: SourceRange,
        replacement: String,
    ) raises:
        """Replace `extent` with `replacement`."""
        self._check_valid()
        var extent_copy = extent.copy()
        clang_CXRewriter_replaceText(
            self._raw,
            rebind[UnsafePointer[CXSourceRange, MutUntrackedOrigin]](
                extent_copy._raw.unsafe_ptr()
            ),
            _borrow_c_string(replacement),
        )

    def remove_text(ref self, extent: SourceRange) raises:
        """Remove the text covered by `extent`."""
        self._check_valid()
        var extent_copy = extent.copy()
        clang_CXRewriter_removeText(
            self._raw,
            rebind[UnsafePointer[CXSourceRange, MutUntrackedOrigin]](
                extent_copy._raw.unsafe_ptr()
            ),
        )

    def overwrite_changed_files(ref self) raises -> Int:
        """Write changes back to disk and return libclang's status code."""
        self._check_valid()
        return Int(clang_CXRewriter_overwriteChangedFiles(self._raw))

    def write_main_file_to_stdout(ref self) raises:
        """Print the rewritten main file to standard output."""
        self._check_valid()
        clang_CXRewriter_writeMainFileToStdOut(self._raw)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("Rewriter()")
