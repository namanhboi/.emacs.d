"""Check that the optional news fetcher is harmless without Calibre."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "calibre_news", Path(__file__).resolve().parents[1] / "utils/fetch-calibre-news.py"
)
NEWS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NEWS)


class NewsPortabilityTests(unittest.TestCase):
    def test_missing_library_does_not_start_any_process(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(NEWS, "LIBRARY", root / "absent"), \
                 patch.object(NEWS, "STATE", root / "state"), \
                 patch.object(NEWS.sys, "argv", ["fetch-calibre-news.py"]), \
                 patch.object(NEWS.subprocess, "run") as run:
                self.assertEqual(NEWS.main(), 0)
                run.assert_not_called()
                self.assertFalse((root / "state").exists())

    def test_missing_tools_do_not_create_download_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "metadata.db").touch()
            with patch.object(NEWS, "LIBRARY", root), \
                 patch.object(NEWS, "STATE", root / "state"), \
                 patch.object(NEWS, "calibre_program", return_value=None), \
                 patch.object(NEWS.sys, "argv", ["fetch-calibre-news.py"]), \
                 patch.object(NEWS.subprocess, "run") as run:
                self.assertEqual(NEWS.main(), 0)
                run.assert_not_called()
                self.assertFalse((root / "state").exists())

    def test_recipes_follow_the_installed_calibre_location(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "builtin_recipes.zip"
            archive.touch()
            response = subprocess.CompletedProcess(
                [], 0, stdout=f"__RECIPES__={archive}\n", stderr=""
            )
            with patch.object(NEWS, "calibre_program", return_value="calibre-debug"), \
                 patch.object(NEWS.subprocess, "run", return_value=response):
                self.assertEqual(NEWS.calibre_recipe_archive(), archive)


if __name__ == "__main__":
    unittest.main()
