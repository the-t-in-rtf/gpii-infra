from locust import HttpLocust, TaskSet, task, events
import random
import os

import on_failure
events.request_failure += on_failure

dev_rep_serialised = "{\"OS\": { \"id\": \"win32\" }, \"solutions\": [{\"id\":\"com.freedomscientific.jaws\"},{\"id\":\"com.freedomscientific.magic\"},{\"id\":\"com.microsoft.windows.cursors\"},{\"id\":\"com.microsoft.windows.filterKeys\"},{\"id\":\"com.microsoft.windows.highContrast\"},{\"id\":\"com.microsoft.windows.highContrastTheme\"},{\"id\":\"com.microsoft.windows.language\"},{\"id\":\"com.microsoft.windows.magnifier\"},{\"id\":\"com.microsoft.windows.mouseKeys\"},{\"id\":\"com.microsoft.windows.mouseSettings\"},{\"id\":\"com.microsoft.windows.mouseTrailing\"},{\"id\":\"com.microsoft.windows.narrator\"},{\"id\":\"com.microsoft.windows.nightScreen\"},{\"id\":\"com.microsoft.windows.onscreenKeyboard\"},{\"id\":\"com.microsoft.windows.screenDPI\"},{\"id\":\"com.microsoft.windows.screenResolution\"},{\"id\":\"com.microsoft.windows.stickyKeys\"},{\"id\":\"com.microsoft.windows.touchPadSettings\"},{\"id\":\"com.microsoft.windows.typingEnhancement\"},{\"id\":\"com.microsoft.windows.volumeControl\"},{\"id\":\"com.microsoft.windows.desktopBackground\"},{\"id\":\"com.microsoft.windows.desktopBackgroundColor\"},{\"id\":\"fakemag2\"},{\"id\":\"fakescreenreader1\"},{\"id\":\"net.gpii.explode\"},{\"id\":\"net.gpii.test.speechControl\"},{\"id\":\"net.gpii.uioPlus\"},{\"id\":\"org.alsa-project\"},{\"id\":\"org.freedesktop.xrandr\"},{\"id\":\"org.gnome.desktop.a11y.applications.onscreen-keyboard\"},{\"id\":\"org.gnome.desktop.a11y.keyboard\"},{\"id\":\"org.gnome.desktop.a11y.magnifier\"},{\"id\":\"org.gnome.desktop.interface\"},{\"id\":\"org.gnome.nautilus\"},{\"id\":\"org.gnome.orca\"},{\"id\":\"org.nvda-project\"},{\"id\":\"com.microsoft.office\"}]}"

# "alice" is left off intentionally so that we can use it as our user.
users = [
    "ben",
    "carla",
    "chris",
    "debbie",
    "elaine",
    "jaws",
    "maggie",
    "magic",
    "naomi",
    "nvda",
    "vicky",
    "vladimir",
    "wayne"
]

def flip_booleans(originalDict):
    flippedDict = {}
    for key in originalDict:
        value = originalDict[key]
        if isinstance(value, bool):
            flippedDict[key] = not value
        elif isinstance(value, dict):
            flippedDict[key] = flip_booleans(value)
        else:
            flippedDict[key] = value
    return flippedDict

def get_access_token(l, username, nameTemplate):
    headers = {
        "Content-Type":"application/x-www-form-urlencoded",
    }
    body = {
        "grant_type": "password",
        "username": username,
        "password": "test",
        "client_id": "pilot-computer",
        "client_secret": "pilot-computer-secret"
    }
    name = nameTemplate.format(username)
    auth_response = l.client.post('/access_token', name=name, data=body, headers=headers, verify=False)
    return auth_response.json()["access_token"]

def auth_headers(access_token):
    auth_template = 'Bearer {}'
    headers = { 'Authorization': '', }

    # Create the auth header
    headers["Authorization"] = auth_template.format(access_token)
    return headers

def exercise_settings_endpoints(l, login_username, snapset_name):
    snapset_access_token = get_access_token(l, snapset_name, "1. Snapset user login.")
    snapset_headers = auth_headers(snapset_access_token)

    get_url_template = "/{}/settings/%s"
    put_url_template = "/{}/settings"

    # Full URL includes the serialised device reporter data.
    snapset_get_url = get_url_template.format(snapset_name) % dev_rep_serialised

    snapset_get_response = l.client.get(snapset_get_url, name="2. Read snapset", headers=snapset_headers, verify=False)

    original_settings = snapset_get_response.json()

    # Attempt to update a read-only snapset.
    put_snapset_url = put_url_template.format(snapset_name)
    with l.client.put(put_snapset_url, name="3. Attempt to update snapset", headers=snapset_headers, verify=False, catch_response=True) as snapset_update_response:
        snapset_update_response_body = snapset_update_response.json()
        if snapset_update_response_body["isError"]:
            snapset_update_response.success()
        else:
            snapset_update_response.failure("Updating a read-only snapset should not be allowed.")

    user_access_token = get_access_token(l, login_username, "4. Normal user login.")
    user_headers = auth_headers(user_access_token)

    updated_settings = {}
    updated_settings["contexts"] = flip_booleans(original_settings["preferences"]["contexts"])

    settings_put_url = put_url_template.format(login_username)
    settings_put_response = l.client.put(settings_put_url, name="5. Valid settings save", data=updated_settings, headers=user_headers, verify=False)

    # Attempt to PUT an invalid payload
    with l.client.put(settings_put_url, name="6. Attempt to save an invalid settings payload", headers=user_headers, data={}, verify=False, catch_response=True) as invalid_settings_response:
        if invalid_settings_response.status_code == 400:
            invalid_settings_response.success()
        else:
            invalid_settings_response.failure("Invalid settings payload should have been rejected.")

    # Test retrieving someone else's settings.
    with l.client.get(snapset_get_url, name="7. Read someone else's snapset", headers=user_headers, verify=False, catch_response=True) as unauthorised_settings_response:
        if unauthorised_settings_response.status_code == 401:
            unauthorised_settings_response.success()
        else:
            unauthorised_settings_response.failure("Unauthorized snapset read should have been rejected.")

class PreferencesWriteTasks(TaskSet):
    login_username = "alice"
    prefs_to_clone = "carla"

    def on_start(self):
        self.prefs_to_clone = random.choice(users)

    @task
    def my_task(self):
        exercise_settings_endpoints(self, self.login_username, self.prefs_to_clone)

class PreferencesWriteWarmer(HttpLocust):
    task_set = PreferencesWriteTasks
    min_wait = 5000
    max_wait = 9000
