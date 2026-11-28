# Sourced by each libVLC build: which of VLC's plugins are made from a GPL source file. Some of VLC 3's own modules are
# still GPL (Lua, the Real RTSP access, the Dolby Surround and mono channel mixers, the dummy interface, the exporters),
# and leaving out the GPL contribs does not leave them out.

# A file is GPL when it names the GPL and neither the LGPL nor the GNU Library GPL.
is_gpl() {
  [ -f "$1" ] && grep -q -E 'GNU General Public License|GNU GPL' "$1" && ! grep -q -E 'Lesser General Public|Library General Public|LGPL' "$1"
}

# sources_of <vlc source> <vlc build> <library.la>: the sources a library in modules/ is made from, its in-tree
# convenience libraries' included.
sources_of() {
  _vlc="$1" _build="$2"
  _canonical="$(echo "$3" | sed 's/[^a-zA-Z0-9_]/_/g')"
  _vars="$(make -s -C "$_build/modules" -f Makefile -f /dev/stdin print_sources <<MAKE
print_sources: ; @echo \$(${_canonical}_SOURCES) \$(nodist_${_canonical}_SOURCES) '|' \$(${_canonical}_LIBADD)
MAKE
)"
  for _source in ${_vars%%|*}; do
    echo "$_vlc/modules/$_source"
  done
  for _lib in ${_vars#*|}; do
    case "$_lib" in
      *.la) [ "$(basename "$_lib")" = "$_lib" ] && (sources_of "$_vlc" "$_build" "$_lib") ;;
    esac
  done
}

# gpl_sources_of <vlc source> <vlc build> <plugin>: the GPL files among a plugin's sources, named from the source folder.
gpl_sources_of() {
  for _file in $(sources_of "$1" "$2" "$3.la"); do
    is_gpl "$_file" && echo "${_file#"$1"/}"
  done
  true
}

# gpl_core_sources <vlc source>: the GPL files among libvlccore's and libvlc's own.
gpl_core_sources() {
  for _file in "$1"/src/*.c "$1"/src/*/*.c "$1"/lib/*.c; do
    is_gpl "$_file" && echo "${_file#"$1"/}"
  done
  true
}

# remove_gpl_plugins <vlc source> <vlc build> <plugins folder>: deletes the static plugins made from a GPL source,
# naming each, before they are linked into one library.
remove_gpl_plugins() {
  find "$3" -name 'lib*_plugin.a' | while read -r _plugin; do
    _gpl="$(gpl_sources_of "$1" "$2" "$(basename "$_plugin" .a)" | tr '\n' ' ')"
    if [ -n "$_gpl" ]; then
      echo "GPL, left out: $(basename "$_plugin" .a): $_gpl"
      rm "$_plugin"
    fi
  done
}
