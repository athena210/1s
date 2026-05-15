#!/bin/sh -e

git ls-files -oi --exclude-standard -z |\
grep -zv \
    -e "^.trunk" \
    -e "^.vscode" \
    -e "^cloud_1s/images/server64_" \
    -e "^cloud_1s/images_backup/" \
    -e "secret.admin_password" |\
tar --null -T - -czf ignored_files.tgz



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
