// SPDX-License-Identifier: MIT
// Native icon theme manager. No Python, sudo or shell evaluation.
// Does not modify already-installed icon themes from the legacy manager.
#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <memory>
#include <regex>
#include <openssl/evp.h>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <cerrno>
#include <csignal>
#include <sys/wait.h>
#include <unistd.h>
namespace fs = std::filesystem;
using Words = std::vector<std::string>;
namespace {
fs::path envOr(const char* name, const fs::path& fallback) {
    const char* value=std::getenv(name);
    return value && *value ? fs::path(value) : fallback;
}
fs::path home(){const char* h=std::getenv("HOME"); if(!h||!*h)throw std::runtime_error("HOME missing");return fs::path(h);}
fs::path rice(){return envOr("KANSO_ROOT",home()/"Rice/kanso");}
fs::path source(){return rice()/"icon-theme/Kanso";}
fs::path dest(){return envOr("XDG_DATA_HOME",home()/".local/share")/"icons/Kanso";}
fs::path state(){return envOr("XDG_STATE_HOME",home()/".local/state")/"kanso-native-icons";}
fs::path legacy(){return envOr("XDG_STATE_HOME",home()/".local/state")/"kanso-standalone/icons-v31.json";}
void noLinkParents(const fs::path& p) {
    auto part=p;
    while (!part.empty()) {
        if(fs::is_symlink(fs::symlink_status(part))) throw std::runtime_error("Symlink path rejected: "+part.string());
        if(part==part.parent_path())break;
        part=part.parent_path();
    }
}
std::string readFile(const fs::path& p) {
    if(fs::is_symlink(fs::symlink_status(p))||!fs::is_regular_file(p))throw std::runtime_error("Not a regular file: "+p.string());
    std::ifstream f(p,std::ios::binary);if(!f)throw std::runtime_error("Could not read "+p.string());
    std::ostringstream buf;buf<<f.rdbuf();if(f.bad())throw std::runtime_error("Read failed: "+p.string());return buf.str();
}
void writeNew(const fs::path& p,const std::string& s){
    noLinkParents(p);if(fs::exists(p)||fs::is_symlink(fs::symlink_status(p)))throw std::runtime_error("Already exists: "+p.string());
    fs::create_directories(p.parent_path());
    std::ofstream f(p,std::ios::binary);f<<s;if(!f)throw std::runtime_error("Write failed: "+p.string());
}
std::vector<fs::path> regularFiles(const fs::path& root){
    noLinkParents(root);if(!fs::is_directory(root))throw std::runtime_error("Directory missing: "+root.string());
    std::vector<fs::path> files;
    for(auto iter=fs::recursive_directory_iterator(root,fs::directory_options::none);iter!=fs::recursive_directory_iterator();++iter) {
        if(iter->is_symlink())throw std::runtime_error("Symlink in theme: "+iter->path().string());
        if(!iter->is_regular_file()&&!iter->is_directory())throw std::runtime_error("Unusual file in theme: "+iter->path().string());
        if(iter->is_regular_file())files.push_back(fs::relative(iter->path(),root));
    }
    std::sort(files.begin(),files.end());return files;
}
size_t validateSource(){
    const auto index=readFile(source()/"index.theme");
    bool inGroup=false, directories=false;
    std::vector<std::string> required;
    std::istringstream lines(index);std::string line;
    while(std::getline(lines,line)){
        if(!line.empty()&&line.back()=='\r')line.pop_back();
        if(!line.empty()&&line.front()=='['){inGroup=line=="[Icon Theme]";continue;}
        if(!inGroup||!line.starts_with("Directories="))continue;
        directories=true;std::istringstream list(line.substr(12));std::string part;
        while(std::getline(list,part,',')){if(!part.empty())required.push_back(part);}
    }
    if(!directories||required.empty())throw std::runtime_error("Invalid index.theme: Directories missing");
    size_t count=0;
    for(const auto& name:required){
        auto rel=fs::path(name);
        if(rel.empty()||rel.is_absolute()||rel.lexically_normal()!=rel||name.find("..")!=std::string::npos)
            throw std::runtime_error("Unsafe icon directory: "+name);
        auto dir=source()/rel;noLinkParents(dir);
        if(!fs::is_directory(dir))throw std::runtime_error("Icon directory missing: "+dir.string());
        bool hasSvg=false;
        for(const auto& item:fs::directory_iterator(dir)) {
            if(item.is_symlink())throw std::runtime_error("Symlink icon rejected: "+item.path().string());
            if(item.is_regular_file()&&item.path().extension()==".svg")hasSvg=true;
        }
        if(!hasSvg)throw std::runtime_error("No SVG icons in "+dir.string());
    }
    for(const auto& file:regularFiles(source()))if(file.extension()==".svg")++count;
    std::cout<<"Kanso icons valid: "<<count<<" SVGs; no changes to KDE\n";return count;
}
std::string execCapture(Words args){
    if(args.empty())throw std::runtime_error("No command");
    int fds[2];if(::pipe(fds))throw std::runtime_error("pipe failed");
    auto pid=::fork();
    if(pid<0){::close(fds[0]);::close(fds[1]);throw std::runtime_error("fork failed");}
    if(pid==0){
        ::close(fds[0]);::dup2(fds[1],STDOUT_FILENO);::dup2(fds[1],STDERR_FILENO);::close(fds[1]);
        std::vector<char*> argv;for(auto& s:args)argv.push_back(s.data());argv.push_back(nullptr);
        ::execvp(argv[0],argv.data());_exit(127);
    }
    ::close(fds[1]);
    // Config tools print at most a line. Read to completion, bounded to 32 KiB.
    std::string output;char buf[1024];ssize_t n;
    while((n=::read(fds[0],buf,sizeof(buf)))>0){
        output.append(buf,static_cast<size_t>(n));
        if(output.size()>32768){::kill(pid,SIGTERM);break;}
    }
    ::close(fds[0]);int status=0;
    if(::waitpid(pid,&status,0)<0||!WIFEXITED(status)||WEXITSTATUS(status)!=0)
        throw std::runtime_error(args[0]+" failed: "+output.substr(0,300));
    while(!output.empty()&&(output.back()=='\n'||output.back()=='\r'))output.pop_back();
    return output;
}
std::string selected(){return execCapture({"kreadconfig6","--file","kdeglobals","--group","Icons","--key","Theme"});}
void setSelected(const std::string& name){
    // Empty legacy KDE values cannot be safely restored via kwriteconfig6 --key ... <empty>.
    // Keep an empty previous value instead of silently modifying unrelated KDE keys.
    if(name.empty())throw std::runtime_error("Previous icon selection was empty; restore manually in KDE Settings");
    execCapture({"kwriteconfig6","--file","kdeglobals","--group","Icons","--key","Theme",name});
}
void maybeRefresh(){
    // Cache refresh is best effort and never escalates privileges.
    try { execCapture({"kbuildsycoca6"}); }catch(const std::exception&){}
}
bool sameTree(const fs::path& a,const fs::path& b) {
    auto fa=regularFiles(a),fb=regularFiles(b);if(fa!=fb)return false;
    for(const auto& p:fa)if(readFile(a/p)!=readFile(b/p))return false;
    return true;
}
// Read only the literal, ASCII strings produced by the old Python manager.
// Unknown JSON escaping causes a safe refusal rather than a guessed file path.
std::string legacyField(const std::string& data, const std::string& key) {
    const std::regex re("\"" + key + "\"\\s*:\\s*\"([^\"]*)\"");
    std::smatch match;
    if (!std::regex_search(data, match, re) || match.size()!=2)
        throw std::runtime_error("Legacy icon record missing field: " + key);
    std::string result=match[1].str();
    if(result.find('\\')!=std::string::npos || result.find('\0')!=std::string::npos)
        throw std::runtime_error("Legacy record uses unsupported escaping in " + key);
    return result;
}
using Digest=std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>;
Digest digestNew(){
    Digest ctx(EVP_MD_CTX_new(),EVP_MD_CTX_free);
    if(!ctx || EVP_DigestInit_ex(ctx.get(),EVP_sha256(),nullptr)!=1)
        throw std::runtime_error("OpenSSL SHA-256 init failed");
    return ctx;
}
void digestBytes(EVP_MD_CTX* ctx,const void* data,size_t length){
    if(EVP_DigestUpdate(ctx,data,length)!=1)throw std::runtime_error("SHA-256 update failed");
}
std::string legacySignature(const fs::path& directory){
    auto whole=digestNew();
    for(const auto& file:regularFiles(directory)){
        auto path=file.generic_string();
        digestBytes(whole.get(),path.data(),path.size());
        const unsigned char nul=0;
        digestBytes(whole.get(),&nul,1);
        auto content=digestNew();
        std::ifstream stream(directory/file,std::ios::binary);
        if(!stream)throw std::runtime_error("Could not hash icon: "+file.string());
        char buf[16384];
        while(stream.read(buf,sizeof(buf)) || stream.gcount())
            digestBytes(content.get(),buf,static_cast<size_t>(stream.gcount()));
        if(stream.bad())throw std::runtime_error("Could not finish hashing icon: "+file.string());
        unsigned char inner[EVP_MAX_MD_SIZE];unsigned int length=0;
        if(EVP_DigestFinal_ex(content.get(),inner,&length)!=1 || length!=32)
            throw std::runtime_error("SHA-256 inner digest failed");
        digestBytes(whole.get(),inner,length);
    }
    unsigned char result[EVP_MAX_MD_SIZE];unsigned int length=0;
    if(EVP_DigestFinal_ex(whole.get(),result,&length)!=1 || length!=32)
        throw std::runtime_error("SHA-256 final digest failed");
    const char digits[]="0123456789abcdef";std::string hex;
    for(unsigned int i=0;i<length;++i){hex+=digits[result[i]>>4];hex+=digits[result[i]&15];}
    return hex;
}
struct LegacyInfo {std::string previous;std::string record;std::string hash;};
LegacyInfo inspectLegacy(){
    noLinkParents(dest());noLinkParents(source());noLinkParents(state());noLinkParents(legacy());
    if(fs::exists(state()) || fs::is_symlink(fs::symlink_status(state())))
        throw std::runtime_error("Native icon-manager state already exists; refusing legacy adoption");
    if(!fs::is_regular_file(legacy()) || fs::is_symlink(fs::symlink_status(legacy())))
        throw std::runtime_error("Legacy icon record is missing or unsafe");
    if(!fs::is_directory(dest()) || fs::is_symlink(fs::symlink_status(dest())))
        throw std::runtime_error("Installed Kanso icon directory missing or unsafe");
    LegacyInfo info;info.record=readFile(legacy());
    info.previous=legacyField(info.record,"previous");
    info.hash=legacyField(info.record,"hash");
    const auto destination=legacyField(info.record,"destination");
    if(destination!=dest().string())throw std::runtime_error("Legacy destination does not match installed theme");
    if(info.hash.size()!=64 || !std::all_of(info.hash.begin(),info.hash.end(),[](char c){return (c>='0'&&c<='9')||(c>='a'&&c<='f');}))
        throw std::runtime_error("Invalid SHA-256 in legacy record");
    if(info.previous.empty() || info.previous=="Kanso")
        throw std::runtime_error("Invalid previous icon theme; manual recovery needed");
    if(selected()!="Kanso")throw std::runtime_error("KDE is no longer using Kanso icons; review settings first");
    if(legacySignature(dest())!=info.hash)
        throw std::runtime_error("Legacy icon SHA-256 mismatch; refusing adoption of changed files");
    // This is deliberately strict: an out-of-date source would not necessarily be harmful,
    // but must not be silently treated as the exact existing installation.
    if(!sameTree(source(),dest()))
        throw std::runtime_error("Installed icons differ from current source; refusing automatic adoption");
    return info;
}
void adoptLegacy(bool onlyCheck){
    auto info=inspectLegacy();
    std::cout<<"Legacy Kanso icons verified ("<<regularFiles(dest()).size()<<" files, SHA-256 matches).\n";
    std::cout<<"Previous KDE icon theme: "<<info.previous<<"\n";
    if(onlyCheck){std::cout<<"Read-only legacy adoption check passed; no KDE or files changed.\n";return;}
    auto stage=fs::path(state().string()+".adopting");
    noLinkParents(stage);
    if(fs::exists(stage)||fs::is_symlink(fs::symlink_status(stage)))
        throw std::runtime_error("Legacy adoption staging directory already exists");
    try {
        fs::create_directories(stage);
        fs::copy(dest(),stage/"snapshot",fs::copy_options::recursive);
        if(!sameTree(dest(),stage/"snapshot") || legacySignature(dest())!=info.hash)
            throw std::runtime_error("Installed icon theme changed while copying; not adopted");
        writeNew(stage/"previous",info.previous+"\n");
        writeNew(stage/"legacy-record-backup.json",info.record);
        writeNew(stage/"legacy-hash",info.hash+"\n");
        writeNew(stage/"installed","Kanso native icons adopted from Python manager v2.3\n");
        fs::rename(stage,state());
    } catch(...){
        std::error_code ec;fs::remove_all(stage,ec);
        throw;
    }
    // Keep the original record safely in native state; only unlink the old active record.
    // If unlinking fails, neither KDE selection nor icon files were modified.
    if(!fs::remove(legacy()))
        throw std::runtime_error("Native adoption state created, but legacy record remains; inspect before retrying");
    std::cout<<"Legacy icon manager adopted into C++20. Icon files and KDE selection unchanged.\n";
}
void returnLegacy(){
    noLinkParents(dest());noLinkParents(state());noLinkParents(legacy());
    if(!fs::is_regular_file(state()/"installed") || !fs::is_regular_file(state()/"legacy-record-backup.json") ||
       !fs::is_regular_file(state()/"legacy-hash") || !fs::is_directory(state()/"snapshot"))
        throw std::runtime_error("No complete adopted legacy icon state to return");
    if(fs::exists(legacy()) || fs::is_symlink(fs::symlink_status(legacy())))
        throw std::runtime_error("Legacy record already exists; refusing overwrite");
    auto data=readFile(state()/"legacy-record-backup.json");
    auto hash=readFile(state()/"legacy-hash");
    while(!hash.empty() && (hash.back()=='\n'||hash.back()=='\r'))hash.pop_back();
    if(legacyField(data,"hash")!=hash || legacyField(data,"destination")!=dest().string() ||
       legacySignature(dest())!=hash || !sameTree(dest(),state()/"snapshot"))
        throw std::runtime_error("Installed icons or adoption backup changed; refusing to restore legacy record");
    if(selected()!="Kanso")throw std::runtime_error("KDE icon selection changed; refusing to return legacy manager");
    writeNew(legacy(),data);
    fs::remove_all(state());
    std::cout<<"Legacy icon-manager record restored. Icon files and KDE selection unchanged.\n";
}
void statusIcons(){
    noLinkParents(dest());noLinkParents(state());noLinkParents(legacy());
    std::cout<<"Icon installation: "<<(fs::exists(dest())?"present":"absent")<<'\n';
    std::cout<<"Native manager: "<<(fs::is_regular_file(state()/"installed")?"installed":"not installed")<<'\n';
    std::cout<<"Legacy manager: "<<(fs::exists(legacy())?"present (do not overwrite)":"absent")<<'\n';
    std::cout<<"KDE icons: "<<selected()<<'\n';
}
void installIcons(){
    validateSource();noLinkParents(dest());noLinkParents(state());noLinkParents(legacy());
    if(fs::exists(dest())||fs::exists(state())||fs::exists(legacy()))
        throw std::runtime_error("Existing icon installation or manager state; refusing to overwrite");
    const auto previous=selected();
    if(previous.empty())throw std::runtime_error("Cannot record previous KDE icon theme (empty selection)");
    auto stage=dest().parent_path()/".Kanso-native-stage";
    if(fs::exists(stage)||fs::is_symlink(fs::symlink_status(stage)))throw std::runtime_error("Existing stage; refusing overwrite");
    noLinkParents(stage);fs::create_directories(stage.parent_path());
    fs::copy(source(),stage,fs::copy_options::recursive);
    try {
        if(!sameTree(source(),stage))throw std::runtime_error("Source copy mismatch");
        fs::create_directories(state());
        writeNew(state()/"previous",previous+"\n");
        fs::copy(stage,state()/"snapshot",fs::copy_options::recursive);
        fs::rename(stage,dest());
        setSelected("Kanso");
        writeNew(state()/"installed","Kanso native icons v2.2\n");
        maybeRefresh();
    } catch(...){
        std::error_code ec;fs::remove_all(stage,ec);
        // Leave backup and destination intact when a KDE operation failed.
        // Do not silently delete assets potentially already selected by Plasma.
        std::cerr<<"Kanso icons: incomplete installation; inspect "<<state()<<" and "<<dest()<<"\n";
        throw;
    }
    std::cout<<"Kanso icons installed; previous selection: "<<previous<<'\n';
}
void restoreIcons(){
    noLinkParents(dest());noLinkParents(state());noLinkParents(legacy());
    noLinkParents(state()/"installed");noLinkParents(state()/"snapshot");noLinkParents(state()/"previous");
    if(!fs::is_regular_file(state()/"installed")||!fs::is_directory(state()/"snapshot")||
       !fs::is_regular_file(state()/"previous"))
        throw std::runtime_error("No complete native icon installation record");
    if(!fs::is_directory(dest())||!sameTree(dest(),state()/"snapshot"))
        throw std::runtime_error("Installed icon files were changed; refusing removal");
    auto previous=readFile(state()/"previous");
    while(!previous.empty()&&(previous.back()=='\n'||previous.back()=='\r'))previous.pop_back();
    if(selected()=="Kanso")setSelected(previous);
    // Each icon file was compared byte-for-byte. Do not follow symlinks or remove modified files.
    fs::remove_all(dest());fs::remove_all(state());maybeRefresh();
    std::cout<<"Kanso native icon theme restored.\n";
}
}
int run_native_icons(const Words& args){
    if(args.size()!=1){std::cerr<<"Usage: kanso-native icons check|status|install|restore|adopt-check|adopt|return-legacy\n";return 2;}
    if(args[0]=="check"){validateSource();return 0;}
    if(args[0]=="status"){statusIcons();return 0;}
    if(args[0]=="adopt-check"){adoptLegacy(true);return 0;}
    if(args[0]=="adopt"){adoptLegacy(false);return 0;}
    if(args[0]=="return-legacy"){returnLegacy();return 0;}
    if(args[0]=="install"){installIcons();return 0;}
    if(args[0]=="restore"){restoreIcons();return 0;}
    std::cerr<<"Unknown icons action\n";return 2;
}
