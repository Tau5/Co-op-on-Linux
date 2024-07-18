#include <csignal>
#include <cstring>
#include <iostream>
#include <fstream>
#include <stdio.h>
#include <libudev.h>
#include <fcntl.h>    /* For O_RDWR */
#include <unistd.h>   /* For open(), creat() */
#include <sys/stat.h>
#include <sys/types.h>
#include <libevdev-1.0/libevdev/libevdev.h>
#include <vector>
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <signal.h>

#include <initializer_list>
#include <functional>
#include <algorithm>
#include <iostream>

void log_func_evdev(const struct libevdev *dev, enum libevdev_log_priority priority, void *data, const char *file, int line, const char *func, const char *format, va_list args) {
    std::cout << "FUNCIONAAA";
    printf(format, args);
}
struct udev *udev = nullptr;

struct sdevice {
    std::string sysfs_path;
    std::vector<std::string> devnodes;
};

std::vector<std::string> sdevice_get_eventnodes(struct sdevice dev) {
    std::vector<std::string> events;
    for (auto devnode : dev.devnodes) {
        if (devnode.find("event") != std::string::npos) {
            events.push_back(devnode);
        }
    }
    return events;
}

std::vector<struct sdevice> sdevices;

void write_controller_file(std::vector<struct sdevice*> sdevice_players) {
    std::fstream file;
    file.open("../controllers.rc", std::ios_base::out);
    file.clear();

    file << "export CONTROLLERS_NUM=" << sdevice_players.size() << std::endl;
    file << "function load_controller_firejail_args_array() {" << std::endl;

    for (uint i = 0; i < sdevice_players.size(); i++) {
        std::string blacklist_others;
        for (uint a = 0; a < sdevices.size(); a++) {
            if (sdevices[a].sysfs_path != sdevice_players[i]->sysfs_path) {
                for (auto devnode : sdevices[a].devnodes) {
                    blacklist_others += "--blacklist=" + devnode + " ";
                }
            }
        }
        std::cout << i << ": " << sdevice_players[i]->sysfs_path << std::endl;
        std::cout << "\tdevnodes:";
        for (auto devnode: sdevice_players[i]->devnodes) {
            std::cout << " " << devnode;
        }
        file << "\tcontroller_firejail_args[" << i << "]=\"" << blacklist_others << '"' << std::endl;
    }

    file << "}" << std::endl;
    file << "export -f load_controller_firejail_args_array" << std::endl;

    file.close();
}

SDL_Window* window;
SDL_Renderer* renderer;
TTF_Font* font;

int WIDTH = 960;
int HEIGHT = 540;

void signal_handler(int signal) {
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    exit(1);
}

void scan_usb(struct sdevice* sdevice, struct udev* udev, udev_device* usbdev) {
    struct udev_enumerate* enumerate_usb = udev_enumerate_new(udev);
    udev_enumerate_add_match_parent(enumerate_usb, usbdev);
    udev_enumerate_scan_devices(enumerate_usb);

    udev_list_entry* child_devices = udev_enumerate_get_list_entry(enumerate_usb);
    udev_list_entry* curr_child;
    udev_list_entry_foreach(curr_child, child_devices) {
        struct udev_device* child_device;
        child_device = udev_device_new_from_syspath(udev, udev_list_entry_get_name(curr_child));

        std::cout << "\t\t\t" << udev_device_get_syspath(child_device) << std::endl;

        const char* devnode = udev_device_get_devnode(child_device);
        if (devnode) {
            if (std::string(devnode).find("event") != std::string::npos) {
                std::cout << "\t\t\t\tEVENT!" << std::endl;
            }
            sdevice->devnodes.push_back(devnode);
            std::cout << "\t\t\t\t" << devnode << std::endl;
        }
        udev_device_unref(child_device);
    }
}

void scan_devices_from_enumerate(udev_enumerate* udev_enumerate) {
    udev_enumerate_scan_devices(udev_enumerate);
    udev_list_entry* devices = udev_enumerate_get_list_entry(udev_enumerate);
    udev_list_entry* curr_device;
    udev_list_entry_foreach(curr_device, devices) {
        struct sdevice sdevice {};

        const char* sysfs_path;
        const char* dev_path;
        struct udev_device* raw_dev;
        struct udev_device *hid_dev;

        sysfs_path = udev_list_entry_get_name(curr_device);
        std::cout << "[I] Starting scan for " << sysfs_path << std::endl;
        sdevice.sysfs_path = sysfs_path;

        raw_dev = udev_device_new_from_syspath(udev, sysfs_path);
        sysfs_path = udev_device_get_syspath(raw_dev);
        dev_path = udev_device_get_devpath(raw_dev);

        hid_dev = udev_device_get_parent_with_subsystem_devtype(raw_dev, "hid", NULL);

        struct udev_device* usbdev;
        //usbdev = udev_device_get_parent_with_subsystem_devtype(
        //       hid_dev,
        //       "usb",
        //       "usb_device");

        if (hid_dev) {
            usbdev = hid_dev;
        } else {
            usbdev = raw_dev;
        }

        std::cout << sysfs_path << std::endl;
        if (dev_path) {
            std::cout << "[I] Devpath: " << dev_path << std::endl;
            //std::cout << "[I] Devpath devnode: " << udev_device_get_devnode(raw_dev) << std::endl;
        }
        if (hid_dev) {
            std::cout << "[I] HID dev syspath: " << udev_device_get_syspath(hid_dev) << std::endl;
        }

        if (usbdev) {
            std::cout << "[I] USB dev syspath: " << udev_device_get_syspath(usbdev) << std::endl;
            const char* product = udev_device_get_sysattr_value(usbdev, "product");
            if (product) {
                std::cout << "[I] USB dev product: " << product << std::endl;
            }

            //scan_usb(&sdevice, udev, usbdev);
            struct udev_enumerate* enumerate_usb = udev_enumerate_new(udev);
            udev_enumerate_add_match_parent(enumerate_usb, usbdev);
            udev_enumerate_scan_devices(enumerate_usb);

            udev_list_entry* child_devices = udev_enumerate_get_list_entry(enumerate_usb);
            udev_list_entry* curr_child;
            udev_list_entry_foreach(curr_child, child_devices) {
                struct udev_device* child_device;
                child_device = udev_device_new_from_syspath(udev, udev_list_entry_get_name(curr_child));

                std::cout << "\t\t\t" << udev_device_get_syspath(child_device) << std::endl;

                const char* devnode = udev_device_get_devnode(child_device);
                if (devnode) {
                    if (std::string(devnode).find("event") != std::string::npos) {
                        std::cout << "\t\t\t\tEVENT!" << std::endl;
                    }
                    sdevice.devnodes.push_back(devnode);
                    std::cout << "\t\t\t\t" << devnode << std::endl;
                }
                udev_device_unref(child_device);
            }

            udev_enumerate_unref(enumerate_usb);
        }

        sdevices.push_back(sdevice);

        udev_device_unref(raw_dev);

    }
}

auto main(int argc, char *argv[]) -> int {


    std::signal(SIGINT, signal_handler);

    int error = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS);
    if (error) {
        std::cerr << "Error: Couldn't init SDL" << std::endl << "\tSDL_Error: " << SDL_GetError() << std::endl;
        exit(1);
    }

    error = TTF_Init();
    if (error) {
        std::cerr << "Error: Couldn't init SDL_TTF" << std::endl << "\tTTF_Error: " << TTF_GetError() << std::endl;
        exit(1);
    }

    // Check if screen resolutions have been provided
    char opt;
    while ((opt = getopt(argc, argv, "w:h:")) != -1) {
        switch (opt) {
        case 'w':
            WIDTH = std::stoi(optarg);
            break;
        case 'h':
            HEIGHT = std::stoi(optarg);
            break;
        default: /* '?' */
            fprintf(stderr, "Usage: %s [-w width] [-h height]\n",
                    argv[0]);
            exit(EXIT_FAILURE);
        }
    }

    window = SDL_CreateWindow("Controller selector", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, 0);
    if (window == NULL) {
        std::cerr << "Error: Couldn't create SDL Window" << std::endl << "\tSDL_Error: " << SDL_GetError() << std::endl;
        exit(1);
    }

    renderer = SDL_CreateRenderer(window, 0, 0);
    if (renderer == NULL) {
        std::cerr << "Error: Couldn't create SDL Renderer" << std::endl << "\tSDL_Error: " << SDL_GetError() << std::endl;
        exit(1);
    }

    const char* env_p = std::getenv("APPDIR");
    auto font_path = (env_p ? std::string(env_p) : "") + "/usr/share/co-op-on-linux/assets/UbuntuMono-R.ttf";
    font = TTF_OpenFont(font_path.c_str(), 30);
    if (font == nullptr) {
        font_path = "./assets/UbuntuMono-R.ttf";
        font = TTF_OpenFont(font_path.c_str(), 30);
        if (font == nullptr) {
            std::cerr << "Error: Couldn't load font" << std::endl << "\tTTF_Error: " << TTF_GetError() << std::endl;
            exit(1);
        }
    }

    SDL_SetRenderDrawColor(renderer, 0, 0, 100, 255);
    SDL_RenderClear(renderer);

    auto text_surface = TTF_RenderText_Solid(font, "Scanning devices...", {255, 255, 255, 255});
    auto text_texture = SDL_CreateTextureFromSurface(renderer, text_surface);
    auto rect = SDL_Rect {(WIDTH - text_surface->w)/2, (HEIGHT - text_surface->h)/2, text_surface->w, text_surface->h};
    SDL_RenderCopy(renderer, text_texture, nullptr, &rect);

    SDL_RenderPresent(renderer);

    udev = udev_new();

    auto udev_enumerate_xpad = udev_enumerate_new(udev);
    udev_enumerate_add_match_property(udev_enumerate_xpad, "DRIVER", "xpad");
    scan_devices_from_enumerate(udev_enumerate_xpad);
    udev_enumerate_unref(udev_enumerate_xpad);

    auto udev_enumerate_hidraw = udev_enumerate_new(udev);
    udev_enumerate_add_match_subsystem(udev_enumerate_hidraw, "hidraw");
    scan_devices_from_enumerate(udev_enumerate_hidraw);
    udev_enumerate_unref(udev_enumerate_hidraw);

    udev_unref(udev);

    // We've got the events, now it's time for the main plate A.K.A, opening and using evdev to see
    // if a is pressed

    struct evd_device {
        struct sdevice* sdevice;
        int fd;
        std::string eventnode;
        struct libevdev* dev;
        bool ignore_for_detection = false;
    };

    std::vector<struct evd_device> evd_devices;

    for (auto it = sdevices.begin(); it != sdevices.end(); it++) {
        auto events = sdevice_get_eventnodes(*it);
        for (auto eventnode : events) {
            printf("[I]: Trying to open %s\n", eventnode.c_str());
            int fd;
            fd = open(eventnode.c_str(), O_RDONLY | O_NONBLOCK);
            if (fd < 0) {
                printf("[W]: Couldn't open %s (%s)\n", eventnode.c_str(), strerror(-fd));
                close(fd);
                continue;
            }
            int rc = 1;

            char buffer[1024];

            // Reading until the end of the file using fread
            while (read(fd, buffer, sizeof(buffer)) > 0) {

            }

            struct libevdev* dev = libevdev_new();
            libevdev_set_device_log_function(dev, log_func_evdev, LIBEVDEV_LOG_ERROR, NULL);
            rc = libevdev_set_fd(dev, fd);
            if (rc < 0) {
                printf("Failed to init libevdev (%s)\n", strerror(-rc));
                if (eventnode == *events.end().base()) {
                    exit(1);
                } else {
                    continue;
                }
            }
            printf("Input device name: \"%s\"\n", libevdev_get_name(dev));
            printf("Input device ID: bus %#x vendor %#x product %#x\n",
                libevdev_get_id_bustype(dev),
                libevdev_get_id_vendor(dev),
                libevdev_get_id_product(dev));
            if (!libevdev_has_event_code(dev, EV_KEY, BTN_SOUTH)) {
                printf("This device does not look like a gamepad\n");
                continue;
            }
            evd_devices.push_back({it.base(), fd, eventnode, dev});
        }

    }

    std::cout << "SCANNING DONE!" << std::endl;

    std::cout << "Press A/X/B to add a new gamepad, START/+ to add the last gamepad. Max 4" << std::endl;

    std::vector<struct sdevice*> sdevice_players;

    bool selection_done = 0;

    SDL_SetRenderDrawColor(renderer, 70, 0, 210, 255);

    SDL_Event ev;
    while(!selection_done) {

        while (SDL_PollEvent(&ev)) {
            if (ev.type = SDL_WINDOWEVENT) {
                    if (ev.window.event == SDL_WINDOWEVENT_CLOSE) {
                        SDL_DestroyRenderer(renderer);
                        SDL_DestroyWindow(window);
                        exit(1);
                    }
            }
        }

        SDL_RenderClear(renderer);
        TTF_SetFontSize(font, 30);
        auto text_surface = TTF_RenderText_Solid(font, "Press A/X/B (South) on a gamepad (START to confirm)", {255, 255, 255, 255});
        auto text_texture = SDL_CreateTextureFromSurface(renderer, text_surface);
        auto rect = SDL_Rect {(WIDTH - text_surface->w)/2, (HEIGHT - text_surface->h)/2, text_surface->w, text_surface->h};
        if (sdevice_players.size() > 0) {
            rect.y = HEIGHT - text_surface->h * 1.4;

            for (int i = 0; i < sdevice_players.size(); i++) {
                SDL_Rect r;
                if (sdevice_players.size() < 3) {
                    r = {WIDTH/2 * i, 0, WIDTH/2, HEIGHT};
                } else {
                    r = {WIDTH/2 * (i % 2), HEIGHT/2 * (i%4/2), WIDTH/2, HEIGHT/2};
                }

                SDL_SetRenderDrawColor(renderer, 0, 170, 40, 255);
                SDL_RenderFillRect(renderer, &r);
                SDL_SetRenderDrawColor(renderer, 70, 0, 210, 255);
                SDL_RenderDrawRect(renderer, &r);

                TTF_SetFontSize(font, 250);
                auto text_surface = TTF_RenderText_Solid(font, std::to_string(i + 1).c_str(), {255, 255, 255, 255});
                auto text_texture = SDL_CreateTextureFromSurface(renderer, text_surface);
                auto rect = SDL_Rect {r.x + (r.w - text_surface->w)/2, r.y + (r.h - text_surface->h)/2, text_surface->w, text_surface->h};
                //auto rect = SDL_Rect {r.x + (r.w - (int)(r.w * 0.75)) / 2, (r.h - int(r.h * 0.75))/2, static_cast<int>(r.w * 0.75), (int)(r.h * 0.75)};

                SDL_RenderCopy(renderer, text_texture, NULL, &rect);

                SDL_FreeSurface(text_surface);
                SDL_DestroyTexture(text_texture);
            }
        }
        SDL_RenderCopy(renderer, text_texture, NULL, &rect);

        SDL_RenderPresent(renderer);

        SDL_FreeSurface(text_surface);
        SDL_DestroyTexture(text_texture);

        //evd_device* evd_device_to_delete = NULL;
        for (evd_device& ev_device : evd_devices) {
            auto dev = ev_device.dev;
            struct input_event ev;
            int rc = libevdev_next_event(dev, LIBEVDEV_READ_FLAG_NORMAL, &ev);
            if (rc == 0) {
                if (ev.type == EV_KEY && (ev.code == BTN_SOUTH || ev.code == BTN_START)) {
                    std::cout << ev_device.eventnode << ": south " << ev.value << std::endl;
                    if (!ev_device.ignore_for_detection && sdevice_players.size() < 4) {
                        sdevice_players.push_back(ev_device.sdevice);
                        ev_device.ignore_for_detection = true;
                    }
                    //evd_device_to_delete = &ev_device;
                    if (ev.code == BTN_START) {
                        selection_done = true;
                    }
                    break;
                } else if (ev.code == BTN_NORTH) {
                    if (ev.value == 1) sdevice_players.push_back(ev_device.sdevice);
                }
            }
        }
    }

    write_controller_file(sdevice_players);

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    return 0;
}
