// SPDX-License-Identifier: MIT
// Kanso Native Core - narrow C++ replacements for frequently invoked Python helpers.
// No Qt requirement and no shell interpolation in any privileged/system action.
#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <string_view>
#include <thread>
#include <vector>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
namespace fs = std::filesystem;
using Args = std::vector<std::string>;

static std::string read(const fs::path &path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) throw std::runtime_error("Cannot read: " + path.string());
    std::ostringstream out; out << in.rdbuf(); return out.str();
}
static bool safeFile(const fs::path &path) {
    return !fs::is_symlink(fs::symlink_status(path)) && fs::exists(path) && fs::is_regular_file(path);
}
static fs::path home() {
    const char* value = std::getenv("HOME");
    if (!value || !*value) throw std::runtime_error("HOME is not set");
    return fs::path(value);
}
static fs::path root() {
    if (const char* r = std::getenv("KANSO_ROOT")) return fs::path(r);
    return home() / "Rice/kanso";
}
static bool available(const std::string &name) {
    if (name.find('/') != std::string::npos) return ::access(name.c_str(), X_OK) == 0;
    const char* raw = std::getenv("PATH");
    std::istringstream path(raw ? raw : "/usr/bin:/bin");
    std::string part;
    while (std::getline(path, part, ':')) {
        if (part.empty()) part = ".";
        if (::access((fs::path(part) / name).c_str(), X_OK) == 0) return true;
    }
    return false;
}
static std::string join(const Args &args) {
    std::string result;
    for (const auto& a : args) { if (!result.empty()) result += ' '; result += a; }
    return result;
}
static int spawn(const Args &args, bool detach=false, int timeout=25) {
    if (args.empty()) return 127;
    pid_t pid = ::fork();
    if (pid < 0) throw std::runtime_error("fork failed");
    if (pid == 0) {
        if (detach) {
            ::setsid();
            // Detached desktop commands must never hold pipes to the QML process.
            auto fd = ::fopen("/dev/null", "r+");
            if (fd) { ::dup2(fileno(fd), STDIN_FILENO); ::dup2(fileno(fd), STDOUT_FILENO); ::dup2(fileno(fd), STDERR_FILENO); }
        }
        std::vector<char*> a;
        for (const auto &s : args) a.push_back(const_cast<char*>(s.c_str()));
        a.push_back(nullptr);
        ::execvp(a[0], a.data());
        _exit(127);
    }
    if (detach) { int state = 0; ::waitpid(pid, &state, WNOHANG); return 0; }
    const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(timeout);
    int state = 0;
    while (std::chrono::steady_clock::now() < end) {
        auto w = ::waitpid(pid, &state, WNOHANG);
        if (w == pid) return WIFEXITED(state) ? WEXITSTATUS(state) : 128;
        if (w == -1) throw std::runtime_error("waitpid failed");
        std::this_thread::sleep_for(std::chrono::milliseconds(30));
    }
    ::kill(pid, SIGTERM);
    ::waitpid(pid, &state, 0);
    std::cerr << "Kanso: command timed out: " << args.front() << '\n';
    return 124;
}
static double round1(double n) { return std::round(n * 10.0) / 10.0; }
static int status() {
    fs::path proc = std::getenv("KANSO_TEST_PROC_ROOT") ? std::getenv("KANSO_TEST_PROC_ROOT") : "/proc";
    std::istringstream cpu(read(proc / "stat"));
    std::string token; cpu >> token;
    if (token != "cpu") throw std::runtime_error("Missing /proc/stat cpu line");
    unsigned long long n=0, total=0, idle=0;
    for (int i=0;i<8;i++) {if (!(cpu >> n)) throw std::runtime_error("Malformed /proc/stat"); total+=n; if(i==3 || i==4) idle+=n;}
    unsigned long long memTotal=0, memFree=0, memAvailable=0;
    std::istringstream info(read(proc / "meminfo"));
    while (std::getline(info, token)) {
        std::istringstream row(token); std::string key, unit; unsigned long long value=0;
        if (!(row >> key >> value)) continue;
        if (key=="MemTotal:") memTotal=value;
        if (key=="MemFree:") memFree=value;
        if (key=="MemAvailable:") memAvailable=value;
    }
    if (!memTotal) throw std::runtime_error("Missing MemTotal");
    if (!memAvailable) memAvailable=memFree;
    const auto used = memTotal - std::min(memAvailable, memTotal);
    std::cout << std::fixed << std::setprecision(1)
        << "{\"total\":" << total << ",\"idle\":" << idle
        << ",\"memory_percent\":" << round1(100.0*double(used)/double(memTotal))
        << ",\"memory_used_gib\":" << double(used)/1048576.0
        << ",\"memory_total_gib\":" << double(memTotal)/1048576.0 << "}\n";
    return 0;
}
static std::string led(const std::string &name) {
    fs::path p = std::getenv("KANSO_TEST_LEDS_ROOT") ? std::getenv("KANSO_TEST_LEDS_ROOT") : "/sys/class/leds";
    if (!fs::exists(p)) return "null";
    std::vector<fs::path> matches;
    for (auto &it : fs::directory_iterator(p)) {
        if (it.path().filename().string().ends_with("::"+name)) matches.push_back(it.path()/"brightness");
    }
    std::sort(matches.begin(),matches.end());
    for (const auto &path : matches) {
        std::ifstream in(path); int value=0;
        if (in >> value) return value>0 ? "true" : "false";
    }
    return "null";
}
static int locks() { std::cout << "{\"caps\":" << led("capslock") << ",\"num\":" << led("numlock") << "}\n"; return 0; }
static int power(const std::string &action, bool dry) {
    std::vector<Args> choices;
    const std::string bus = available("qdbus6") ? "qdbus6" : (available("qdbus") ? "qdbus" : "");
    if (action=="lock") { choices.push_back({"loginctl","lock-session"}); if (!bus.empty()) choices.push_back({bus,"org.freedesktop.ScreenSaver","/ScreenSaver","Lock"}); }
    else if (action=="suspend") choices.push_back({"systemctl","suspend"});
    else if (action=="logout") {
        if (!bus.empty()) choices.push_back({bus,"org.kde.Shutdown","/Shutdown","org.kde.Shutdown.logout"});
        if (const char* id = std::getenv("XDG_SESSION_ID"); id && *id) choices.push_back({"loginctl","terminate-session",id});
    } else if (action=="reboot") {
        if (!bus.empty()) choices.push_back({bus,"org.kde.Shutdown","/Shutdown","org.kde.Shutdown.logoutAndReboot"});
        choices.push_back({"systemctl","reboot"});
    } else if (action=="shutdown") {
        if (!bus.empty()) choices.push_back({bus,"org.kde.Shutdown","/Shutdown","org.kde.Shutdown.logoutAndShutdown"});
        choices.push_back({"systemctl","poweroff"});
    } else {std::cerr << "Invalid power action\n";return 2;}
    for (const auto& choice:choices) {
        if (dry) {std::cout << join(choice) << '\n';continue;}
        if (!available(choice.front())) continue;
        int code=spawn(choice,false,12); if (code==0) return 0;
        std::cerr << "Kanso power: " << choice.front() << " exit " << code << '\n';
    }
    return dry ? 0 : 1;
}
static std::string selectedMode() {
    auto file=root()/"theme-selection.json";
    if (!safeFile(file)) return "day";
    auto s=read(file);
    return std::regex_search(s,std::regex("\\\"selected\\\"\\s*:\\s*\\\"night\\\"")) ? "night" : "day";
}
static int rofi() {
    if (!available("rofi")) {std::cerr << "Kanso: rofi executable missing\n";return 127;}
    const auto file=root()/"config/rofi"/(selectedMode()=="night" ? "kanso-night.rasi":"kanso.rasi");
    if (!safeFile(file)) {std::cerr << "Kanso: missing Rofi theme " << file << '\n';return 2;}
    Args args={"rofi","-no-config","-theme",file.string(),"-show","drun"};
    std::vector<char*> argv; for (auto& a:args) argv.push_back(a.data()); argv.push_back(nullptr);
    ::execvp(argv[0],argv.data());
    return 127;
}
static Args updateProgram() {
    if (available("cachy-update")) return {"cachy-update"};
    if (available("arch-update")) return {"arch-update"};
    if (available("paru")) return {"paru","-Syu"};
    if (available("pacman") && available("sudo")) return {"sudo","pacman","-Syu"};
    throw std::runtime_error("No cachy-update, arch-update, paru or pacman available");
}
static int updates(const Args &args, const fs::path &self) {
    auto cmd=updateProgram();
    if (std::find(args.begin(),args.end(),"--print")!=args.end()) {
        std::cout << "Updater: " << join(cmd) << '\n'; return 0;
    }
    if (std::find(args.begin(),args.end(),"--interactive")!=args.end()) {
        std::cout << "\n KANSO · CACHYOS UPDATES\n Program: " << join(cmd) << "\n";
        std::cout << "Press Enter to continue, Ctrl+C to cancel..." << std::flush;
        std::string answer; if (!std::getline(std::cin,answer)) return 0;
        int code=spawn(cmd,false,7200);
        std::cout << "\nUpdater exited (" << code << "). Press Enter to close." << std::flush;
        std::getline(std::cin,answer);
        return code;
    }
    if (std::find(args.begin(),args.end(),"--launch")==args.end()) {std::cerr << "Use updates --launch|--print\n";return 2;}
    Args launcher;
    if (available("alacritty")) launcher={"alacritty","--title","Kanso - Updates","-e",self.string(),"updates","--interactive"};
    else if (available("konsole")) launcher={"konsole","--hold","-e",self.string(),"updates","--interactive"};
    else if (available("xterm")) launcher={"xterm","-T","Kanso - Updates","-e",self.string(),"updates","--interactive"};
    else throw std::runtime_error("Alacritty, Konsole or xterm required");
    return spawn(launcher,true);
}
static void replaceAll(std::string &target, std::string_view from, std::string_view to, int &count) {
    auto pos=target.find(from);
    while(pos!=std::string::npos) {target.replace(pos,from.size(),to);count++;pos=target.find(from,pos+to.size());}
}
struct Change { fs::path path; std::string before,after; int replacements=0; };
static const std::vector<std::pair<std::string,std::string>>& patterns() {
    static const std::vector<std::pair<std::string,std::string>> p={
        {"[\"python3\", Quickshell.shellDir + \"/scripts/system_status.py\"]","[Quickshell.shellDir + \"/native/bin/kanso-native\", \"status\"]"},
        {"[\"python3\", Quickshell.shellDir + \"/scripts/keylocks.py\"]","[Quickshell.shellDir + \"/native/bin/kanso-native\", \"locks\"]"},
        {"[\"python3\", Quickshell.shellDir + \"/scripts/power.py\", name]","[Quickshell.shellDir + \"/native/bin/kanso-native\", \"power\", name]"},
        {"[\"python3\", Quickshell.shellDir + \"/scripts/open_updates.py\", \"--launch\"]","[Quickshell.shellDir + \"/native/bin/kanso-native\", \"updates\", \"--launch\"]"},
        {"[\"python3\", Quickshell.shellDir + \"/kansoctl.py\", \"rofi\"]","[Quickshell.shellDir + \"/native/bin/kanso-native\", \"rofi\"]"},
        {"[\"python3\",Quickshell.shellDir+\"/kansoctl.py\",\"rofi\"]","[Quickshell.shellDir + \"/native/bin/kanso-native\", \"rofi\"]"}
    };return p;
}
static std::vector<Change> changes(bool allowPatched) {
    std::vector<fs::path> names={"services/SystemStatus.qml","services/KeyboardStatus.qml","popups/KansoPower.qml","popups/KansoUpdates.qml","components/KansoPanel.qml","components/KansoDock.qml"};
    std::vector<Change> output;
    for(const auto &name:names) {
        Change c; c.path=root()/name; if(!safeFile(c.path)) throw std::runtime_error("Missing or symlinked QML: "+c.path.string());
        c.before=read(c.path);c.after=c.before;
        for(const auto& [oldv,newv]:patterns()) replaceAll(c.after,oldv,newv,c.replacements);
        // Already native means it is managed by this migration only with state.
        if(c.replacements==0 && (!allowPatched || c.before.find("native/bin/kanso-native")==std::string::npos))
            throw std::runtime_error("Expected Python call not found in "+c.path.string()+"; no files touched");
        output.push_back(std::move(c));
    }
    // Each of the six required QML files must contain a recognized Python caller.
    // The number of calls per file varies between dock revisions (6 or 7 total).
    // The per-file validation above is the safety boundary, not a magic global count.
    return output;
}
static fs::path migrationState() {
    const char* state=std::getenv("XDG_STATE_HOME");
    return fs::path(state && *state ? state : (home()/".local/state").string())/"kanso-native-core";
}
static void writeAtomic(const fs::path &path,const std::string &value) {
    auto stage=path;stage+=".kanso-native-stage";
    {std::ofstream out(stage,std::ios::binary|std::ios::trunc); if(!out) throw std::runtime_error("write failed: "+stage.string());out<<value;out.flush();if(!out) throw std::runtime_error("write failed: "+stage.string());}
    fs::permissions(stage,fs::status(path).permissions());
    fs::rename(stage,path);
}
static int migrate(const std::string &operation) {
    auto dir=migrationState();auto marker=dir/"installed";
    if(operation=="restore") {
        if(!safeFile(marker)) throw std::runtime_error("No migration recorded");
        auto list=changes(true);
        for(size_t i=0;i<list.size();++i) {
            auto post=dir/(std::to_string(i)+".after");
            if (!safeFile(post) || !safeFile(dir/(std::to_string(i)+".before")) || read(post)!=list[i].before) throw std::runtime_error("QML changed after migration: "+list[i].path.string()+"; refusing restore");
        }
        for(size_t i=0;i<list.size();++i) writeAtomic(list[i].path,read(dir/(std::to_string(i)+".before")));
        fs::remove(marker);
        std::cout << "Original QML restored. Native binary left installed (harmless).\n";
        return 0;
    }
    if(fs::exists(marker)) {
        if(operation=="check") {
            auto current=changes(true);
            for(size_t i=0;i<current.size();++i) {
                auto after=dir/(std::to_string(i)+".after");
                if(!safeFile(after) || read(after)!=current[i].before)
                    throw std::runtime_error("Installed QML changed externally: "+current[i].path.string());
            }
            std::cout<<"Native migration installed, all six QML files match.\n";return 0;
        }
        throw std::runtime_error("Already installed. Use migrate restore first");
    }
    auto list=changes(false);
    for(auto &c:list) std::cout << (operation=="check" ? "WILL PATCH " : "PATCH ") << c.path.filename().string() << " (" << c.replacements << " calls)\n";
    if(operation=="check") {std::cout<<"Compatible: no QML modified. Theme switching remains Python in this phase.\n";return 0;}
    if(operation!="install") return 2;
    if(fs::exists(dir) && fs::is_symlink(dir)) throw std::runtime_error("Unsafe state symlink");
    fs::create_directories(dir);
    // Save all snapshots before touching a single QML file.
    for(size_t i=0;i<list.size();++i) {
        std::ofstream before(dir/(std::to_string(i)+".before"),std::ios::binary|std::ios::trunc);
        std::ofstream after(dir/(std::to_string(i)+".after"),std::ios::binary|std::ios::trunc);
        before << list[i].before; after << list[i].after;
        if(!before||!after) throw std::runtime_error("Cannot save rollback data");
    }
    size_t applied=0;
    try {for(;applied<list.size();++applied) writeAtomic(list[applied].path,list[applied].after);}
    catch(...) {for(size_t i=0;i<applied;++i) writeAtomic(list[i].path,list[i].before);throw;}
    {std::ofstream out(marker);out<<root().string()<<'\n';out.close();
      if(!out) {for(size_t i=0;i<list.size();++i) writeAtomic(list[i].path,list[i].before);
                throw std::runtime_error("Cannot write installed marker; QML restored");}}
    std::cout<<"Native migration installed. Restart only Quickshell (not KWin/Plasma).\n";
    return 0;
}
static int themeMigrate(const std::string &operation) {
    const auto file=root()/"shell.qml";
    const auto dir=migrationState()/"native-theme-upgrade";
    const auto marker=dir/"installed";
    const std::string original="[\"python3\", Quickshell.shellDir + \"/scripts/theme_mode.py\", \"--apply\", mode]";
    const std::string replacement="[Quickshell.shellDir + \"/native/bin/kanso-native\", \"theme\", \"--apply\", mode]";
    if(!safeFile(file)) throw std::runtime_error("Missing/symlinked shell.qml");
    std::string raw=read(file);
    if(operation=="restore") {
        if(!safeFile(marker)||!safeFile(dir/"before")||!safeFile(dir/"after")) throw std::runtime_error("Theme migration backup missing");
        if(raw!=read(dir/"after"))throw std::runtime_error("shell.qml changed externally; refusing restore");
        writeAtomic(file,read(dir/"before")); fs::remove(marker);fs::remove(dir/"before");fs::remove(dir/"after");
        std::cout<<"Theme call restored to previous Python helper.\n";return 0;
    }
    if(fs::exists(marker)) {
        if(operation=="check" && safeFile(dir/"after") && raw==read(dir/"after")) {
            std::cout<<"Theme migration already active; shell.qml matches.\n";return 0;
        }
        throw std::runtime_error("Theme migration already installed or shell.qml changed");
    }
    const auto pos=raw.find(original);
    if(pos==std::string::npos || raw.find(original,pos+original.size())!=std::string::npos)
        throw std::runtime_error("Expected unique original theme call missing; no modification");
    if(raw.find(replacement)!=std::string::npos)throw std::runtime_error("Already has native theme call");
    auto after=raw;after.replace(pos,original.size(),replacement);
    if(operation=="check"){
        std::cout<<"Compatible native theme upgrade: one QML call, no file touched.\n";return 0;
    }
    if(operation!="install")return 2;
    if(fs::is_symlink(fs::symlink_status(dir)))throw std::runtime_error("Unsafe theme migration state");
    fs::create_directories(dir);
    if(fs::exists(dir/"before")||fs::exists(dir/"after"))throw std::runtime_error("Migration snapshots already exist; review state");
    {std::ofstream f(dir/"before",std::ios::binary);f<<raw;if(!f)throw std::runtime_error("Cannot back up QML");}
    {std::ofstream f(dir/"after",std::ios::binary);f<<after;if(!f)throw std::runtime_error("Cannot prepare QML snapshot");}
    writeAtomic(file,after);
    try{std::ofstream f(marker);f<<root().string()<<'\n';if(!f)throw std::runtime_error("Cannot create migration marker");}
    catch(...){writeAtomic(file,raw);throw;}
    std::cout<<"QML theme call migrated to native C++.\n";return 0;
}
int run_native_theme(const Args &args);
int run_native_shortcut(const Args &args);
int run_native_icons(const Args &args);
int run_native_doctor(const Args &args);
int run_native_windows(const Args &args);
static void help() {std::cout<<"kanso-native commands:\n  status | locks | rofi | power ACTION [--dry-run] | updates --launch|--print|--interactive\n  migrate check|install|restore\n  theme --check|--apply day|night\n  theme-migrate check|install|restore\n  shortcut check|install-entry|restore-entry|audit|open-settings\n  icons check|status|install|restore|adopt-check|adopt|return-legacy\n  doctor audit|preflight | windows [--dock-debug]\n";}
int main(int argc,char** argv) {
    try {
        if(argc<2) {help();return 2;}
        const std::string cmd=argv[1];
        if(cmd=="status") return status();
        if(cmd=="locks") return locks();
        if(cmd=="rofi") return rofi();
        if(cmd=="power") return argc<3 ? 2 : power(argv[2],argc>3 && std::string(argv[3])=="--dry-run");
        if(cmd=="updates") return updates(Args(argv+2,argv+argc),fs::absolute(argv[0]));
        if(cmd=="migrate") return argc<3 ? 2 : migrate(argv[2]);
        if(cmd=="theme") return run_native_theme(Args(argv+2, argv+argc));
        if(cmd=="shortcut") return run_native_shortcut(Args(argv+2, argv+argc));
        if(cmd=="icons") return run_native_icons(Args(argv+2, argv+argc));
        if(cmd=="doctor") return run_native_doctor(Args(argv+2,argv+argc));
        if(cmd=="windows") return run_native_windows(Args(argv+2,argv+argc));
        if(cmd=="theme-migrate") return argc<3 ? 2 : themeMigrate(argv[2]);
        help();return 2;
    } catch(const std::exception &e) { std::cerr<<"Kanso Native: "<<e.what()<<'\n';return 2;}
}
