"""Compilation database wrappers.

Mirrors the Python ``CompilationDatabase``, ``CompileCommands``, and
``CompileCommand`` classes.
"""

from src._ffi import (
    CXCompilationDatabase,
    CXCompileCommands,
    CXCompileCommand,
    CXCompilationDatabase_Error,
    c_uint,
    clang_CompilationDatabase_fromDirectory,
    clang_CompilationDatabase_dispose,
    clang_CompilationDatabase_getCompileCommands,
    clang_CompilationDatabase_getAllCompileCommands,
    clang_CompileCommands_dispose,
    clang_CompileCommands_getSize,
    clang_CompileCommands_getCommand,
    clang_CompileCommand_getDirectory,
    clang_CompileCommand_getFilename,
    clang_CompileCommand_getNumArgs,
    clang_CompileCommand_getArg,
    clang_CompileCommand_getNumMappedSources,
    clang_CompileCommand_getMappedSourcePath,
    clang_CompileCommand_getMappedSourceContent,
)

from src.libclang.common import _alloc_c_string, _c_string, _CXStringStorage
from src.libclang.enums import CompilationDatabaseErrorCode
from src.libclang.errors import CompilationDatabaseError

from std.iter import Iterable, Iterator, StopIteration
from std.memory import UnsafePointer, alloc, rebind


@fieldwise_init
struct CompileCommand(Copyable, Movable, Writable):
    """One compile command from a compilation database."""

    var _raw: CXCompileCommand

    def directory(ref self) raises -> String:
        var cs = _CXStringStorage()
        clang_CompileCommand_getDirectory(cs.ptr_for_out(), self._raw)
        return cs.take()

    def filename(ref self) raises -> String:
        var cs = _CXStringStorage()
        clang_CompileCommand_getFilename(cs.ptr_for_out(), self._raw)
        return cs.take()

    def num_args(ref self) -> c_uint:
        return clang_CompileCommand_getNumArgs(self._raw)

    def get_arg(ref self, i: c_uint) raises -> String:
        if i >= self.num_args():
            raise Error("CompileCommand arg index out of range")
        var cs = _CXStringStorage()
        clang_CompileCommand_getArg(cs.ptr_for_out(), self._raw, i)
        return cs.take()

    def arguments(ref self) raises -> List[String]:
        var n = Int(self.num_args())
        var out = List[String]()
        for i in range(n):
            out.append(self.get_arg(c_uint(i)))
        return out^

    def num_mapped_sources(ref self) -> c_uint:
        return clang_CompileCommand_getNumMappedSources(self._raw)

    def get_mapped_source_path(ref self, i: c_uint) raises -> String:
        if i >= self.num_mapped_sources():
            raise Error("CompileCommand mapped source index out of range")
        var cs = _CXStringStorage()
        clang_CompileCommand_getMappedSourcePath(cs.ptr_for_out(), self._raw, i)
        return cs.take()

    def get_mapped_source_content(ref self, i: c_uint) raises -> String:
        if i >= self.num_mapped_sources():
            raise Error("CompileCommand mapped source index out of range")
        var cs = _CXStringStorage()
        clang_CompileCommand_getMappedSourceContent(
            cs.ptr_for_out(), self._raw, i
        )
        return cs.take()

    def write_to(self, mut writer: Some[Writer]):
        try:
            writer.write("CompileCommand(", self.directory(), ": ", self.filename(), ")")
        except:
            writer.write("CompileCommand(<invalid>)")


struct CompileCommandsIterator[mut: Bool, //, origin: Origin[mut=mut]](
    Movable, Iterator
):
    """Iterator over commands in a ``CompileCommands`` collection."""

    comptime Element = CompileCommand

    var _raw: CXCompileCommands
    var _count: c_uint
    var _index: c_uint

    def __init__(out self, ref cmds: CompileCommands):
        self._raw = cmds._raw
        self._count = cmds._count
        self._index = c_uint(0)

    def __next__(mut self) raises StopIteration -> CompileCommand:
        if self._index >= self._count:
            raise StopIteration()
        var cmd = CompileCommand(
            clang_CompileCommands_getCommand(self._raw, self._index)
        )
        self._index += 1
        return cmd^


struct CompileCommands(Movable, Sized, Writable, Iterable):
    """A collection of ``CompileCommand`` values."""

    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = CompileCommandsIterator[mut=iterable_mut, origin=iterable_origin]

    var _raw: CXCompileCommands
    var _count: c_uint

    def __init__(out self, raw: CXCompileCommands):
        self._raw = raw
        if raw:
            self._count = clang_CompileCommands_getSize(raw)
        else:
            self._count = c_uint(0)

    def __del__(deinit self):
        if self._raw:
            try:
                clang_CompileCommands_dispose(self._raw)
            except:
                pass

    def __len__(self) -> Int:
        return Int(self._count)

    def __getitem__(ref self, i: c_uint) raises -> CompileCommand:
        if i >= self._count:
            raise Error("CompileCommands index out of range")
        return CompileCommand(clang_CompileCommands_getCommand(self._raw, i))

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return CompileCommandsIterator[origin_of(self)](self)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("CompileCommands(count=", Int(self._count), ")")


struct CompilationDatabase(Movable, Writable):
    """Wrapper around a ``compile_commands.json`` database."""

    var _raw: CXCompilationDatabase

    def __init__(out self, build_dir: String) raises:
        var dir_c = _alloc_c_string(build_dir)
        var err = InlineArray[CXCompilationDatabase_Error, 1](
            fill=CXCompilationDatabase_Error(c_uint(0))
        )

        var raw = clang_CompilationDatabase_fromDirectory(
            _c_string(dir_c),
            rebind[UnsafePointer[CXCompilationDatabase_Error, MutExternalOrigin]](
                err.unsafe_ptr()
            ),
        )

        dir_c.free()

        if not raw:
            raise CompilationDatabaseError(
                err[0],
                "could not load compilation database from " + build_dir,
            )

        self._raw = raw

    @staticmethod
    def from_directory(build_dir: String) raises -> Self:
        return Self(build_dir)

    def __del__(deinit self):
        if self._raw:
            try:
                clang_CompilationDatabase_dispose(self._raw)
            except:
                pass

    def get_compile_commands(ref self, filename: String) raises -> CompileCommands:
        var filename_c = _alloc_c_string(filename)
        var raw = clang_CompilationDatabase_getCompileCommands(
            self._raw,
            _c_string(filename_c),
        )
        filename_c.free()

        if not raw:
            raise Error(
                "CompilationDatabase: no compile commands for " + filename
            )

        return CompileCommands(raw)

    def get_all_compile_commands(ref self) raises -> CompileCommands:
        var raw = clang_CompilationDatabase_getAllCompileCommands(self._raw)
        if not raw:
            return CompileCommands(CXCompileCommands())
        return CompileCommands(raw)

    def write_to(self, mut writer: Some[Writer]):
        writer.write("CompilationDatabase()")
