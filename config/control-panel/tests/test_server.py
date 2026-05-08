import json
import threading
import urllib.error
import urllib.request
from pathlib import Path

import pytest

from server import build_server


@pytest.fixture
def server(tmp_path):
    """Boot a server with a temp web/ and handlers/ dir on an ephemeral port."""
    web = tmp_path / "web"
    web.mkdir()
    (web / "index.html").write_text("<html>hi</html>")
    (web / "panels").mkdir()

    handlers_dir = tmp_path / "handlers"
    handlers_dir.mkdir()
    (handlers_dir / "__init__.py").write_text("")
    (handlers_dir / "ping.py").write_text(
        "def handle(method, subpath, body):\n"
        "    return 200, {'pong': subpath, 'method': method}\n"
    )

    httpd = build_server(host="127.0.0.1", port=0, web_dir=web,
                         handlers_dir=handlers_dir)
    port = httpd.server_address[1]
    t = threading.Thread(target=httpd.serve_forever, daemon=True)
    t.start()
    yield f"http://127.0.0.1:{port}"
    httpd.shutdown()
    httpd.server_close()


def _get(url):
    with urllib.request.urlopen(url) as resp:
        return resp.status, json.loads(resp.read())


def test_serves_index(server):
    with urllib.request.urlopen(server + "/") as resp:
        assert resp.status == 200
        assert b"hi" in resp.read()


def test_panels_endpoint_lists_handler(server):
    status, body = _get(server + "/api/_panels")
    assert status == 200
    assert any(p["id"] == "ping" for p in body)


def test_dispatches_to_handler(server):
    status, body = _get(server + "/api/ping/foo/bar")
    assert status == 200
    assert body == {"pong": "foo/bar", "method": "GET"}


def test_unknown_panel_returns_404(server):
    with pytest.raises(urllib.error.HTTPError) as exc:
        _get(server + "/api/nope/x")
    assert exc.value.code == 404
