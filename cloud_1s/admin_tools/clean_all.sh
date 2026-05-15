#!/bin/sh

db_storage=/srv/1sdb1
updates_storage=/srv/1sadmin/1c8_templates/1c
user_admin=user1s

if \
    [ -z "$DIR_USER" ] || \
    [ -z "$DIR_GROUP" ] || \
    [ "$DIR_USER" != "$(id -u)" ] || \
    [ "$DIR_GROUP" != "$(id -g)" ]
then
    echo "Must be started from container."
    exit 1
fi


# databases sizes
print_db_sizes() {
    sortfile=$(mktemp)
    find "$db_storage" \
        -path "$db_storage/lost+found" -prune -o \
        -type f -iname "1cv8.1cd" -print | \
        sort | while read fname
    do
        du -xhd0 $(dirname "$fname") >> $sortfile
    done
    cat $sortfile | sort -h
    rm -f $sortfile
}


# search indexes
print_search_sizes() {
    sortfile=$(mktemp)
    and_delete="$1"
    find "$db_storage" \
        -path "$db_storage/lost+found" -prune -o \
        -type d -iname "1Cv8FTxt" -print | \
        sort | while read fname
    do
        du -xhd0 "$fname" >> $sortfile
        [ "$and_delete" = "and_delete" ] && rm -rf "$fname"
    done
    cat $sortfile | sort -h
    rm -f $sortfile
}


# 1c journals
print_journals() {
    sortfile=$(mktemp)
    and_delete="$1"
    find "$db_storage" \
        -path "$db_storage/lost+found" -prune -o \
        -type d -iname "1Cv8Log" -print | \
        sort | while read fname
    do
        du -xhd0 "$fname" >> $sortfile
        [ "$and_delete" = "and_delete" ] && rm -rf "$fname"
    done
    cat $sortfile | sort -h
    rm -f $sortfile
}


# old updates
clean_updates() {
    base_path="$updates_storage"
    storages="Accounting AccountingBase AccountingCorp hrm"
    for stor in $storages; do
        ls -1 "${base_path}/${stor}"|sort -h|head -n -10| while read dname; do
            echo   "${base_path}/${stor}/${dname}"
            rm -rf "${base_path}/${stor}/${dname}"
        done
    done
}

printf "\nsearch indexes:\n==============\n"
# print_search_sizes
print_search_sizes and_delete

printf "\njournals:\n==============\n"
# print_journals
print_journals and_delete

printf "\nupdates deleted:\n==============\n"
clean_updates

printf "\nclean home:\n==============\n"
rm -rf "/home/$user_admin/.1cv82/1C/1Cv82"
rm -rf "/home/$user_admin/.1cv8/1C/1cv8"

printf "\ndatabases:\n==============\n"
print_db_sizes
