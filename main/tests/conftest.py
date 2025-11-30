import pytest


def pytest_addoption(parser):
    parser.addoption(
        "--skip-slow",
        action="store_true",
        default=False,
        help="Skip tests marked as slow",
    )


def pytest_configure(config):
    config.addinivalue_line("markers", "slow: mark test as slow to run")


def pytest_collection_modifyitems(config, items):
    if config.getoption("--skip-slow"):
        skip_slow = pytest.mark.skip(reason="Skipped due to --skip-slow flag")
        for item in items:
            if "slow" in item.keywords:
                item.add_marker(skip_slow)
