#!/usr/bin/env python3
from __future__ import annotations

import subprocess  # nosec
import json
import re
import os
import redis
import time
import threading
from pathlib import Path
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Iterator
from redis.exceptions import RedisError


RSS_LIMIT_BYTES = 300 * 1024 * 1024  # 300 MiB
LOG_DIR = "/var/log/1s"
TIME_INACTIVE = timedelta(hours=1)
FILE_OUTPUT_STATE = "/1sstat"
REGX_FILE_LOG = re.compile(r"^apache2_(\d+)_(\d{8})\.log$")
MAX_SAFE_INT = (1 << 30) - 1

@dataclass
class State:
    license: int = 0
    time: datetime | None = None
    active: bool = False
    user: str = ""

    @classmethod
    def from_dict(cls, obj: Any) -> State:
        if not isinstance(obj, dict):
            return cls()

        lic_raw = obj.get("license", 0)
        try:
            license_value = int(lic_raw)
        except (TypeError, ValueError):
            license_value = 0

        time_raw = obj.get("time")
        ts: datetime | None = None
        if isinstance(time_raw, str) and time_raw.strip():
            try:
                ts = parse_dt_from_iso(time_raw.strip())
            except ValueError:
                ts = None

        active = bool(obj.get("active", False))
        user = str(obj.get("user", ""))

        return cls(
            license=license_value,
            time=ts,
            active=active,
            user=user,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "license": self.license,
            "time": self.time.isoformat() if self.time is not None else "",
            "active": self.active,
            "user": self.user,
        }


@dataclass(frozen=True)
class LogFile:
    pid: int
    file_time: datetime
    path: Path


def parse_dt_from_filename(value: str) -> datetime:
    return datetime.strptime(value, "%y%m%d%H")


def parse_dt_from_iso(value: str) -> datetime:
    dt = datetime.fromisoformat(value)
    return dt.replace(tzinfo=None) if dt.tzinfo is not None else dt


def iter_json_records(text: str) -> Iterator[dict[str, Any]]:
    decoder = json.JSONDecoder()
    i = 0
    n = len(text)

    while True:
        while i < n and text[i].isspace():
            i += 1
        if i >= n:
            return

        obj, end = decoder.raw_decode(text, i)
        if isinstance(obj, dict):
            yield obj
        i = end


def list_log_files(log_dir: Path) -> list[LogFile] | None:
    files: list[LogFile] = []

    try:
        entries = log_dir.iterdir()
    except OSError:
        return None

    for path in entries:
        if not path.is_file():
            continue

        m = REGX_FILE_LOG.match(path.name)
        if not m:
            continue

        pid_text=m.group(1)
        pid = 0
        try:
            pid = int(pid_text)
        except ValueError:
            continue
        file_time = parse_dt_from_filename(m.group(2))
        files.append(LogFile(pid=pid, file_time=file_time, path=path))

    return files


def select_pid_set(all_log_files: list[LogFile] | None) -> list[LogFile] | None:
    if not all_log_files:
        return None

    latest_file_time = max(f.file_time for f in all_log_files)
    latest_hour_logs = [f for f in all_log_files if f.file_time == latest_file_time]
    max_pid = max(f.pid for f in latest_hour_logs)
    selected = [f for f in all_log_files if f.pid == max_pid]

    return selected


def load_state_from_file(path: Path) -> State:
    try:
        raw = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return State()
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError:
        return State()

    return State.from_dict(obj)


def save_state_to_file(path: Path, state: State) -> None:
    # вроде thread safe
    with path.open("w", encoding="utf-8-sig") as f:
        json.dump(state.to_dict(), f, ensure_ascii=False, indent=4)
        f.write("\n")

    redis_host = os.getenv('REDIS_IP')
    hasp_server = os.getenv('HASP_SERVER')
    base_name = os.getenv('BASE_NAME')
    time_loop_str = os.getenv('TIME_LOOP')
    time_loop = 0
    try:
        time_loop = int(time_loop_str or '')
    except ValueError:
        pass
    if \
      not redis_host or \
      not base_name or \
      not hasp_server or \
      time_loop < 1:
        return

    try:
        with redis.Redis(host=redis_host, decode_responses=True) as r:
            r.set(f"license:{hasp_server}:{base_name}", state.license, ex=int(time_loop*1.05))
    except RedisError:
        pass



def analyze_log_files(log_files: list[LogFile] | None, now: datetime, state: State) -> State:

    if not log_files:
        return state

    result = State(
        license=state.license,
        time=state.time,
        active=False,
        user=state.user,
    )

    active_time_threshold = now - TIME_INACTIVE

    time_of_the_first_file = min(f.file_time for f in log_files) if log_files else None
    result.active = bool(time_of_the_first_file is not None and time_of_the_first_file >= active_time_threshold)

    last_time_lic_record_seen = state.time

    for logfile in sorted(log_files, key=lambda x: x.file_time):
        try:
            logtext = logfile.path.read_text(encoding="utf-8-sig", errors="replace")
        except OSError:
            continue

        for json_log_record in iter_json_records(logtext):
            ts_raw = json_log_record.get("ts")
            try:
                ts = parse_dt_from_iso(ts_raw) if isinstance(ts_raw, str) else logfile.file_time
            except Exception:
                ts = logfile.file_time

            record_name = json_log_record.get("name")

            if record_name == "LIC":
                if last_time_lic_record_seen is None or ts > last_time_lic_record_seen:
                    last_time_lic_record_seen = ts
                    res = json_log_record.get("res")
                    if res == "release":
                        result.license -= 1
                    elif res == "seize":
                        result.license += 1

            if record_name == "SESN":
                if ts >= active_time_threshold:
                    result.active = True
                user = str(json_log_record.get("Usr", ""))
                if len(user) > 0 :
                    result.user = user

    result.time = last_time_lic_record_seen
    return result


def apache_rss_bytes() -> int:
    # Возвращает суммарный RSS всех процессов Apache в байтах.

    total = 0
    for pid_dir in Path("/proc").iterdir():
        if not pid_dir.name.isdigit():
            continue

        try:
            comm = (pid_dir / "comm").read_text().strip()
            if comm == "apache2":
                total += _rss_from_status(pid_dir)
                continue
        except Exception:  # nosec
            continue

    return total


def _rss_from_status(pid_dir: Path) -> int:
    # Читает VmRSS из /proc/<pid>/status и возвращает байты.

    status_path = pid_dir / "status"
    for line in status_path.read_text().splitlines():
        if line.lower().startswith("vmrss:"):
            parts = line.split()
            # VmRSS: <value> kB
            size_kb = 0
            try:
                size_kb = int(parts[1] or '')
            except ValueError:
                pass
            return size_kb * 1024
    return 0


def _graceful_restart_apache() -> int:

    cmd = ["apache2ctl", "-k", "graceful"]

    last_error = None
    try:
        result = subprocess.run(cmd, check=False)   # nosec
        if result.returncode == 0:
            return 0
        last_error = result.returncode
    except FileNotFoundError:
        pass

    return last_error if last_error is not None else 1


def redis_connect_and_listen(proc_lock: threading.Lock) -> None:
    redis_host = None
    base_name = None
    while True:
        redis_host = os.getenv('REDIS_IP')
        base_name = os.getenv('BASE_NAME')

        if redis_host and base_name:
            break
        time.sleep(30)

    r = redis.Redis(
        host=redis_host,
        decode_responses=True,
        health_check_interval=30,
    )
    pubsub = r.pubsub()
    pubsub.subscribe('event:command')

    try:
        for msg in pubsub.listen():
            if msg["type"] != "message":
                continue

            payload = msg["data"]
            parts = payload.split(" ", 1)
            event_id = parts[0]
            command = parts[1] if len(parts) > 1 else ""

            if event_id != base_name and event_id != 'all':
                continue

            match command:
                case 'reset':
                    reset_apache_thread_safe(proc_lock)
    finally:
        pubsub.close()
        r.close()


def redis_listener(proc_lock: threading.Lock) -> None:
    while True:
        try:
            redis_connect_and_listen(proc_lock)
        # except (ConnectionError, TimeoutError):
        #     time.sleep(5)
        # except Exception:
        except RedisError:
            time.sleep(5)


def reset_apache_thread_safe(proc_lock: threading.Lock) -> None:
    # выходить если процедура уже работает, не выполнять дважды

    if not proc_lock.acquire(blocking=False):
        return
    try:
        state = State()
        for item in Path(LOG_DIR).iterdir():
            if item.is_file():
                item.unlink()
        _graceful_restart_apache()
        save_state_to_file(Path(FILE_OUTPUT_STATE), state)
    finally:
        proc_lock.release()


def main() -> int:

    proc_lock = threading.Lock()
    listener_thread = threading.Thread(target=redis_listener, args=(proc_lock,), daemon=True)
    listener_thread.start()

    virgin=True
    no_users_seen = 0
    while True:

        time_loop     = 0
        time_loop_str = None
        no_users_seen_to_restart     = 0
        no_users_seen_to_restart_str = None
        while True:
            time_loop_str = os.getenv('TIME_LOOP')
            no_users_seen_to_restart_str = os.getenv('NO_USERS_SEEN_TO_RESTART')
            try:
                time_loop = int(time_loop_str or '')
                no_users_seen_to_restart = int(no_users_seen_to_restart_str or '')
            except ValueError:
                pass

            if time_loop > 1 and no_users_seen_to_restart > 1:
                break
            time.sleep(30)

        if not virgin:
            time.sleep(time_loop)
        virgin = False

        ### keep it reasonable
        if no_users_seen >= MAX_SAFE_INT:
            no_users_seen = no_users_seen_to_restart

        all_log_files = list_log_files(Path(LOG_DIR))
        selected_log_files = select_pid_set(all_log_files)
        now = datetime.now()
        state = load_state_from_file(Path(FILE_OUTPUT_STATE))
        state = analyze_log_files(selected_log_files, now, state)
        rss = apache_rss_bytes()

        if state.license < 1:
            no_users_seen += 1
        else:
            no_users_seen = 0

        if no_users_seen >= no_users_seen_to_restart and rss > RSS_LIMIT_BYTES:
            no_users_seen = 0
            ### reset includes saving the state
            reset_apache_thread_safe(proc_lock)
        else:
            ### just save the state
            save_state_to_file(Path(FILE_OUTPUT_STATE), state)


if __name__ == "__main__":
    raise SystemExit(main())
