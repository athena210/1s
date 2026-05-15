#!/usr/bin/python3

import time
import os
import sys
import shutil
import datetime


######################
def mod7(conf, fromdir, todir) :

    fromdir = fromdir.replace('\\','\\\\')
    todir = todir.replace('\\','\\\\')

    confdir = os.path.dirname(conf)
    username = os.path.basename(confdir)

    found = None
    with open(conf,"r",encoding="utf-16") as fh:
        lines = []
        for line in fh:
            if fromdir in line:
                found = username
                line = line.replace(fromdir, todir)
            lines.append(line)

    if found :
        print(found)
        with open(conf, "w", encoding="utf-16") as fd:
            for line in lines:
                fd.write(line)

    return



def mod8(conf, fromdir, todir) :

    username = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(conf)))))

    found = None
    with open(conf,"r", encoding="utf-8") as fh:
        lines = []
        for line in fh:
            if fromdir in line:
                found = username
                line = line.replace(fromdir, todir)
            lines.append(line)

    if found :
        print(found)
        with open(conf, "w", encoding="utf-8") as fd:
            for line in lines:
                fd.write(line)

    return



def print_usage():
    print("USAGE:")
    print("command.py /fromdir /todir")


def main():

    if len(sys.argv) != 3:
        print_usage()
        return

    fromdir = sys.argv[1]
    todir = sys.argv[2]

    if len(fromdir) < 1 :
        print("ERROR:")
        print("Too short path: "+fromdir)
        return

    if len(todir) < 1 :
        print("ERROR:")
        print("Too short path: "+todir)
        return

#    print("========")
########################################
#    print(sys.stdin.encoding)
#    fromdir = fromdir.encode(encoding="cp866").decode(encoding="cp1251")
#    todir = todir.encode(encoding="cp866").decode(encoding="cp1251")
########################################

    homes = os.path.dirname(os.environ['ALLUSERSPROFILE'])

    print("== v7")
    for i in os.listdir(homes):
        homedir = os.path.join(homes, i)
        if not os.path.isdir(homedir) :
            continue
        conf7 = os.path.join(homedir, os.path.basename(homedir)+"_77.reg")
        if os.path.isfile(conf7) :
            mod7(conf7, fromdir, todir)

    print("== v8")
    for i in os.listdir(homes):
        homedir = os.path.join(homes, i)
        if not os.path.isdir(homedir) :
            continue
        conf8 = os.path.join(homedir,"Application Data","1C","1CEStart","ibases.v8i")
        if os.path.isfile(conf8) :
            mod8(conf8, fromdir, todir)





if __name__ == '__main__':
    main()

