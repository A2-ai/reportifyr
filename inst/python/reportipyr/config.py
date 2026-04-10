import yaml


def load_yaml(yaml_file: str) -> dict:
    """Load contents from a YAML file."""
    try:
        with open(yaml_file, "r") as y:
            return yaml.safe_load(y) or {}
    except FileNotFoundError as e:
        raise FileNotFoundError(f"YAML file not found: {yaml_file}") from e
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML in {yaml_file}: {e}") from e
