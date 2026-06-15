from std.memory import ArcPointer
from src._ffi import (
    CXIndex,
    CXTranslationUnit,
    clang_disposeIndex,
    clang_disposeTranslationUnit,
)


struct IndexState(Movable):
    """ARC pointee that owns a CXIndex.

    This should only be owned through ArcPointer[IndexState].
    Do not copy this type directly.
    """

    var _raw: CXIndex
    var alive: Bool

    def __init__(out self, raw: CXIndex):
        self._raw = raw
        self.alive = True

    def raw(self) raises -> CXIndex:
        if not self.alive:
            raise Error("IndexState used after disposal")
        return self._raw

    def __del__(deinit self):
        if self.alive:
            if self._raw:
                clang_disposeIndex(self._raw)


struct TranslationUnitState(Movable):
    """ARC pointee that owns a CXTranslationUnit.

    Holds ArcPointer[IndexState] so the index cannot be disposed before
    translation units created from it.
    """

    var _index: ArcPointer[IndexState]
    var _raw: CXTranslationUnit
    var alive: Bool
    var generation: Int

    def __init__(
        out self,
        index: ArcPointer[IndexState],
        raw: CXTranslationUnit,
    ):
        self._index = index
        self._raw = raw
        self.alive = True
        self.generation = 0

    def raw(self) raises -> CXTranslationUnit:
        if not self.alive:
            raise Error("TranslationUnit used after disposal")
        return self._raw

    def _raw_unchecked(self) -> CXTranslationUnit:
        """Return the raw handle without checking `alive`.

        Intended for iterator hot paths that have already validated the TU
        generation/state. Calling this on a disposed TU is unsafe.
        """
        return self._raw

    def bump_generation(mut self):
        self.generation += 1

    def __del__(deinit self):
        if self.alive:
            if self._raw:
                clang_disposeTranslationUnit(self._raw)
