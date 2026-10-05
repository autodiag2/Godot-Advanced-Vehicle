# Running tests
from the repo root:

```bash
godot --headless \
	--path "$PWD" \
	-s addons/gut/gut_cmdln.gd \
	-gexit
```

## Only unit tests
```bash
godot --headless \
	--path "$PWD"
	-s addons/gut/gut_cmdln.gd \
	-gdir=res://test/unit \
	-gexit
```

## Only integration tests
same but res://test/integration
