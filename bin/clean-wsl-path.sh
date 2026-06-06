_cleaned_path=""

_old_ifs="$IFS"
IFS=:

for _dir in $PATH; do
    case "$_dir" in
        *" "*)
            # Skip PATH entries that contain spaces.
            ;;
        "")
            # Skip empty PATH entries.
            ;;
        *)
            if [ -z "$_cleaned_path" ]; then
                _cleaned_path="$_dir"
            else
                _cleaned_path="$_cleaned_path:$_dir"
            fi
            ;;
    esac
done

IFS="$_old_ifs"

export PATH="$_cleaned_path"

unset _cleaned_path
unset _old_ifs
unset _dir
