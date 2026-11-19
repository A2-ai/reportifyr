from reportipyr.magic import (
    build_magic_string,
    parse_magic_string,
    get_magic_pattern,
)


def test_parse_magic_string_single():
    result = parse_magic_string("{rpfy}:figure.png")
    assert result == {"figure.png": {}}


def test_parse_magic_string_multi_with_args():
    magic = "{rpfy}:[a.png<width: 4, height: 5>, b.png]"
    result = parse_magic_string(magic)
    assert result["a.png"]["width"] == "4"
    assert result["a.png"]["height"] == "5"
    assert result["b.png"] == {}


def test_parse_magic_string_whitespace_variations():
    magic = "{rpfy}:[ a.png<width:4 , height:5> ,b.png ]"
    result = parse_magic_string(magic)
    assert result["a.png"]["width"] == "4"
    assert result["a.png"]["height"] == "5"
    assert result["b.png"] == {}


def test_parse_magic_string_multi_no_args():
    magic = "{rpfy}:[a.png, b.png, c.png]"
    result = parse_magic_string(magic)
    assert result == {"a.png": {}, "b.png": {}, "c.png": {}}


def test_parse_magic_string_single_with_args_no_brackets():
    magic = "{rpfy}:a.png<width:4, height:5>"
    result = parse_magic_string(magic)
    assert result["a.png"]["width"] == "4"
    assert result["a.png"]["height"] == "5"


def test_parse_magic_string_mixed_extensions():
    magic = "{rpfy}:[a.png<width:4>, table.csv]"
    result = parse_magic_string(magic)
    assert result["a.png"]["width"] == "4"
    assert result["table.csv"] == {}


def test_magic_pattern_matches():
    pattern = get_magic_pattern()
    assert pattern.search("{rpfy}:table.csv") is not None


def test_build_magic_string_format():
    # Single entry: no brackets
    assert (
        build_magic_string({"a.png": {"width": "4.0", "height": "5.0"}})
        == "{rpfy}:a.png<width: 4.0, height: 5.0>"
    )
    # Empty args still emit an empty <>
    assert build_magic_string({"a.png": {}}) == "{rpfy}:a.png<>"
    # More than one entry: bracketed, joined with ", "
    assert (
        build_magic_string({"a.png": {"width": "4.0"}, "b.png": {}})
        == "{rpfy}:[a.png<width: 4.0>, b.png<>]"
    )


def test_build_magic_string_round_trips_through_parse():
    cases = [
        {"a.png": {"width": "4.0", "height": "5.0"}},
        {"a.png": {}},
        {"a.png": {"width": "4.0", "height": "5.0"}, "b.png": {"width": "2.0"}},
        {"a.png": {"width": "4.0"}, "b.png": {}, "table.csv": {}},
    ]
    for figure_args in cases:
        assert parse_magic_string(build_magic_string(figure_args)) == figure_args
