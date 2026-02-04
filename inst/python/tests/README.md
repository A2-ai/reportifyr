# Python Tests (reportipyr)

This folder contains lightweight regression tests for the Python package in
`inst/python/reportipyr/`.

## Running the tests

From the repo root:

```
uv run -m pytest inst/python/tests
```

To run a single test file:

```
uv run -m pytest inst/python/tests/test_parse_magic_string.py
```

## Adding tests

- Test files should be named `test_<function-name>.py`.
- Prefer small, focused regression tests over broad integration tests.
- When using fixtures (e.g., `.docx`), place them in:

```
inst/python/tests/data/
```

Then load them in tests using:

```python
from pathlib import Path
DATA_DIR = Path(__file__).parent / "data"
path = DATA_DIR / "your-fixture.docx"
```

## Importing the package in tests

`conftest.py` inserts `inst/python` into `sys.path`, so tests can import
`reportipyr` without installing it.

## Notes

- These tests are designed to be fast and deterministic.
- Use `uv pip install pytest` if pytest is not installed in the venv.
