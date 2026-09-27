#!/usr/bin/env bash
# Lists tickets and their status. A "todo" ticket is READY when every ticket in its
# depends_on list is "done".
#   tools/tickets.sh            all tickets
#   tools/tickets.sh ready      only tickets a builder can start now
#   tools/tickets.sh review     only tickets with that status (todo, draft, review, ...)
cd "$(dirname "$0")/.."
field() { awk -v k="$1" 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} $0 ~ "^"k":" {sub("^"k":[ ]*",""); print; exit}' "$2"; }
status_of() { local f; f=$(ls tickets/"$1"-*.md 2>/dev/null | head -1); [ -n "$f" ] && field status "$f"; }
want="${1:-}"
for f in tickets/T-*.md; do
	[ -e "$f" ] || continue
	id=$(field id "$f"); status=$(field status "$f"); title=$(field title "$f")
	size=$(field size "$f"); owner=$(field owner "$f")
	deps=$(field depends_on "$f" | tr -d '[] ' | tr ',' ' ')
	ready=""
	if [ "$status" = "todo" ]; then
		ready="ready"
		for d in $deps; do
			[ "$(status_of "$d")" = "done" ] || { ready="waits:$d"; break; }
		done
	fi
	if [ -z "$want" ] || [ "$want" = "$status" ] || { [ "$want" = "ready" ] && [ "$ready" = "ready" ]; }; then
		printf "%-7s %-18s %-13s %-2s %-9s %s\n" "$id" "$status" "$ready" "$size" "$owner" "$title"
	fi
done
