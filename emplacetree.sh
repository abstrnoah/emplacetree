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


our_fd() {
    local src_root="$1"
    shift
    fd --unrestricted --follow --base-directory "$src_root" "$@"
}

ls_leaves() {
    local src_root="$1"
    shift
    # Assuming --follow, fd will report symlinks to regular files as regular files.
    our_fd "$src_root" --type file "$@"
}

ls_dirlike() {
    local src_root="$1"
    shift
    # Assuming --follow, fd will report symlinks to directories as directories.
    our_fd "$src_root" --type directory "$@"
}

# Resolve all symlinks and report absolute path.
canonical_path() {
    grealpath -e "$1"
}

# Clean path (namely remove trailing slash and make absolute),
# but don't resolve symlinks.
clean_path() {
    grealpath -ms "$1"
}

is_leaf() {
    gtest -f "$(canonical_path "$1")"
}

is_dirlike() {
    gtest -d "$(canonical_path "$1")"
}

is_dir() {
    # Apparently gtest -d returns true even if symlink to directory.
    # Argument should be passed thru clean_path for correct behaviour.
    gtest -d "$1" && ! gtest -L "$1"
}

equivalent() {
    gtest "$(canonical_path "$1")" = "$(canonical_path "$2")" \
        || diff "$1" "$2" >/dev/null
}

safety_checks() {
    if gtest "$#" -ne 2; then
        usage_error
    fi
    local src_root
    local dst_root
    src_root="$(clean_path "$1")"
    dst_root="$(clean_path "$2")"

    if ! gtest -e "$src_root"; then
        oops 4 "Source does not exist: $src_root"
    elif ! is_dirlike "$src_root"; then
        oops 4 "Source is not directory-like: $src_root"
    elif gtest -e "$dst_root" && ! is_dirlike "$dst_root"; then
        oops 4 "Destination is not directory-like: $dst_root"
    fi

    for node in $(ls_dirlike "$src_root"); do
        local dst_node
        dst_node="$(clean_path "$dst_root/$node")"
        if gtest -e "$dst_node" && ! is_dir "$dst_node"; then
            oops 3 "Destination of a directory-like source is not a directory: $node"
        fi
    done

    for node in $(ls_leaves "$src_root"); do
        local dst_node
        local src_node
        dst_node="$(clean_path "$dst_root/$node")"
        src_node="$(clean_path "$src_root/$node")"
        if gtest -e "$dst_node" && ! equivalent "$src_node" "$dst_node" ; then
            oops 2 "Destination of a leaf is not equivalent to source: $node"
        fi
    done
}

make_dirs() {
    local src_root
    local dst_root
    src_root="$(clean_path "$1")"
    dst_root="$(clean_path "$2")"

    ls_dirlike "$src_root" -x gmkdir -p "$dst_root/{}"
}

emplace_leaves() {
    if gtest "$#" -ne 3; then
        usage_error
    fi
    local src_root
    local dst_root
    local emplacer
    src_root="$(clean_path "$1")"
    dst_root="$(clean_path "$2")"
    emplacer="$3"

    safety_checks "$src_root" "$dst_root"

    make_dirs "$src_root" "$dst_root"

    for node in $(ls_leaves "$src_root"); do
        "$emplacer" "$src_root" "$dst_root" "$node"
    done
}

ln_leaf() {
    local src_root="$1"
    local dst_root="$2"
    local node="$3"
    gln -sfT \
        "$(clean_path "$src_root/$node")" "$(clean_path "$dst_root/$node")"
}

ln_leaves() {
    emplace_leaves "$1" "$2" ln_leaf
}

cp_leaf() {
    local src_root="$1"
    local dst_root="$2"
    local node="$3"
    gcp -T --preserve=mode --remove-destination \
        "$(clean_path "$src_root/$node")" "$(clean_path "$dst_root/$node")"
}

cp_leaves() {
    emplace_leaves "$1" "$2" cp_leaf
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
        cp_leaves "$@"
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
