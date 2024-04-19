if gtest -n "${DEBUG:-}"; then
    set -x
fi

oops() {
    gecho "Error: $2"
    exit "$1"
}

print_usage() {
    gecho "Deploy and undeploy file trees via symlink or copy."
    gecho "Zero configuration."
    gecho
    gecho "Usage: $0 (ln | cp) SOURCE DESTINATION"
    gecho "       $0 rm SOURCE DESTINATION"
    gecho "       $0 ls SOURCE"
    gecho "       $0 check SOURCE DESTINATION"
    gecho "       $0 (help | -h | --help)"
    gecho
    gecho "See github:abstrnoah/emplacetree for details."
}

usage_error() {
    gecho "Error: Invalid usage"
    gecho
    print_usage
    exit 1
}

if gtest "$#" -lt 1; then
    usage_error
fi

fd_opts=(--unrestricted --follow)
# Assuming --follow, fd will report symlinks to regular files as regular files.
fd_type_leaf=(--type file)
# Assuming --follow, fd will report symlinks to directories as directories.
fd_type_dirlike=(--type directory)

our_fd() {
    fd "${fd_opts[@]}" "$@"
}

ls_leaves() {
    if gtest "$#" -ne 1; then
        usage_error
    fi
    local src_root="$1"
    our_fd "${fd_type_leaf[@]}" --base-directory "$src_root"
}

ls_dirlike() {
    if gtest "$#" -ne 1; then
        usage_error
    fi
    local src_root="$1"
    our_fd "${fd_type_dirlike[@]}" --base-directory "$src_root"
}

canonical_path() {
    greadlink -f "$1"
}

is_leaf() {
    gtest -f "$(canonical_path "$1")"
}

is_dirlike() {
    gtest -d "$(canonical_path "$1")"
}

is_dir() {
    # Apparently gtest -d returns true even if symlink to directory.
    # We realpath it because trailing paths fool test.
    gtest -d "$1" && ! gtest -L "$(grealpath -s "$1")"
}

equivalent() {
    gtest "$(canonical_path "$1")" = "$(canonical_path "$2")"
}

safety_checks() {
    if gtest "$#" -ne 2; then
        usage_error
    fi
    local src_root="$1"
    local dst_root="$2"

    if gtest -e "$src_root" && ! is_dirlike "$src_root"; then
        oops 4 "Source is not directory-like: $src_root"
    elif gtest -e "$dst_root" && ! is_dirlike "$dst_root"; then
        oops 4 "Destination is not directory-like: $dst_root"
    fi

    for node in $(ls_dirlike "$src_root"); do
        local dst_node="$dst_root/$node"
        if gtest -e "$dst_node" && ! is_dir "$dst_node"; then
            oops 3 "Destination of a directory-like source is not a directory: $node"
        fi
    done

    for node in $(ls_leaves "$src_root"); do
        local src_node="$src_root/$node"
        local dst_node="$dst_root/$node"
        if gtest -e "$dst_node" && ! equivalent "$src_node" "$dst_node" ; then
            oops 2 "Destination of a leaf is not equivalent to source: $node"
        fi
    done
}

make_dirs() {
    local src_root="$1"
    local dst_root="$2"

    for node in $(ls_dirlike "$src_root"); do
        local dst_node="$dst_root/$node"
        gmkdir -p "$dst_node"
    done
}

ln_leaves() {
    if gtest "$#" -ne 2; then
        usage_error
    fi
    local src_root="$1"
    local dst_root
    dst_root="$(greadlink -f "$2")"

    safety_checks "$src_root" "$dst_root"

    make_dirs "$1" "$2"

    our_fd "${fd_type_leaf[@]}" --base-directory "$src_root" \
        -x gln -sfT "$src_root"/{} "$dst_root"/{}
}

subcommand="$1"
shift

case "$subcommand" in
    help|-h|--help)
        print_usage
        ;;
    ln)
        ln_leaves "$@"
        ;;
    cp)
        oops 1 TODO
        ;;
    rm)
        oops 1 TODO
        ;;
    ls)
        ls_leaves "$@"
        ;;
    check)
        safety_checks "$@"
        ;;
    *)
        usage_error
        ;;
esac
