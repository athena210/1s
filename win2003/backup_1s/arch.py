
import sys
import os
import datetime
import time
import subprocess
import shutil


def parse_line(line):

    line = line.rstrip('\r\n')
    stripped = line.strip()

    # empty str
    if not stripped:
        return None

    # commented str
    if stripped.startswith('#'):
        return None

    # split by 3 parts
    parts = stripped.split(None, 2)

    if len(parts) < 3:
        return None

    TYPE, STATUS, SRC_PATH = parts[0], parts[1], parts[2]

    return TYPE, STATUS, SRC_PATH


def archive_the_base(basedir, dstdir):
    EXE_7Z = r"C:\Program Files\7-Zip\7z.exe"
    # 7za a arch.7z c:\src -xr!EXTFORMS\Rp??q?.grp\

    ar_name = datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S') + '.7z'
    fn = os.path.join(dstdir, ar_name)
    try:
        return subprocess.call([EXE_7Z, 'a', '-mx=1', '-bd', '-slp', r'-x!*\ExtForms\Rp??q?.grp', fn, basedir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except:
        return None


def rm_content(path):
    for name in os.listdir(path):
        if name == 'System Volume Information':
            continue

        full_path = os.path.join(path, name)
        try:
            if os.path.isfile(full_path) or os.path.islink(full_path):
                os.remove(full_path)
            elif os.path.isdir(full_path):
                shutil.rmtree(full_path)
        except:
            pass



#def rm_all_but_num_files(path, num):
#
#    flist = []
#    for name in os.listdir(path):
#        full_path = os.path.join(path, name)
#        if os.path.isfile(full_path):
#            flist.append(full_path)
#
#    if not flist:
#        return None
#
#    flist = sorted(flist, reverse=True)
#
#    for full_path in flist[num:]:
#        try:
#            os.remove( full_path )
#        except:
#            continue


def main():

    start_time = datetime.datetime.now()
    
    if ( len(sys.argv) < 4 or
         len(sys.argv) > 5 ):
        print("Usage: script.py <config_file> <DST_PATH> <daily|monthly|once> [BASE_NAME|dontclean]")
        sys.exit(1)

    config_file = sys.argv[1]
    DST_PATH = sys.argv[2]
    COMMAND = sys.argv[3]
    BASE_NAME = ""
    if len(sys.argv) > 4:
        BASE_NAME = sys.argv[4]

    if not os.path.isfile(config_file):
        print("Config file not found: %s" % config_file)
        sys.exit(1)

    if DST_PATH.endswith(':') and len(DST_PATH) == 2:
        DST_PATH += os.sep

    if not os.path.isdir(DST_PATH):
        print("Directory not found: %s" % DST_PATH)
        sys.exit(1)

    try:
        f = open(config_file, 'r', encoding='utf-8-sig')
    except IOError as e:
        print("Error opening config file: %s" % str(e))
        sys.exit(1)

    if not BASE_NAME:
        rm_content(DST_PATH)

    for line in f:
        result = parse_line(line)
        if result is None:
            continue

        TYPE, STATUS, SRC_PATH = result
#        print("TYPE=%s STATUS=%s PATH=%s" % (TYPE, STATUS, SRC_PATH))

        if TYPE != 'src':
            continue

        stor_name = os.path.basename(SRC_PATH.rstrip(os.sep))
        
        for DIR in os.listdir(SRC_PATH):
            if not os.path.isdir(os.path.join(SRC_PATH, DIR)):
                continue
            if BASE_NAME and BASE_NAME != 'dontclean' and BASE_NAME != DIR:
                continue
            if ( (COMMAND == 'daily' and STATUS == 'w') or
                 (COMMAND == 'monthly' and STATUS == 'w') or
                 (COMMAND == 'once' and STATUS == 'a') ):
                print("%s/%s" % (stor_name, DIR))
                os.makedirs(os.path.join(DST_PATH, stor_name, DIR), exist_ok=True)
                arch = archive_the_base( os.path.join(SRC_PATH, DIR), os.path.join(DST_PATH, stor_name, DIR))
#                if arch == 0:
#                    rm_all_but_num_files(os.path.join(DST_PATH, stor_name, DIR), 1)

    f.close()

    end_time = datetime.datetime.now()
    duration = end_time - start_time
    minutes_passed = duration.total_seconds() // 60
    seconds_passed = duration.total_seconds() % 60
    print("Time (mm:ss): %d:%d" % (minutes_passed, seconds_passed))


if __name__ == "__main__":
    main()
    
