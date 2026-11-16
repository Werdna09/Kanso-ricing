// Kanso native read-only preflight and Python dependency audit.
// No child process is started, no user configuration is written.
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>
#include <algorithm>
namespace kd {
namespace fs = std::filesystem;
static fs::path home(){const char* s=getenv("HOME");if(!s||!*s)throw std::runtime_error("HOME missing");return fs::path(s);}
static fs::path root(){const char* p=getenv("KANSO_ROOT");return p&&*p?fs::path(p):home()/"Rice/kanso";}
static bool file(const fs::path& p){std::error_code ec;return !fs::is_symlink(fs::symlink_status(p,ec))&&fs::is_regular_file(p,ec);}
static std::string read(const fs::path& p){std::ifstream in(p);std::ostringstream s;s<<in.rdbuf();return s.str();}
static bool pythonReference(const std::string& s){return s.find("python3")!=std::string::npos||s.find("/usr/bin/python")!=std::string::npos||s.find(".py\"")!=std::string::npos||s.find(".py'")!=std::string::npos||s.find(".py ")!=std::string::npos||s.find(".py\n")!=std::string::npos;}
static int scanFile(const fs::path& p, bool verbose){
    if(!file(p))return 0;
    std::error_code ec;if(fs::file_size(p,ec)>1048576||ec)return 0;
    const std::string content=read(p);if(content.find('\0')!=std::string::npos)return 0;
    std::istringstream s(content);std::string line;int number=0,hits=0;
    while(std::getline(s,line)){
        ++number;auto x=line.find_first_not_of(" \t");if(x==std::string::npos||line[x]=='#')continue;
        if(pythonReference(line)){
            if(verbose)std::cout<<"  REFERENCE "<<p<<":"<<number<<"\n";
            hits++;
        }
    }
    return hits;
}
static int scanDirectory(const fs::path& base,bool verbose){
    std::error_code ec;
    if(!fs::is_directory(base,ec)||fs::is_symlink(fs::symlink_status(base,ec)))return 0;
    int hits=0;size_t count=0;
    fs::recursive_directory_iterator it(base,fs::directory_options::skip_permission_denied,ec),end;
    for(;it!=end;it.increment(ec)){
        if(ec){ec.clear();continue;}
        if(++count>4000){std::cerr<<"WARNING: scan limited to 4000 files in "<<base<<"\n";break;}
        const auto p=it->path();if(it->is_symlink(ec)){it.disable_recursion_pending();continue;}
        if(it->is_directory(ec))continue;
        const auto ext=p.extension().string();
        if(ext==".qml"||ext==".js"||ext==".desktop"||ext==".service"||ext==".timer"||ext==".sh"||ext==".fish"||ext==".conf"||ext==".ini")hits+=scanFile(p,verbose);
    }
    return hits;
}
}
int run_native_doctor(const std::vector<std::string>& a){
    if(a.size()!=1||(a[0]!="audit"&&a[0]!="preflight")){
        std::cerr<<"Usage: kanso-native doctor audit|preflight\n";return 2;
    }
    const auto root=kd::root();int errors=0;
    if(!std::filesystem::is_directory(root)){std::cerr<<"Missing Kanso root: "<<root<<"\n";return 2;}
    if(a[0]=="preflight"){
        const std::vector<std::string> required={"shell.qml","components/KansoDock.qml","components/KansoPanel.qml","services/SystemStatus.qml","services/KeyboardStatus.qml","popups/KansoPower.qml","popups/KansoUpdates.qml","native/src/main.cpp","native/src/theme.cpp","native/src/shortcut.cpp","native/src/icons.cpp","native/CMakeLists.txt"};
        for(const auto& n:required){if(!kd::file(root/n)){std::cerr<<"MISSING "<<n<<"\n";++errors;}}
        const auto shell=root/"shell.qml";
        if(kd::file(shell)&&kd::read(shell).find("native/bin/kanso-native")==std::string::npos){std::cerr<<"Theme has not been migrated to native C++\n";++errors;}
        if(!kd::file(root/"native/bin/kanso-native")){std::cerr<<"MISSING built native binary\n";++errors;}
    }
    int pyfiles=0;
    std::error_code ec;
    for(std::filesystem::recursive_directory_iterator it(root,std::filesystem::directory_options::skip_permission_denied,ec),end;it!=end;it.increment(ec)){
        if(ec){ec.clear();continue;}
        if(it->is_symlink(ec)){it.disable_recursion_pending();continue;}
        if(it->is_regular_file(ec)&&it->path().extension()==".py")++pyfiles;
        if(it->is_directory(ec)&&it->path().filename()==".build")it.disable_recursion_pending();
    }
    const auto runtime=kd::scanDirectory(root,false);
    int external=0;
    for(const auto& d:{kd::home()/".config/autostart",kd::home()/".config/autostart-scripts",kd::home()/".config/systemd/user",kd::home()/".local/share/applications"})external+=kd::scanDirectory(d,true);
    std::cout<<"Kanso root: "<<root<<"\n";
    std::cout<<"Python source files: "<<pyfiles<<"\n";
    std::cout<<"Python command references in Kanso config/code: "<<runtime<<"\n";
    std::cout<<"Python command references in user launchers/autostart: "<<external<<" (some may be unrelated)\n";
    if(runtime){std::cerr<<"Runtime/config reference found, details follow:\n";kd::scanDirectory(root,true);errors++;}
    if(external)std::cerr<<"Inspect user launcher references before removing old scripts.\n";
    if(errors)return 2;
    std::cout<<"Read-only audit completed. No files changed.\n";
    return 0;
}
