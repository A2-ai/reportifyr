import os
import sys
from pathlib import Path

""" 
postprocess.py is run with `python postprocess.py input_file_path footnotes_path` 
"""
outputs_dir = None
user_footnotes_path = None
user_config_path = None

for line in open("_quarto.yml", "r"):
    if line.startswith("py-outputs:"):
        outputs_dir = line.split("py-outputs:")[1].strip()
    if line.startswith("footnotes-file:"):
        user_footnotes_path = line.split("footnotes-file:")[1].strip()
    if line.startswith("config-file:"):
        user_config_path = line.split("config-file:")[1].strip()

if outputs_dir is not None:
    if "" in outputs_dir:
        outputs_dir = outputs_dir.replace('"', "")

if user_footnotes_path is not None:
    if "" in user_footnotes_path:
        footnotes_path = user_footnotes_path.replace('"', "")

if user_config_path is not None:
    if "" in user_config_path:
        config_path = user_config_path.replace('"', "")

if outputs_dir is None:
    sys.exit("Please add py-outputs: path/to/json_outputs in _quarto.yml")

input_file_path = sys.argv[1]

footnotes_path = sys.argv[2]
if user_footnotes_path is not None:
    if Path(user_footnotes_path).exists():
        footnotes_path = user_footnotes_path

figure_path = os.path.join(outputs_dir, "figures")
tables_path = os.path.join(outputs_dir, "tables")

from add_figure_footnotes import add_figure_footnotes
from add_table_footnotes import add_table_footnotes

add_figure_footnotes(
    input_file_path, input_file_path, figure_path, footnotes_path, config_path
)
add_table_footnotes(
    input_file_path, input_file_path, tables_path, footnotes_path, config_path
)
