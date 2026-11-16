// SPDX-License-Identifier: MIT
// KDE 6 shortcut launcher entry; never edits live KWin / kglobalshortcutsrc bindings.
#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
namespace fs = std::filesystem;
using StringList = std::vector<std::string>;
namespace {
fs::path homePath() {
    const char* v=std::getenv("HOME");
    if (!v || !*v) throw std::runtime_error("HOME is missing");
    return fs::path(v);
}
fs::path rootPath() {
    const char* v=std::getenv("KANSO_ROOT");
    return v && *v ? fs::path(v) : homePath()/"Rice/kanso";
}
fs::path configHome() {
    const char* v=std::getenv("XDG_CONFIG_HOME");
    return v && *v ? fs::path(v) : homePath()/".config";
}
fs::path dataHome() {
    const char* v=std::getenv("XDG_DATA_HOME");
    return v && *v ? fs::path(v) : homePath()/".local/share";
}
fs::path stateHome() {
    const char* v=std::getenv("XDG_STATE_HOME");
    return v && *v ? fs::path(v) : homePath()/".local/state";
}
fs::path entryPath(){return dataHome()/"applications/kanso-launcher.desktop";}
fs::path statePath(){return stateHome()/"kanso-native-shortcuts";}
void rejectLinks(const fs::path& path) {
    for (auto cur=path; !cur.empty() && cur!=cur.parent_path(); cur=cur.parent_path()) {
        if (fs::is_symlink(fs::symlink_status(cur)))
            throw std::runtime_error("Refusing symlink path: "+cur.string());
    }
}
std::string read(const fs::path& file) {
    std::ifstream f(file, std::ios::binary);
    if(!f) throw std::runtime_error("Unable to read "+file.string());
    std::ostringstream out; out<<f.rdbuf();return out.str();
}
void write(const fs::path& path,const std::string& text) {
    rejectLinks(path);
    fs::create_directories(path.parent_path());
    fs::path temp=path; temp += ".kanso-native-stage";
    if(fs::exists(temp)||fs::is_symlink(fs::symlink_status(temp)))throw std::runtime_error("Staging file already exists: "+temp.string());
    try {
        {std::ofstream f(temp,std::ios::binary);f<<text;if(!f)throw std::runtime_error("Write failed");}
        fs::rename(temp,path);
    } catch (...) {std::error_code ec;fs::remove(temp,ec);throw;}
}
bool managed(const std::string &txt){return txt.find("X-Kanso-Managed=true")!=std::string::npos;}
bool knownLauncher(const std::string &txt) {
    std::istringstream in(txt);std::string line;
    while(std::getline(in,line)) {
        if(!line.starts_with("Exec="))continue;
        return line.find(" rofi")!=std::string::npos &&
               (line.find("/kansoctl.py")!=std::string::npos ||
                line.find("/native/bin/kanso-native")!=std::string::npos);
    }
    return false;
}
std::string launcherText() {
    auto binary=rootPath()/"native/bin/kanso-native";
    if(!fs::is_regular_file(binary)||fs::is_symlink(fs::symlink_status(binary)))
        throw std::runtime_error("Native executable missing: "+binary.string());
    auto s=binary.string();
    if(s.find_first_of("\n\r\"%'\\")!=std::string::npos)
        throw std::runtime_error("Unsupported characters in native executable path");
    return "[Desktop Entry]\nType=Application\nName=Kanso Launcher\n"
           "Comment=Minimal launcher for Kanso\nIcon=system-search\n"
           "Exec=\""+s+"\" rofi\n"
           "Terminal=false\nCategories=Utility;\nStartupNotify=false\n"
           "X-Kanso-Managed=true\n";
}
void checkEntry() {
    auto e=entryPath();rejectLinks(e);
    std::cout<<"Entry: "<<e<<'\n';
    if(fs::exists(e)) {
        if(!fs::is_regular_file(e))throw std::runtime_error("Entry is not a regular file");
        auto raw=read(e);
        if(!managed(raw)) throw std::runtime_error("Existing desktop entry not owned by Kanso");
        if(!knownLauncher(raw)) throw std::runtime_error("Unknown managed entry Exec; no change");
        bool python=(raw.find("python3")!=std::string::npos||raw.find("kansoctl.py")!=std::string::npos);
        std::cout<<(python?"Current entry: legacy Python\n":"Current entry: no Python command\n");
    } else std::cout<<"Current entry: absent\n";
    const auto s=statePath();rejectLinks(s);
    if(fs::exists(s/"installed"))std::cout<<"Native shortcut state already installed\n";
    else std::cout<<"Native shortcut state: not installed\n";
    std::cout<<"Does not read or modify KWin global shortcut bindings\n";
}
void installEntry() {
    auto e=entryPath(), state=statePath();rejectLinks(e);rejectLinks(state);
    if(fs::exists(state) || fs::is_symlink(fs::symlink_status(state)))
        throw std::runtime_error("Existing shortcut state; inspect before reinstalling");
    std::string original;
    bool existed=fs::exists(e);
    if(existed) {
        if(!fs::is_regular_file(e))throw std::runtime_error("Existing entry is not a regular file");
        original=read(e);
        if(!managed(original)) throw std::runtime_error("Unmanaged desktop entry; refusing overwrite");
        // Avoid replacing an unrelated managed entry with an unexpected command.
        if(!knownLauncher(original))throw std::runtime_error("Unknown managed entry Exec; no change");
    }
    auto next=launcherText();
    fs::create_directories(state);
    try {
        write(state/"existed",existed?"yes\n":"no\n");
        write(state/"before",original);
        write(state/"after",next);
        write(e,next);
        write(state/"installed","Kanso Native shortcut\n");
    } catch (...) {
        // Conservative failure: keep backup available for manual recovery;
        // do not pretend a partially written setup was completed.
        std::cerr<<"Kanso shortcut: installation interrupted; check "<<state<<'\n';
        throw;
    }
    std::cout<<"Native launcher entry installed: "<<e<<"\n"
             <<"KDE global Meta+Space must be rebound manually to the entry or native command.\n";
}
void restoreEntry() {
    auto e=entryPath(),state=statePath();rejectLinks(e);rejectLinks(state);
    if(!fs::is_regular_file(state/"installed") || !fs::is_regular_file(state/"before") ||
       !fs::is_regular_file(state/"after") || !fs::is_regular_file(state/"existed"))
        throw std::runtime_error("No complete native shortcut backup");
    if(!fs::is_regular_file(e) || read(e)!=read(state/"after"))
        throw std::runtime_error("Desktop entry modified since native install; refusing restore");
    if(read(state/"existed")=="yes\n")write(e,read(state/"before"));
    else if(read(state/"existed")=="no\n")fs::remove(e);
    else throw std::runtime_error("Invalid native shortcut backup marker");
    fs::remove_all(state);
    std::cout<<"Original desktop entry restored. KDE shortcut binding unchanged.\n";
}
void audit() {
    auto cfg=configHome()/"kglobalshortcutsrc";
    if(fs::exists(cfg)) {
        rejectLinks(cfg);
        if(!fs::is_regular_file(cfg)) throw std::runtime_error("Shortcut config is not a regular file");
        std::istringstream in(read(cfg));std::string line,group;
        while(std::getline(in,line)) {
            if(line.size()>2 && line.front()=='[' && line.back()==']')group=line;
            if(line.find("Meta+Space")!=std::string::npos || line.find("Win+Space")!=std::string::npos ||
               line.find("kansoctl.py")!=std::string::npos || line.find("python3")!=std::string::npos) {
                if(line.size()>250)line.resize(250);
                std::cout<<group<<' '<<line<<'\n';
            }
        }
    }
    checkEntry();
    std::cout<<"Only KDE Settings can reliably change a cached Wayland shortcut binding.\n";
}
void openSettings() {
    StringList commands={"kcmshell6","systemsettings"};
    for(const auto& c:commands) {
        if(::access(("/usr/bin/"+c).c_str(),X_OK)!=0)continue;
        pid_t p=::fork();
        if(p<0)throw std::runtime_error("fork failed");
        if(p==0) {::setsid();::execl(("/usr/bin/"+c).c_str(),c.c_str(),"kcm_keys",(char*)nullptr);_exit(127);}
        std::cout<<"Opening KDE keyboard settings (no bindings modified).\n";
        return;
    }
    throw std::runtime_error("KDE shortcut settings tool missing");
}
}
int run_native_shortcut(const StringList& args) {
    if(args.size()!=1) {std::cerr<<"Usage: shortcut check|audit|install-entry|restore-entry|open-settings\n";return 2;}
    if(args[0]=="check")checkEntry();
    else if(args[0]=="audit")audit();
    else if(args[0]=="install-entry")installEntry();
    else if(args[0]=="restore-entry")restoreEntry();
    else if(args[0]=="open-settings")openSettings();
    else {std::cerr<<"Unknown shortcut action\n";return 2;}
    return 0;
}
