"""File inclusion description returned by ``TranslationUnit.get_includes``."""

from src.libclang.source_location import SourceLocation
from src.libclang.file import File


@fieldwise_init
struct FileInclusion(Copyable, Movable, Writable):
    """Describes one inclusion relationship in a translation unit."""

    var source: File
    var included: File
    var location: SourceLocation
    var depth: Int

    def is_input_file(ref self) raises -> Bool:
        """True if this is the top-level input file (depth 0)."""
        return self.depth == 0

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "FileInclusion(",
            self.source,
            " -> ",
            self.included,
            " at ",
            self.location,
            ", depth=",
            self.depth,
            ")",
        )
