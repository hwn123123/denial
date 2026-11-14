// SPDX-License-Identifier: GPL-3.0-or-later
// One native session handoff; no polling or independent input event producer.
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int write_attribute(const char *path, const char *value) {
    int fd = open(path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        fprintf(stderr, "touch handoff: open %s: %s\n", path, strerror(errno));
        return -1;
    }
    size_t length = strlen(value);
    ssize_t written;
    do {
        written = write(fd, value, length);
    } while (written < 0 && errno == EINTR);
    int saved = errno;
    close(fd);
    if (written != (ssize_t)length) {
        fprintf(stderr, "touch handoff: write %s: %s\n", path,
                written < 0 ? strerror(saved) : "short write");
        return -1;
    }
    return 0;
}

int main(void) {
    if (write_attribute("/sys/devices/platform/synaptics_tcm.0/synaptics_tcm/power_state",
                        "resume\n") < 0 ||
        write_attribute("/sys/devices/virtual/touch/touch_dev/enable_touch_raw", "0\n") < 0) {
        return 1;
    }
    puts("touch handoff: Synaptics resumed with standard evdev coordinates");
    return 0;
}
