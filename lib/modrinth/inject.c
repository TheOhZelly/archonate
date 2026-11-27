// Archonate's look for the Modrinth app, with nothing of the app changed.
//
// The app is a web page in WebKitGTK and has no theme files of its own, so this
// is preloaded (LD_PRELOAD, set only by Archonate's launcher entry for it) and
// adds ~/.config/archonate/modrinth.css as a user stylesheet to the app's
// WebKit content manager, the first time the app hands that manager a script.
// The file is watched: a style change restyles the open app at once.
//
// It links nothing: every WebKit/GLib call is looked up in the running process,
// so in the shell scripts and helpers the launcher passes through it is inert.
// In the app itself it takes itself out of LD_PRELOAD, so Minecraft and the
// other programs the app starts never load it.
//
// Build: cc -shared -fPIC -O2 -o modrinth-inject.so inject.c -ldl
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void *ptr;
static ptr managers[16];
static int n_managers;
static ptr monitor;

#define SYM(name) ((ptr)dlsym(RTLD_DEFAULT, name))

static char *css_path(void) {
    static char path[4096];
    const char *xdg = getenv("XDG_CONFIG_HOME"), *home = getenv("HOME");
    if (xdg && *xdg)
        snprintf(path, sizeof path, "%s/archonate/modrinth.css", xdg);
    else
        snprintf(path, sizeof path, "%s/.config/archonate/modrinth.css", home ? home : "");
    return path;
}

static void apply(ptr m) {
    int (*get_contents)(const char *, char **, unsigned long *, ptr *) = SYM("g_file_get_contents");
    ptr (*sheet_new)(const char *, int, int, ptr, ptr) = SYM("webkit_user_style_sheet_new");
    void (*add)(ptr, ptr) = SYM("webkit_user_content_manager_add_style_sheet");
    void (*remove_all)(ptr) = SYM("webkit_user_content_manager_remove_all_style_sheets");
    void (*unref)(ptr) = SYM("webkit_user_style_sheet_unref");
    void (*gfree)(ptr) = SYM("g_free");
    if (!get_contents || !sheet_new || !add || !remove_all || !unref || !gfree)
        return;
    char *css = NULL;
    remove_all(m);
    if (!get_contents(css_path(), &css, NULL, NULL))
        return; // no file: the app's own look
    // all frames, user level (its !important rules win over the page's)
    ptr s = sheet_new(css, 0, 1, NULL, NULL);
    add(m, s);
    unref(s);
    gfree(css);
}

static void changed(ptr mon, ptr file, ptr other, int event, ptr data) {
    (void)mon; (void)file; (void)other; (void)data;
    // any change, rename-over (how Archonate writes it) or removal: reload.
    // Skip only the "attribute changed" and unmount noise.
    if (event == 4 || event == 5 || event == 6)
        return;
    for (int i = 0; i < n_managers; i++)
        apply(managers[i]);
}

static void watch(void) {
    ptr (*file_new)(const char *) = SYM("g_file_new_for_path");
    ptr (*monitor_file)(ptr, int, ptr, ptr *) = SYM("g_file_monitor_file");
    unsigned long (*connect)(ptr, const char *, ptr, ptr, ptr, int) = SYM("g_signal_connect_data");
    if (monitor || !file_new || !monitor_file || !connect)
        return;
    ptr f = file_new(css_path());
    monitor = monitor_file(f, 2 /* G_FILE_MONITOR_WATCH_MOVES */, NULL, NULL);
    if (monitor)
        connect(monitor, "changed", (ptr)changed, NULL, NULL, 0);
}

void webkit_user_content_manager_add_script(ptr m, ptr script) {
    static void (*real)(ptr, ptr);
    if (!real)
        real = (void (*)(ptr, ptr))dlsym(RTLD_NEXT, "webkit_user_content_manager_add_script");
    if (real)
        real(m, script);
    for (int i = 0; i < n_managers; i++)
        if (managers[i] == m)
            return;
    if (n_managers < 16) {
        managers[n_managers++] = m;
        apply(m);
        watch();
    }
}

// In the app (not the launcher's shell scripts), drop this library from
// LD_PRELOAD so nothing the app starts inherits it.
__attribute__((constructor)) static void scrub(void) {
    char exe[4096];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    if (n <= 0)
        return;
    exe[n] = 0;
    if (!strstr(exe, "modrinth"))
        return;
    const char *pre = getenv("LD_PRELOAD");
    if (!pre)
        return;
    char out[8192] = "";
    char *copy = strdup(pre), *save = NULL;
    for (char *tok = strtok_r(copy, ": ", &save); tok; tok = strtok_r(NULL, ": ", &save)) {
        if (strstr(tok, "modrinth-inject"))
            continue;
        if (*out)
            strncat(out, ":", sizeof out - strlen(out) - 1);
        strncat(out, tok, sizeof out - strlen(out) - 1);
    }
    free(copy);
    if (*out)
        setenv("LD_PRELOAD", out, 1);
    else
        unsetenv("LD_PRELOAD");
}
