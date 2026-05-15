#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
import time
import datetime
import yaml
import shlex
import subprocess       # nosec
import multiprocessing as mp
from typing import Any
from pydantic import BaseModel


WORKER_COUNT = 6
JOBS_INTERVAL_SEC = 10
SCRIPT_PRE_FILE='w_pre.sh'
SCRIPT_JOB_FILE='w_job.sh'
SCRIPT_POST_FILE='w_post.sh'


class Ujob(BaseModel):
    command: str
    db_type: str
    db_dir: str
    update_dir: str | None = None


def _load_yaml(
    yaml_file: str
) -> dict[str, Any]:
    with open(yaml_file, "r", encoding="utf-8-sig") as f:
        data = yaml.safe_load(f) or {}

    if not isinstance(data, dict):
        raise ValueError(f"Error: YAML {yaml_file} must be a dictionary.")

    return data


def jobs_to_do(
    db_config_file: str,
    patch_config_file: str,
    command: str,
    with_updates: bool = True,
    only_type: str | None = None
) -> list[Ujob]:

    if not os.path.isfile(db_config_file):
        raise ValueError(f"No such file {db_config_file}")

    db_yaml = _load_yaml(db_config_file)

    patch_yaml = None
    patch_vars = None
    patch_updates = None
    if with_updates:
        if not os.path.isfile(patch_config_file):
            raise ValueError(f"No such file {patch_config_file}")

        patch_yaml = _load_yaml(patch_config_file)
        patch_vars = patch_yaml.get("vars", {})
        # if not isinstance(patch_vars, dict):
        #     raise ValueError(f"'vars' in YAML {patch_config_file} must be a dictionary.")

        patch_updates = patch_yaml.get("updates", {})
        # if not isinstance(patch_updates, dict):
        #     raise ValueError(f"'updates' in YAML {patch_config_file} must be a dictionary.")

    jobs: list[Ujob] = []

    for db_type, db_dirs in db_yaml.items():

        if not isinstance(db_dirs, list):
            raise ValueError(f"Database list for {db_type} in YAML {db_config_file} must be actually a list.")

        updates_for_this_type = ['']
        if with_updates:
            updates_for_this_type = patch_updates.get(db_type, []) if patch_updates is not None else None
            if updates_for_this_type is None:
                updates_for_this_type = []

            if not isinstance(updates_for_this_type, list):
                raise ValueError(f"Updates list for {db_type} in YAML {db_config_file} must be actually a list.")

        for db_dir in db_dirs:

            for update_dir_template in updates_for_this_type:
                update_dir = None
                try:
                    update_dir = update_dir_template.format_map(patch_vars) if patch_vars is not None else None
                except KeyError as e:
                    print(f"EXCEPTION: No such var declared: {e}")
                    pass

                if only_type is not None and not db_type.startswith(only_type):
                    continue

                jobs.append(Ujob(
                    command = command,
                    db_type = db_type,
                    db_dir = db_dir,
                    update_dir = update_dir
                ))

    return jobs


def _argv_from_shebang(
    script_file: str
) -> list[str]:

    first_line = ''
    try:
        with open(script_file, 'r', encoding='utf-8-sig') as f:
            first_line = f.readline().strip('\n')
    except IOError as e:
        raise ValueError(f"Error opening script file: {str(e)}") from e

    if not first_line.startswith("#!"):
        raise ValueError(f"No shebang in file {script_file}")

    shebang = first_line[2:].strip()
    parts = shlex.split(shebang)

    if not parts:
        raise ValueError(f"Shebang is empty in {script_file}")

    return parts + [script_file]


def launch_script_group(
    script_file: str,
    env_vars: dict[str, str],
) -> None:

    if not os.path.isfile(script_file):
        return

    argv = _argv_from_shebang(script_file)

    env = os.environ.copy()
    env.update({k: v for k, v in env_vars.items()})

    proc = subprocess.Popen(
        argv,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True,
        start_new_session=True,
        env=env,
    )  # nosec

    pgid = os.getpgid(proc.pid)
    proc.wait()

    # wait until the whole group dies
    while True:
        try:
            os.killpg(pgid, 0)
        except ProcessLookupError:
            break
        except PermissionError:
            pass

        time.sleep(1)


def run_the_job(job: Ujob) -> None:
    env_vars = {
        "BATCH_1S_PROCESSING":  '1',
        "BATCH_1S_COMMAND":     job.command,
        "BATCH_1S_DB_TYPE":     job.db_type,
        "BATCH_1S_DB_DIR":      job.db_dir,
        "BATCH_1S_UPDATE_DIR":  job.update_dir or ''
    }
    launch_script_group(
        SCRIPT_PRE_FILE,
        env_vars
    )
    launch_script_group(
        SCRIPT_JOB_FILE,
        env_vars
    )
    launch_script_group(
        SCRIPT_POST_FILE,
        env_vars
    )

def multiprocess_the_queue(job_list: list[Ujob]) -> None:

    active_processes = []
    running_dirs = set()
    last_running_time = 0

    idx = 1
    jlen = len(job_list)

    while job_list or active_processes:

        # Release finished jobs
        for p, job in active_processes[:]:
            if p.is_alive():
                continue
            active_processes.remove((p, job))
            running_dirs.remove(job.db_dir)
            last_running_time = time.monotonic()

        # Start new job
        current_time = time.monotonic()
        if (
            job_list and
            len(active_processes) < WORKER_COUNT and
            (current_time - last_running_time) >= JOBS_INTERVAL_SEC
        ):
            # look for a db which is not being processed now
            for i, job in enumerate(job_list):
                if job.db_dir in running_dirs:
                    continue
                job_to_run = job_list.pop(i)

                p = mp.Process(target=run_the_job, args=(job_to_run,))
                running_dirs.add(job_to_run.db_dir)
                active_processes.append((p, job_to_run))

                print(f"[{idx:02d}/{jlen:02d}] {os.path.basename(job.db_dir)}")
                idx += 1
                p.start()
                last_running_time = time.monotonic()
                break 

        time.sleep(1)


def main() -> int:

    time_start = time.monotonic()
    print(f"Started at {datetime.datetime.fromtimestamp(round(time.time()))}")

    dir_user = os.getenv('DIR_USER')
    dir_group = os.getenv('DIR_GROUP')
    if \
      not dir_user or \
      not dir_group or \
      dir_user != str(os.geteuid()) or \
      dir_group != str(os.getegid()):
        print("Must be started from container as non-root.")
        return 1

    args = sys.argv[1:]

    if not args:
        print("Usage: script.py command [type]")
        print("Commands: run, repair, update")
        print("Type: pattern to match db type. For example b83 matches b83* types")
        return(1)

    command = args[0].lower()
    only_type = args[1].lower() if len(args) > 1 else None

    include_updates = False
    match command:
        case "run":
            include_updates = False
        case "repair":
            include_updates = False
        case "update":
            include_updates = True
        case _:
            print(f"Unknown command: {command}")
            return(1)

    jobs_list: list[Ujob] = []
    try:
        jobs_list = jobs_to_do('list_db.yaml', 'list_updates.yaml', command, include_updates, only_type)
    except ValueError as e:
        print(e)
        return(1)

    # for j in jobs_list:
    #     print(f"job: {j.db_type} {j.db_dir} {j.update_dir}")


    multiprocess_the_queue(jobs_list)

    time_end = time.monotonic()
    print(f"Finished at {datetime.datetime.fromtimestamp(round(time.time()))}")
    print(f"Job done in {datetime.timedelta(seconds=round(time_end - time_start + 0.49))}")

    return(0)


if __name__ == "__main__":
    raise SystemExit(main())
