"""Code completion wrappers.

`CodeCompletionResults` owns the result set returned by
``clang_codeCompleteAt``. Individual results expose their ``CompletionString``
and chunks.
"""

from src._ffi import (
    CXCodeCompleteResults,
    CXCompletionResult,
    CXCompletionString,
    CXCursorKind,
    c_uint,
    c_ulong_long,
    clang_codeCompleteAt,
    clang_codeCompleteGetContainerKind,
    clang_codeCompleteGetContainerUSR,
    clang_codeCompleteGetContexts,
    clang_codeCompleteGetDiagnostic,
    clang_codeCompleteGetNumDiagnostics,
    clang_codeCompleteGetObjCSelector,
    clang_disposeCodeCompleteResults,
    clang_getCompletionAnnotation,
    clang_getCompletionAvailability,
    clang_getCompletionBriefComment,
    clang_getCompletionChunkCompletionString,
    clang_getCompletionChunkKind,
    clang_getCompletionChunkText,
    clang_getCompletionNumAnnotations,
    clang_getCompletionNumChunks,
    clang_getCompletionPriority,
    clang_sortCodeCompletionResults,
)

from src.libclang.common import _CXStringStorage, _alloc_c_string, _c_string
from src.libclang.state import TranslationUnitState
from src.libclang.enums import (
    AvailabilityKind,
    CompletionChunkKind,
    CursorKind,
)

from std.iter import Iterable, Iterator, StopIteration
from std.memory import ArcPointer, UnsafePointer


@fieldwise_init
struct CompletionChunk(Copyable, Movable, Writable):
    """A single chunk inside a ``CompletionString``."""

    var _string: CXCompletionString
    var _index: c_uint

    def kind(ref self) -> CompletionChunkKind:
        return CompletionChunkKind(
            clang_getCompletionChunkKind(self._string, self._index)
        )

    def spelling(ref self) raises -> String:
        var cs = _CXStringStorage()
        clang_getCompletionChunkText(
            cs.ptr_for_out(), self._string, self._index
        )
        return cs.take()

    def string(ref self) -> Optional[CompletionString]:
        var nested = clang_getCompletionChunkCompletionString(
            self._string, self._index
        )
        if not nested:
            return None
        var s = CompletionString(nested)
        return Optional[CompletionString](s^)

    def is_kind_optional(ref self) -> Bool:
        return self.kind() == CompletionChunkKind.OPTIONAL

    def is_kind_typed_text(ref self) -> Bool:
        return self.kind() == CompletionChunkKind.TYPED_TEXT

    def is_kind_placeholder(ref self) -> Bool:
        return self.kind() == CompletionChunkKind.PLACEHOLDER

    def is_kind_informative(ref self) -> Bool:
        return self.kind() == CompletionChunkKind.INFORMATIVE

    def is_kind_result_type(ref self) -> Bool:
        return self.kind() == CompletionChunkKind.RESULT_TYPE

    def write_to(self, mut writer: Some[Writer]):
        try:
            writer.write(
                "CompletionChunk(", self.kind(), ": ", self.spelling(), ")"
            )
        except:
            writer.write("CompletionChunk(<invalid>)")


struct CompletionStringIterator[mut: Bool, //, origin: Origin[mut=mut]](
    Iterator, Movable
):
    """Iterator over chunks in a ``CompletionString``."""

    comptime Element = CompletionChunk

    var _string: CXCompletionString
    var _count: c_uint
    var _index: c_uint

    def __init__(out self, ref s: CompletionString):
        self._string = s._raw
        self._count = s.num_chunks()
        self._index = c_uint(0)

    def __next__(mut self) raises StopIteration -> CompletionChunk:
        if self._index >= self._count:
            raise StopIteration()
        var chunk = CompletionChunk(self._string, self._index)
        self._index += 1
        return chunk^


@fieldwise_init
struct CompletionString(Copyable, Iterable, Movable, Writable):
    """A libclang code-completion string."""

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = CompletionStringIterator[
        mut=iterable_mut, origin=iterable_origin
    ]

    var _raw: CXCompletionString

    def num_chunks(ref self) -> c_uint:
        return clang_getCompletionNumChunks(self._raw)

    def __len__(ref self) -> Int:
        return Int(self.num_chunks())

    def __getitem__(ref self, i: c_uint) raises -> CompletionChunk:
        if i >= self.num_chunks():
            raise Error("CompletionString index out of range")
        return CompletionChunk(self._raw, i)

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return CompletionStringIterator[origin_of(self)](self)

    def priority(ref self) -> c_uint:
        return clang_getCompletionPriority(self._raw)

    def availability(ref self) -> AvailabilityKind:
        return AvailabilityKind(
            c_uint(clang_getCompletionAvailability(self._raw))
        )

    def brief_comment(ref self) raises -> String:
        var cs = _CXStringStorage()
        clang_getCompletionBriefComment(cs.ptr_for_out(), self._raw)
        return cs.take()

    def num_annotations(ref self) -> c_uint:
        return clang_getCompletionNumAnnotations(self._raw)

    def annotation(ref self, i: c_uint) raises -> String:
        if i >= self.num_annotations():
            raise Error("CompletionString annotation index out of range")
        var cs = _CXStringStorage()
        clang_getCompletionAnnotation(cs.ptr_for_out(), self._raw, i)
        return cs.take()

    def write_to(self, mut writer: Some[Writer]):
        try:
            writer.write(
                "CompletionString(priority=", Int(self.priority()), ")"
            )
        except:
            writer.write("CompletionString(<invalid>)")


@fieldwise_init
struct CodeCompletionResult(Copyable, Movable, Writable):
    """One result inside a ``CodeCompletionResults`` set."""

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _cursor_kind: CXCursorKind
    var _string: CompletionString

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXCompletionResult,
    ):
        self._tu = tu
        self._generation = tu[].generation
        self._cursor_kind = raw.CursorKind
        self._string = CompletionString(raw.CompletionString)

    def kind(ref self) -> CursorKind:
        return CursorKind(self._cursor_kind)

    def string(ref self) -> CompletionString:
        return self._string.copy()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "CodeCompletionResult(kind=",
            Int(self._cursor_kind),
            ", ",
            self._string,
            ")",
        )


struct CodeCompletionResultsIterator[mut: Bool, //, origin: Origin[mut=mut]](
    Iterator, Movable
):
    """Iterator over results in a ``CodeCompletionResults`` set."""

    comptime Element = CodeCompletionResult

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _results: Optional[UnsafePointer[CXCompletionResult, MutExternalOrigin]]
    var _count: c_uint
    var _index: c_uint

    def __init__(out self, ref results: CodeCompletionResults):
        self._tu = results._tu
        self._generation = results._generation
        self._results = results._raw.Results
        self._count = results._raw.NumResults
        self._index = c_uint(0)

    def __next__(mut self) raises StopIteration -> CodeCompletionResult:
        if not self._tu[].alive or self._generation != self._tu[].generation:
            raise StopIteration()

        if self._index >= self._count:
            raise StopIteration()

        if not self._results:
            raise StopIteration()

        var raw = (self._results.value() + self._index)[].copy()
        self._index += 1
        return CodeCompletionResult(self._tu, raw)


struct CodeCompletionResults(Iterable, Movable, Sized, Writable):
    """Owns the result set returned by ``clang_codeCompleteAt``."""

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = CodeCompletionResultsIterator[
        mut=iterable_mut, origin=iterable_origin
    ]

    var _tu: ArcPointer[TranslationUnitState]
    var _generation: Int
    var _raw: CXCodeCompleteResults
    var _owns: Bool

    def __init__(
        out self,
        tu: ArcPointer[TranslationUnitState],
        raw: CXCodeCompleteResults,
    ):
        self._tu = tu
        self._generation = tu[].generation
        self._raw = raw
        self._owns = True

    def _check_valid(self) raises:
        if not self._tu[].alive:
            raise Error(
                "CodeCompletionResults used after TranslationUnit disposal"
            )

        if self._generation != self._tu[].generation:
            raise Error(
                "CodeCompletionResults used after TranslationUnit.reparse()"
            )

    def __del__(deinit self):
        if self._owns:
            if self._raw.Results:
                try:
                    clang_disposeCodeCompleteResults(
                        Optional[
                            UnsafePointer[
                                CXCodeCompleteResults, MutExternalOrigin
                            ]
                        ](
                            rebind[
                                UnsafePointer[
                                    CXCodeCompleteResults, MutExternalOrigin
                                ]
                            ](self._raw.unsafe_ptr())
                        )
                    )
                except:
                    pass

    def __len__(self) -> Int:
        return Int(self._raw.NumResults)

    def __getitem__(ref self, i: c_uint) raises -> CodeCompletionResult:
        self._check_valid()

        if i >= self._raw.NumResults:
            raise Error("CodeCompletionResults index out of range")

        if not self._raw.Results:
            raise Error("CodeCompletionResults has no result buffer")

        var raw = (self._raw.Results.value() + i)[].copy()
        return CodeCompletionResult(self._tu, raw)

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return CodeCompletionResultsIterator[origin_of(self)](self)

    def sort(mut self) raises:
        """Sort results by priority."""
        self._check_valid()
        if self._raw.Results and self._raw.NumResults > c_uint(0):
            clang_sortCodeCompletionResults(
                self._raw.Results.value(),
                self._raw.NumResults,
            )

    def num_diagnostics(ref self) raises -> c_uint:
        self._check_valid()
        return clang_codeCompleteGetNumDiagnostics(
            Optional[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                rebind[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                    self._raw.unsafe_ptr()
                )
            )
        )

    def diagnostic(ref self, i: c_uint) raises -> Diagnostic:
        from src.libclang.diagnostic import Diagnostic

        self._check_valid()

        if i >= self.num_diagnostics():
            raise Error("CodeCompletionResults diagnostic index out of range")

        var raw = clang_codeCompleteGetDiagnostic(
            Optional[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                rebind[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                    self._raw.unsafe_ptr()
                )
            ),
            i,
        )

        var d = Diagnostic(tu=self._tu, raw=raw, owns=True)
        d._cache_format()
        return d^

    def diagnostics(ref self) raises -> List[Diagnostic]:
        from src.libclang.diagnostic import Diagnostic

        self._check_valid()
        var n = Int(self.num_diagnostics())
        var out = List[Diagnostic]()
        for i in range(n):
            out.append(self.diagnostic(c_uint(i)))
        return out^

    def contexts(ref self) raises -> c_ulong_long:
        self._check_valid()
        return clang_codeCompleteGetContexts(
            Optional[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                rebind[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                    self._raw.unsafe_ptr()
                )
            )
        )

    def container_kind(ref self) raises -> Tuple[CursorKind, Bool]:
        """Return the container kind and whether it is incomplete."""
        self._check_valid()

        var incomplete = InlineArray[c_uint, 1](fill=c_uint(0))
        var kind = clang_codeCompleteGetContainerKind(
            Optional[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                rebind[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                    self._raw.unsafe_ptr()
                )
            ),
            rebind[UnsafePointer[c_uint, MutExternalOrigin]](
                incomplete.unsafe_ptr()
            ),
        )

        return (CursorKind(kind), Bool(incomplete[0]))

    def container_usr(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_codeCompleteGetContainerUSR(
            cs.ptr_for_out(),
            Optional[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                rebind[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                    self._raw.unsafe_ptr()
                )
            ),
        )
        return cs.take()

    def objc_selector(ref self) raises -> String:
        self._check_valid()
        var cs = _CXStringStorage()
        clang_codeCompleteGetObjCSelector(
            cs.ptr_for_out(),
            Optional[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                rebind[UnsafePointer[CXCodeCompleteResults, MutExternalOrigin]](
                    self._raw.unsafe_ptr()
                )
            ),
        )
        return cs.take()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "CodeCompletionResults(count=", Int(self._raw.NumResults), ")"
        )
