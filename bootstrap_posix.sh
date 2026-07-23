#!/bin/sh

# Shared archive bootstrap for macOS, Linux, iSH, and a-Shell.
# The README entry command feeds this file to a real POSIX shell after installing
# missing iSH-only bootstrap dependencies.

bootstrap_error() {
	printf '%s\n' "Dotfiles bootstrap: $*" >&2
}

bootstrap_tmp_dir=''

# Called indirectly by the portable exit trap below.
# shellcheck disable=SC2329
bootstrap_cleanup() {
	if [ -n "$bootstrap_tmp_dir" ]; then
		rm -f "$bootstrap_tmp_dir/repository.tar.gz" 2>/dev/null || :
		rmdir "$bootstrap_tmp_dir" 2>/dev/null || :
	fi
}

trap 'bootstrap_cleanup' 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 131' 3
trap 'exit 143' 15

if [ -z "${HOME:-}" ]; then
	bootstrap_error 'HOME is not set.'
	exit 1
fi

case "${TERM_PROGRAM:-}:${APPNAME:-}" in
a-Shell:* | *:a-Shell | *:a-Shell-mini | *:a-Shell-*)
	dotfiles_dir=$HOME/Documents/.dotfiles
	;;
*)
	dotfiles_dir=$HOME/.dotfiles
	;;
esac

case "$dotfiles_dir" in
/*) ;;
*)
	bootstrap_error "Refusing non-absolute destination: $dotfiles_dir"
	exit 1
	;;
esac

for bootstrap_command in mkdir grep rm rmdir sh tar; do
	if ! command -v "$bootstrap_command" >/dev/null 2>&1; then
		bootstrap_error "Required command not found: $bootstrap_command"
		exit 1
	fi
done

if command -v curl >/dev/null 2>&1; then
	bootstrap_downloader=curl
elif command -v wget >/dev/null 2>&1; then
	bootstrap_downloader=wget
else
	bootstrap_error 'Install curl or wget first.'
	exit 1
fi

if ! mkdir -p "$dotfiles_dir"; then
	bootstrap_error "Could not create destination: $dotfiles_dir"
	exit 1
fi

bootstrap_tmp_base=$dotfiles_dir/.dotfiles-bootstrap.$$
bootstrap_tmp_candidate=$bootstrap_tmp_base
bootstrap_tmp_attempt=0

while ! (umask 077 && mkdir "$bootstrap_tmp_candidate") 2>/dev/null; do
	bootstrap_tmp_attempt=$((bootstrap_tmp_attempt + 1))
	if [ "$bootstrap_tmp_attempt" -gt 20 ]; then
		bootstrap_error "Could not create a private temporary directory below $dotfiles_dir."
		exit 1
	fi
	bootstrap_tmp_candidate=$bootstrap_tmp_base.$bootstrap_tmp_attempt
done

bootstrap_tmp_dir=$bootstrap_tmp_candidate
bootstrap_archive=$bootstrap_tmp_dir/repository.tar.gz
bootstrap_archive_url=https://github.com/WaterNS/.dotfiles/tarball/master

case "$bootstrap_downloader" in
curl)
	if ! curl -fsSL "$bootstrap_archive_url" -o "$bootstrap_archive"; then
		bootstrap_error 'Repository download failed.'
		exit 1
	fi
	;;
wget)
	if ! wget -qO "$bootstrap_archive" "$bootstrap_archive_url"; then
		bootstrap_error 'Repository download failed.'
		exit 1
	fi
	;;
esac

if [ ! -s "$bootstrap_archive" ]; then
	bootstrap_error 'Repository download was empty.'
	exit 1
fi

if ! tar -tzf "$bootstrap_archive" >/dev/null 2>&1; then
	bootstrap_error 'Downloaded repository archive is invalid.'
	exit 1
fi

if ! tar -tzf "$bootstrap_archive" | grep -q '^[^/]*/init_posix\.sh$'; then
	bootstrap_error 'Downloaded repository archive does not contain init_posix.sh.'
	exit 1
fi

if ! tar -xzf "$bootstrap_archive" -C "$dotfiles_dir" --strip-components 1; then
	bootstrap_error 'Could not extract the repository archive.'
	exit 1
fi

if [ ! -f "$dotfiles_dir/init_posix.sh" ]; then
	bootstrap_error "Missing initializer after extraction: $dotfiles_dir/init_posix.sh"
	exit 1
fi

sh "$dotfiles_dir/init_posix.sh" "$@"
bootstrap_status=$?
exit "$bootstrap_status"
