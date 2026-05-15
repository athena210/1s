#!/usr/bin/python3

import time
import os
import sys
import shutil
import datetime

import ntsecuritycon as con
import win32security
import win32api


sid_admin = None




def print_usage():
    print("USAGE:")
    print("command.py init /rootdir /aclroot")
    print("    Create structure of ACL tree.\n")
    print("command.py clean /rootdir1 [rootdir2 ...] /aclroot")
    print("    Vanish ACL bases if not-existet in roots.\n")
    print("command.py repair  /rootdir /aclroot")
    print("    Set all ACLs from ACL tree to 1s storage.\n")
    print("command.py setacl  /rootdir stor/database  /aclroot")
    print("    Set ACL to one database.\n")



def buildacltree(rootdir, aclroot):

    for db in getdblist(rootdir):
        os.makedirs(os.path.join(aclroot, db), exist_ok=True)
    return


def getconfig(fname):

    with open(fname, "r", encoding = 'utf-8-sig') as fh:
        lines = []
        for line in fh:
            line = line.strip()
            if (len(line) < 1) or (line[0] == "#") :
                continue
            lines += [line]
    return lines


def getdblist(rootdir):

    dblist = []
    if not os.path.isdir(rootdir):
        return dblist

    for storname in os.listdir(rootdir):
        stordir = os.path.join(rootdir, storname)
        if not os.path.isdir(stordir):
            continue

        for dbname in os.listdir(stordir):
            dbdir = os.path.join(stordir, dbname)
            if not os.path.isdir(dbdir):
                continue
            dblist += [os.path.join(storname, dbname)]

    return dblist


def cleanacltree(aclroot, dblist):

    acldblist = getdblist(aclroot)

    print("Cean manually:")
    for acldb in set(acldblist) - set(dblist):
        print(os.path.join(aclroot,acldb))

    return



def setacl(path, acls, inherited):
# path - path to dir/file
# acls - acl:perm list
# inherited - if take parent acls (1) or not (0)
# -------------
# empty acls and inherited=0 -> exit
# empty acls and inherited=1 -> default acls


    global sid_admin

    dacl = win32security.ACL()

    if inherited == 1:

        inherit_flags = win32security.UNPROTECTED_DACL_SECURITY_INFORMATION

        # First set default ACL with inheritance
        win32security.SetNamedSecurityInfo( \
            path \
            ,win32security.SE_FILE_OBJECT \
            ,win32security.DACL_SECURITY_INFORMATION | inherit_flags | win32security.OWNER_SECURITY_INFORMATION \
            ,sid_admin,None,dacl,None)

        # then read ACL
        sd = win32security.GetNamedSecurityInfo( \
            path \
            ,win32security.SE_FILE_OBJECT \
            ,win32security.DACL_SECURITY_INFORMATION)
        dacl = sd.GetSecurityDescriptorDacl()

    else:

        inherit_flags = win32security.PROTECTED_DACL_SECURITY_INFORMATION

        if len(acls) < 1:
            print("Skip. No inheritance and no ACLs for " + path)
            return

    
    for acl in acls:

        acl1 = acl.split(":")
        if len(acl1) != 2:
            print("incorrect ACL rec: " + acl)
            continue

        username, permission = acl1

        perm_flags = 0
        container_flags = 0
        if permission == "FULL":
            perm_flags = con.GENERIC_ALL
            container_flags = win32security.OBJECT_INHERIT_ACE | win32security.CONTAINER_INHERIT_ACE

        elif permission == "TRAVERSE":
            perm_flags = con.FILE_GENERIC_EXECUTE | con.FILE_READ_EA
            container_flags = win32security.CONTAINER_INHERIT_ACE

        else:
            print("incorrect permission: " + permission)
            print("    in ACL: " + acl)
            continue

        try:
            sid, domain, type = win32security.LookupAccountName("", username)
        except:
            print("no such user: " + username)
            print("    in ACL: " + acl)
            continue

        dacl.AddAccessAllowedAceEx( \
             win32security.ACL_REVISION_DS \
            ,container_flags \
            ,perm_flags \
            ,sid )

    win32security.SetNamedSecurityInfo( \
        path \
        ,win32security.SE_FILE_OBJECT \
        ,win32security.DACL_SECURITY_INFORMATION | inherit_flags | win32security.OWNER_SECURITY_INFORMATION \
        ,sid_admin,None,dacl,None)

    return


def getacls(aclfile):

    acls = []
    inherited = 1

    if os.path.isfile(aclfile):
        for acl in getconfig(aclfile):
            if acl == "<-NOPARENTS->":
                inherited = 0
            else:
                acls += [acl]

    return [acls, inherited]


def setobjacl(rootdir, relpath, aclroot):

    objpath = os.path.join(rootdir, relpath)

    aclfile = os.path.join(aclroot, relpath, "ACL.txt")
    acls, inherited = getacls(aclfile)

    # is it db dir?
    if len(relpath.split("\\")) == 2:
        if len(acls) < 1:
            print("no ACL found for: "+objpath)

    setacl(objpath, acls, inherited)

    for subdir in os.listdir(objpath):
        fsub = os.path.join(objpath, subdir)
        relpath1 = os.path.join(relpath, subdir)

        if os.path.isdir(fsub):
            setobjacl(rootdir, relpath1, aclroot)
        elif os.path.isfile(fsub):
            aclfile1 = os.path.join(aclroot, relpath1, "ACL.txt")
            acls1, inherited1 = getacls(aclfile1)
            setacl(fsub, acls1, inherited1)

    return




def main():

    global sid_admin

    if len(sys.argv) < 4:
        print_usage()
        return

    cmd = sys.argv[1]
    rootdir = sys.argv[2]

    if not os.path.isdir(rootdir):
        print("ERROR:")
        print("Bad dir: "+rootdir)
        return

    ############ sequrity token
    try:
        try:
            th = win32security.OpenThreadToken(win32api.GetCurrentThread(), win32security.TOKEN_ADJUST_PRIVILEGES | win32security.TOKEN_QUERY, True)
        except win32security.error:
            th = win32security.OpenProcessToken(win32api.GetCurrentProcess(), win32security.TOKEN_ADJUST_PRIVILEGES | win32security.TOKEN_QUERY)

        priv = [ (win32security.LookupPrivilegeValue(None, name), win32security.SE_PRIVILEGE_ENABLED) \
                  for name in (win32security.SE_TAKE_OWNERSHIP_NAME, win32security.SE_RESTORE_NAME)]

        win32security.AdjustTokenPrivileges(th, False, priv)

    except:
        raise

    sid_admin, domain, type = win32security.LookupAccountName("", "Администратор")
    ############


    print("===========")

    if cmd == "init" :
        aclroot = sys.argv[3]
        buildacltree(rootdir, aclroot)

    elif cmd == "clean":
        aclroot = sys.argv[-1]
        dblist=[]
        for rootdir in sys.argv[2:-1]:
            dblist += getdblist(rootdir)
        cleanacltree(aclroot, dblist)

    elif cmd == "repair":
        aclroot = sys.argv[3]
        setobjacl(rootdir, "", aclroot)

    elif cmd == "setacl":
        dir = sys.argv[3]
        aclroot = sys.argv[4]
        setobjacl(rootdir, dir, aclroot)


if __name__ == '__main__':
    main()

