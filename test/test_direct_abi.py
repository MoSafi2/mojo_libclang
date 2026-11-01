"""Regression checks for the layout-only transformation, using parsed C facts."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.direct_abi import normalize_direct_abi
from mojo_bindgen.ir import Function, Struct
from mojo_bindgen.orchestrator import BindgenOptions, BindgenOrchestrator


class DirectABITests(unittest.TestCase):
    def parse(self, source):
        with tempfile.TemporaryDirectory() as directory:
            header = Path(directory) / "api.h"
            header.write_text(source)
            return BindgenOrchestrator(BindgenOptions(header=header, library="oracle", link_name="oracle")).parse()

    def test_flattening_preserves_layout_signatures_and_original(self):
        original = self.parse("typedef struct { const void *data[3]; unsigned kind; } Value; Value call(Value);")
        before = original.to_json()
        normalized = normalize_direct_abi(original)
        record = next(d for d in normalized.decls if isinstance(d, Struct))
        source = next(d for d in original.decls if isinstance(d, Struct))
        stride = source.fields[0].size_bytes // 3
        self.assertEqual([f.name for f in record.fields], ["data_0", "data_1", "data_2", "kind"])
        self.assertEqual([f.byte_offset for f in record.fields], [0, stride, 2 * stride, 3 * stride])
        self.assertEqual((record.size_bytes, record.align_bytes), (source.size_bytes, source.align_bytes))
        self.assertEqual([d for d in original.decls if isinstance(d, Function)],
                         [d for d in normalized.decls if isinstance(d, Function)])
        self.assertEqual(original.to_json(), before)
        self.assertEqual(normalize_direct_abi(normalized).to_json(), normalized.to_json())

    def test_pointer_only_records_remain_unchanged(self):
        unit = self.parse("typedef struct { unsigned data[4]; } Value; void call(Value *);")
        self.assertEqual(normalize_direct_abi(unit).to_json(), unit.to_json())

    def test_callback_table_reaches_by_value_record(self):
        unit = self.parse("typedef struct { void *data[2]; } Value; typedef struct { void (*visit)(Value); } Callbacks; void call(Callbacks *);")
        result = normalize_direct_abi(unit)
        record = next(d for d in result.decls if isinstance(d, Struct) and len(d.fields) == 2)
        self.assertEqual([f.name for f in record.fields], ["data_0", "data_1"])

    def test_by_value_bitfields_are_rejected(self):
        unit = self.parse("typedef struct { unsigned flag:1; } Value; Value call(void);")
        with self.assertRaisesRegex(ValueError, "Unsupported by-value record"):
            normalize_direct_abi(unit)

    def test_flattened_name_collision_is_rejected(self):
        unit = self.parse("typedef struct { void *data[2]; void *data_0; } Value; Value call(void);")
        with self.assertRaisesRegex(ValueError, "Flattened field collision"):
            normalize_direct_abi(unit)


if __name__ == "__main__":
    unittest.main()
