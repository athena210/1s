#!/bin/sh -e

ignored_files_archive="ignored_files.tgz"

[ ! -f "$ignored_files_archive" ] || rm -f "$ignored_files_archive"

git ls-files -oi --exclude-standard -z |\
grep -zv \
    -e "^.trunk" \
    -e "^.vscode" \
    -e "^ignored_files" \
    -e "^cloud_1s/images/server64_" \
    -e "^cloud_1s/images_backup/" \
    -e "secret.admin_password" |\
tar --null -T - -czf "$ignored_files_archive"



# # shellcheck disable=SC2016
# git ls-files -oi --exclude-standard -z |\
# grep -zv \
#     -e "^.trunk" \
#     -e "^.vscode" \
#     -e "^cloud_1s/images/server64_" \
#     -e "^cloud_1s/images_backup/" \
#     -e "secret.admin_password" |\
# xargs -0 -I {} sh -c '
#     OBJ="{}"
#     echo "$OBJ"
# '
