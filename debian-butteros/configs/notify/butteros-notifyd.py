#!/usr/bin/env python3
# ==============================================================================
# ADD-ON: ButterOS notification service (org.freedesktop.Notifications).
# Apps (Clocks alarms, Calls, Chatty SMS, notify-send...) post notifications on the session
# bus; with no daemon owning that name they were silently lost. Each one is appended as a
# JSON line to /run/user/1000/butteros-notifs.jsonl, which the bridge serves at /notifs and
# the shell turns into a pop-up + a card in the notification shade.
# Needs python3-dbus + python3-gi. Started from butteros-session.
# ==============================================================================
import json, os, time
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

LOG = '/run/user/1000/butteros-notifs.jsonl'
MAX_LINES = 300

def last_seq():
    try:
        with open(LOG) as f:
            lines = f.readlines()
        return json.loads(lines[-1]).get('seq', 0) if lines else 0
    except (OSError, ValueError, IndexError):
        return 0

class Notifications(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, '/org/freedesktop/Notifications')
        self.seq = last_seq()

    @dbus.service.method('org.freedesktop.Notifications', in_signature='susssasa{sv}i', out_signature='u')
    def Notify(self, app_name, replaces_id, app_icon, summary, body, actions, hints, timeout):
        self.seq += 1
        nid = int(replaces_id) or self.seq
        entry = {'seq': self.seq, 'id': nid, 'app': str(app_name) or 'App', 'summary': str(summary),
                 'body': str(body)[:500], 'icon': str(app_icon), 'time': int(time.time()),
                 'urgency': int(hints.get('urgency', 1)) if 'urgency' in hints else 1}
        try:
            with open(LOG, 'a') as f:
                f.write(json.dumps(entry) + '\n')
            with open(LOG) as f:
                lines = f.readlines()
            if len(lines) > MAX_LINES:
                with open(LOG, 'w') as f:
                    f.writelines(lines[-MAX_LINES:])
        except OSError:
            pass
        return dbus.UInt32(nid)

    @dbus.service.method('org.freedesktop.Notifications', in_signature='u', out_signature='')
    def CloseNotification(self, nid):
        self.NotificationClosed(nid, 3)

    @dbus.service.method('org.freedesktop.Notifications', in_signature='', out_signature='as')
    def GetCapabilities(self):
        return ['body', 'persistence']

    @dbus.service.method('org.freedesktop.Notifications', in_signature='', out_signature='ssss')
    def GetServerInformation(self):
        return ('ButterOS', 'ButterOS', '1.0', '1.2')

    @dbus.service.signal('org.freedesktop.Notifications', signature='uu')
    def NotificationClosed(self, nid, reason):
        pass

    @dbus.service.signal('org.freedesktop.Notifications', signature='us')
    def ActionInvoked(self, nid, action_key):
        pass

if __name__ == '__main__':
    os.environ.setdefault('DBUS_SESSION_BUS_ADDRESS', 'unix:path=/run/user/1000/bus')
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName('org.freedesktop.Notifications', bus, do_not_queue=True)
    Notifications(bus)
    GLib.MainLoop().run()
