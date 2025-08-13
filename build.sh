
#!/bin/bash
pip install poetry
poetry install
poetry eval $(poetry env activate)

