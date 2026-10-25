#!/usr/bin/env python3
# Yatagarasu Roost — the listener. Watches the session's
# notification bus from the public square (via dbus-monitor)
# and reports the mood of the moment: the priority of the
# freshest scroll still standing, or EMPTY when the wire is
# clear. Speaks on stdout: READY / ARRIVE <P> / MOOD <P|EMPTY>
import re
import signal
import subprocess
from collections import OrderedDict

MAX_PENDING = 256

stack = {}
pending = OrderedDict()

def emit_mood():
    top = ""
    for value in stack.values():
        top = value
    print("MOOD " + (top if top else "EMPTY"), flush=True)

def prio_of(hints):
    if "x-jurai-priority" in hints:
        value = str(hints["x-jurai-priority"]).upper()
        if value in ("LOW", "MEDIUM", "HIGH", "CRITICAL"):
            return value
    try:
        urgency = int(hints.get("urgency", 1))
    except (TypeError, ValueError):
        urgency = 1
    return "CRITICAL" if urgency >= 2 else ("LOW" if urgency <= 0 else "MEDIUM")

proc = subprocess.Popen(
    [
        "dbus-monitor",
        "type='method_call',interface='org.freedesktop.Notifications',member='Notify',destination='org.freedesktop.Notifications'",
        "type='signal',interface='org.freedesktop.Notifications',member='NotificationClosed',sender='org.freedesktop.Notifications'",
        "type='method_return'",
        "type='error'",
    ],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    bufsize=1,
)

def stop_monitor(_signum, _frame):
    if proc.poll() is None:
        proc.terminate()
    raise SystemExit(0)

signal.signal(signal.SIGINT, stop_monitor)
signal.signal(signal.SIGTERM, stop_monitor)

mode = None
sender = None
destination = None
serial = None
reply_serial = None
body_lines = []

def finish_block():
    global mode
    if mode == "notify" and sender and serial is not None:
        replaces = 0
        hints = {}
        first_uint = True
        for index, line in enumerate(body_lines):
            stripped = line.strip()
            if first_uint:
                match = re.match(r"uint32 (\d+)", stripped)
                if match:
                    replaces = int(match.group(1))
                    first_uint = False
                    continue
            match = re.match(r'string "(urgency|x-jurai-priority)"', stripped)
            if match and index + 1 < len(body_lines):
                value = re.search(
                    r'variant\s+(?:byte (\d+)|string "(.*)")',
                    body_lines[index + 1],
                )
                if value:
                    hints[match.group(1)] = (
                        value.group(1) if value.group(1) is not None else value.group(2)
                    )
        priority = prio_of(hints)
        key = (sender, serial)
        pending[key] = (priority, replaces)
        pending.move_to_end(key)
        while len(pending) > MAX_PENDING:
            pending.popitem(last=False)
        print("ARRIVE " + priority, flush=True)
    elif mode == "return" and destination and reply_serial is not None:
        result = pending.pop((destination, reply_serial), None)
        if result:
            priority, replaces = result
            for line in body_lines:
                match = re.match(r"uint32 (\d+)", line.strip())
                if match:
                    notification_id = int(match.group(1))
                    if replaces:
                        stack.pop(replaces, None)
                    if notification_id:
                        stack.pop(notification_id, None)
                        stack[notification_id] = priority
                        emit_mood()
                    break
    elif mode == "error" and destination and reply_serial is not None:
        pending.pop((destination, reply_serial), None)
    elif mode == "closed":
        for line in body_lines:
            match = re.match(r"uint32 (\d+)", line.strip())
            if match:
                notification_id = int(match.group(1))
                if notification_id in stack:
                    del stack[notification_id]
                    emit_mood()
                break
    mode = None

print("READY", flush=True)
try:
    for line in proc.stdout:
        if not line.startswith((" ", "\t")):
            finish_block()
            body_lines = []
            sender = destination = None
            serial = reply_serial = None
            if line.startswith("method call") and "member=Notify" in line:
                mode = "notify"
                match = re.search(r"\bsender=([^\s]+)", line)
                sender = match.group(1) if match else None
                match = re.search(r"\bserial=(\d+)", line)
                serial = int(match.group(1)) if match else None
            elif line.startswith("method return"):
                mode = "return"
                match = re.search(r"\bdestination=([^\s]+)", line)
                destination = match.group(1) if match else None
                match = re.search(r"\breply_serial=(\d+)", line)
                reply_serial = int(match.group(1)) if match else None
            elif line.startswith("error"):
                mode = "error"
                match = re.search(r"\bdestination=([^\s]+)", line)
                destination = match.group(1) if match else None
                match = re.search(r"\breply_serial=(\d+)", line)
                reply_serial = int(match.group(1)) if match else None
            elif line.startswith("signal") and "member=NotificationClosed" in line:
                mode = "closed"
            else:
                mode = None
        elif mode:
            body_lines.append(line)
    finish_block()
finally:
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
