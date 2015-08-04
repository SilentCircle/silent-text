#!/bin/bash
# vim: set filetype=sh syntax=sh et ts=4 sts=4 sw=4 si:

# This is to be invoked with the current default directory set to the Jenkins
# workspace, which contains the result of cloning the remote repository. Thus
# "tooling" must be a subdirectory of the current default directory.
#
# The source files intentionally exclude license and similar files that carry
# no real value as documentation.
#
# This builds a staging directory containing one level of subdirectories, each
# containing flattened filenames that are symlinks to the source text files.
# "tar h" is used to save the linked content rather than the links, thereby
# creating a level of indirection the script uses to rename hidden directories
# like .build_release to a name web servers are willing to expose.

set -e

tarball="SilentText-iOS-doc_$(date +'%Y%m%d%H%M%S').tar.gz"
SCRATCH=StageTextDocs.d
FILES_TO_PUBLISH=Documentation/TextFilesToPublish.txt

RepositoryURL=$(git config --get remote.origin.url)
RepositoryName=$(awk -F '[/.]' '{print $(NF-1)}' <<<$RepositoryURL)

rm -fr "$SCRATCH"
mkdir "$SCRATCH"

grep '^[^#]' $FILES_TO_PUBLISH |
while read path; do
    justfile=$(awk -F/ '{print $NF}' <<<$path)
    flatname=$(awk -F/ '{a=$2;  for (i=3; i<=NF; ++i){a=a "__" $i}; print a}' <<<$path)
    if [ -z "$flatname" ]
    then
        ln -s "../$path" "$SCRATCH/$justfile"
    else
        rawsub=$(awk -F/ '{print $1}' <<<$path)
        mysub=$(sed 's=^[.]==' <<<$rawsub)
        if [ ! -d "$SCRATCH/$mysub" ]
        then
            mkdir "$SCRATCH/$mysub"
            printf "# Documentation from %s directory of %s repository\n\n%s\n\n" \
                    "$rawsub" "$RepositoryName" \
                    '<!-- This index is auto-generated; edits will not persist. -->' \
            > "$SCRATCH/$mysub/index.md"
        fi
        location=$(awk -F/ '{for (i=NF-1;i>1;--i){a=a" in "$i}; print a}' <<<$path)
        ln -s "../../$path" "$SCRATCH/$mysub/$flatname"
        printf -- '- [%s](%s)%s\n' "$justfile" "$flatname" "$location" \
        >> "$SCRATCH/$mysub/index.md"
    fi
done

tar chzf "${tarball}" -C "$SCRATCH" .
