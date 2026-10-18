#!/usr/bin/env python3
"""Regression checks for Cadius-formatted assembly template inputs."""
import unittest
from asm_transform import replace_once, replace_all, label_offset


class AssemblyTransformTest(unittest.TestCase):
    def test_columns_and_tabs(self):
        anchor = "core_variant              dc i2'0'"
        for source in [anchor, "core_variant\tdc\ti2'0'", "core_variant  dc     i2'0'"]:
            self.assertEqual(replace_once(source, anchor, 'exported'), 'exported')

    def test_multiline_trailing_spaces(self):
        source = 'entry\tlda\tvalue  \n\tsta   target\n'
        self.assertEqual(replace_once(source, 'entry lda value\n sta target', 'changed'), 'changed\n')

    def test_preserves_literal_spaces(self):
        source = "message\tdc\tc'one  two'\n"
        self.assertEqual(replace_once(source, "message dc c'one  two'", 'changed'), 'changed\n')
        with self.assertRaises(RuntimeError):
            replace_once(source, "message dc c'one two'", 'wrong')

    def test_missing_and_duplicate_fail(self):
        for source in [' lda different\n', ' lda value\n\tlda value\n']:
            with self.assertRaises(RuntimeError):
                replace_once(source, ' lda value', 'changed')

    def test_no_operand_prefix_or_comment_match(self):
        for source in [' lda value_extra\n', ' lda value+1\n', '; lda value\n']:
            with self.assertRaises(RuntimeError):
                replace_once(source, ' lda value', 'wrong')

    def test_column_zero_is_significant(self):
        with self.assertRaises(RuntimeError):
            replace_once(' lda value\n', 'lda value', 'wrong')
        with self.assertRaises(RuntimeError):
            replace_once('lda value\n', ' lda value', 'wrong')

    def test_label_and_counted_edits(self):
        source = '; entry\nentry\tanop\n\tjsr work\n jsr  work\n'
        self.assertEqual(label_offset(source, 'entry'), len('; entry\n'))
        self.assertEqual(replace_all(source, ' jsr work', ' jsr new', expected=2).count('jsr new'), 2)
        with self.assertRaises(RuntimeError):
            replace_all(source, ' jsr work', ' jsr new', expected=1)


if __name__ == '__main__':
    unittest.main()
