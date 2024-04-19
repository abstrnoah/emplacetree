if gtest -n "${DEBUG:-}"; then
    set -x
fi

oops() {
    gecho -e "Error: $2"
    exit "$1"
}

print_usage() {
    gecho "Deploy and undeploy file trees via symlink or copy."
    gecho "Zero configuration."
    gecho
    gecho "Usage: $0 (ln | cp) SOURCE DESTINATION"
    gecho "       $0 rm SOURCE DESTINATION"
    gecho "       $0 ls SOURCE"
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
# fd_type_dirlike=(--type directory)

our_fd() {
    fd "${fd_opts[@]}" "$@"
}

subcommand_ls() {
    if gtest "$#" -ne 1; then
        usage_error
    fi
    local source_root="$1"
    our_fd "${fd_type_leaf[@]}" --base-directory "$source_root"
}

subcommand="$1"
shift

case "$subcommand" in
    help|-h|--help)
        print_usage
        ;;
    ln)
        oops 1 TODO
        ;;
    cp)
        oops 1 TODO
        ;;
    rm)
        oops 1 TODO
        ;;
    ls)
        subcommand_ls "$@"
        ;;
    *)
        usage_error
        ;;
esac
