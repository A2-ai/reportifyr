from reportipyr.magic import parse_magic_string, get_magic_pattern


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
