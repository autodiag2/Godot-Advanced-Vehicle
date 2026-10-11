gut_test() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: gut_test test_name [test_name ...]" >&2
        return 2
    fi

    local dir root=""
    dir="$(pwd -P)"

    # Find the Godot project root, even when called from a subdirectory.
    while :; do
        if [[ -d "$dir/test" && -f "$dir/addons/gut/gut_cmdln.gd" ]]; then
            root="$dir"
            break
        fi

        [[ "$dir" == "/" ]] && break
        dir="$(dirname "$dir")"
    done

    # Fall back to the Git root.
    if [[ -z "$root" ]]; then
        dir="$(git rev-parse --show-toplevel 2>/dev/null)" || {
            echo "Error: cannot locate the project root." >&2
            return 2
        }

        if [[ -d "$dir/test" && -f "$dir/addons/gut/gut_cmdln.gd" ]]; then
            root="$dir"
        fi
    fi

    if [[ -z "$root" ]]; then
        echo "Error: project root must contain test/ and addons/gut/gut_cmdln.gd." >&2
        return 2
    fi

    local godot_bin="${GODOT_BIN:-godot4}"
    local name file choice status=0
    local -a matches selected
    local chosen_files=()

    for name in "$@"; do
        # Accept valid GDScript method identifiers only.
        if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Invalid test method name: $name" >&2
            status=1
            continue
        fi

        matches=()

        # Search recursively and match the complete method name.
        while IFS= read -r -d '' file; do
            if grep -Eq "^[[:space:]]*func[[:space:]]+${name}[[:space:]]*\\(" "$file"; then
                matches+=("$file")
            fi
        done < <(find "$root/test" -type f -name '*.gd' -print0)

        if [[ ${#matches[@]} -eq 0 ]]; then
            echo "Test not found: $name"
            status=1
            continue
        fi

        choice=""

        if [[ ${#matches[@]} -eq 1 ]]; then
            choice="${matches[0]}"
        else
            echo
            echo "Multiple files contain '$name':"

            local i
            for i in "${!matches[@]}"; do
                printf '  %d) %s\n' "$((i + 1))" "${matches[$i]#"$root"/}"
            done

            while :; do
                read -r -p "Choose a file (1-${#matches[@]}): " answer
                if [[ "$answer" =~ ^[0-9]+$ ]] &&
                   (( answer >= 1 && answer <= ${#matches[@]} )); then
                    choice="${matches[$((answer - 1))]}"
                    break
                fi
                echo "Invalid selection."
            done
        fi

        chosen_files["$name"]="$choice"
    done

    # Run every selected method. GUT accepts one -gunit_test_name
    # filter per invocation, so each method gets its own invocation.
    for name in "$@"; do
        [[ -n "${chosen_files[$name]:-}" ]] || continue

        file="${chosen_files[$name]}"
        local rel="${file#"$root"/}"
        local resource="res://${rel}"

        echo
        echo "Running $name in $resource"

        (
            cd "$root" &&
            "$godot_bin" --path "$root" \
                -s addons/gut/gut_cmdln.gd \
                "-gtest=$resource" \
                "-gunit_test_name=$name" \
                -gexit
        ) || status=1
    done

    return "$status"
}

