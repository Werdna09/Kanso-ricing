// Kanso Native Theme — C++20. No Python, no shell evaluation and no sudo.
// Bridges existing Kanso-managed manifests without discarding their backups.
#include <algorithm>
#include <cctype>
#include <chrono>
#include <csignal>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <optional>
#include <regex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <sys/wait.h>
#include <unistd.h>
namespace kt {
namespace fs=std::filesystem;
using Args=std::vector<std::string>;
static fs::path home() {const char* p=getenv("HOME");if(!p||!*p)throw std::runtime_error("HOME missing");return p;}
static fs::path root() {const char* p=getenv("KANSO_ROOT");return p&&*p?fs::path(p):home()/"Rice/kanso";}
static fs::path stateRoot() {const char* p=getenv("XDG_STATE_HOME");return p&&*p?fs::path(p):home()/".local/state";}
static bool regular(const fs::path& p) {return !fs::is_symlink(fs::symlink_status(p))&&fs::is_regular_file(p);}
static std::string read(const fs::path& p) {std::ifstream f(p,std::ios::binary);if(!f)throw std::runtime_error("Cannot read "+p.string());std::ostringstream s;s<<f.rdbuf();return s.str();}
static void guard(const fs::path& path) {
    const auto h=fs::weakly_canonical(home());
    auto p=fs::absolute(path).lexically_normal();
    if(p==h || (p.string().rfind(h.string()+"/",0)!=0))throw std::runtime_error("Outside HOME: "+p.string());
    for(auto cur=p;cur!=h;cur=cur.parent_path()) {
        if(fs::is_symlink(fs::symlink_status(cur)))throw std::runtime_error("Symlink is unsafe: "+cur.string());
        if(cur==cur.root_path())throw std::runtime_error("Unsafe path: "+p.string());
    }
}
static std::string jsonEscape(const std::string& s) {
    std::string out;
    for(char c:s) {if(c=='"'||c=='\\')out+='\\';if(c=='\n')out+="\\n";else if(c=='\r')out+="\\r";else if(c=='\t')out+="\\t";else out+=c;}
    return out;
}
// Read JSON string values without interpreting regex metacharacters in user paths.
static std::optional<std::string> stringField(const std::string& s,const std::string& key) {
    auto start=s.find('"'+jsonEscape(key)+'"');
    while(start!=std::string::npos) {
        size_t i=start+jsonEscape(key).size()+2;
        while(i<s.size()&&std::isspace((unsigned char)s[i]))i++;
        if(i<s.size()&&s[i++]==':') {
            while(i<s.size()&&std::isspace((unsigned char)s[i]))i++;
            if(i<s.size()&&s[i]=='"') {
                i++;std::string v;bool escaped=false;
                for(;i<s.size();++i){char c=s[i];if(escaped){switch(c){case 'n':v+='\n';break;case 'r':v+='\r';break;case 't':v+='\t';break;default:v+=c;}escaped=false;continue;}if(c=='\\'){escaped=true;continue;}if(c=='"')return v;v+=c;}
            }
        }
        start=s.find('"'+jsonEscape(key)+'"',start+1);
    }
    return std::nullopt;
}
static std::string replaceField(std::string s,const std::string& key,const std::string& val) {
    const auto marker='"'+jsonEscape(key)+'"';auto i=s.find(marker);
    if(i==std::string::npos)throw std::runtime_error("Missing JSON field: "+key);
    i+=marker.size();while(i<s.size()&&std::isspace((unsigned char)s[i]))i++;
    if(i==s.size()||s[i++]!=':')throw std::runtime_error("Malformed JSON field: "+key);
    while(i<s.size()&&std::isspace((unsigned char)s[i]))i++;
    if(i==s.size()||s[i]!='"')throw std::runtime_error("Expected JSON string: "+key);
    auto begin=i++;bool escaped=false;
    for(;i<s.size();i++){if(escaped){escaped=false;continue;}if(s[i]=='\\'){escaped=true;continue;}if(s[i]=='"'){s.replace(begin,i-begin+1,'"'+jsonEscape(val)+'"');return s;}}
    throw std::runtime_error("Unclosed JSON string");
}
static size_t matchingObject(const std::string& s,size_t begin){
    if(begin>=s.size()||s[begin]!='{')throw std::runtime_error("Expected JSON object");
    int depth=0;bool quoted=false,escaped=false;
    for(auto i=begin;i<s.size();++i){char c=s[i];if(quoted){if(escaped)escaped=false;else if(c=='\\')escaped=true;else if(c=='"')quoted=false;continue;}if(c=='"'){quoted=true;continue;}if(c=='{')depth++;if(c=='}'&&!--depth)return i;}
    throw std::runtime_error("Malformed JSON object");
}
static size_t managedEntryPos(const std::string& doc,const fs::path& target){
    auto files=doc.find("\"files\"");
    if(files==std::string::npos)throw std::runtime_error("Missing files map");
    auto map=doc.find('{',files+7);
    if(map==std::string::npos)throw std::runtime_error("Missing files entries");
    const auto marker='"'+jsonEscape(target.string())+'"';
    size_t pos=doc.find(marker,map+1);
    while(pos!=std::string::npos){
        size_t after=pos+marker.size();
        while(after<doc.size()&&std::isspace((unsigned char)doc[after]))after++;
        if(after<doc.size()&&doc[after]==':')return pos;
        pos=doc.find(marker,pos+marker.size());
    }
    throw std::runtime_error("File is not managed: "+target.string());
}
static std::string updateManagedHash(const std::string& manifest,const fs::path& target,const std::string& field,const std::string& hash){
    // Manifests use full absolute file paths as keys in the `files` map.
    const auto marker='"'+jsonEscape(target.string())+'"';auto i=managedEntryPos(manifest,target);
    i=manifest.find(':',i+marker.size());
    if(i==std::string::npos)throw std::runtime_error("Missing entry colon");
    i=manifest.find('{',i+1);if(i==std::string::npos)throw std::runtime_error("Missing managed entry");
    auto end=matchingObject(manifest,i);auto body=manifest.substr(i,end-i+1);
    if(!stringField(body,field))throw std::runtime_error("Missing managed checksum field "+field);
    body=replaceField(body,field,hash);
    auto output=manifest;output.replace(i,end-i+1,body);return output;
}
static void writeAtomically(const fs::path& p,const std::string& data){
    guard(p);if(fs::exists(p)&&!regular(p))throw std::runtime_error("Non-regular target: "+p.string());
    fs::create_directories(p.parent_path());
    auto temp=p;temp+=".kanso-native-new";
    if(fs::exists(temp)||fs::is_symlink(fs::symlink_status(temp)))throw std::runtime_error("Staging file exists: "+temp.string());
    try{
        {std::ofstream out(temp,std::ios::binary);if(!out)throw std::runtime_error("Cannot create "+temp.string());out<<data;out.flush();if(!out)throw std::runtime_error("Write failed "+temp.string());}
        if(fs::exists(p))fs::permissions(temp,fs::status(p).permissions());
        fs::rename(temp,p);
    }catch(...){if(fs::exists(temp))fs::remove(temp);throw;}
}
static bool available(const std::string& exe){
    const char* path=getenv("PATH");std::istringstream paths(path?path:"/usr/bin:/bin");std::string part;
    while(std::getline(paths,part,':')){if(part.empty())part=".";if(access((fs::path(part)/exe).c_str(),X_OK)==0)return true;}return false;
}
static std::string command(const Args& args,int timeout=25){
    if(args.empty())throw std::runtime_error("Empty command");
    int pipes[2];if(pipe(pipes)!=0)throw std::runtime_error("pipe failed");
    pid_t pid=fork();if(pid<0)throw std::runtime_error("fork failed");
    if(pid==0){close(pipes[0]);dup2(pipes[1],STDOUT_FILENO);dup2(pipes[1],STDERR_FILENO);close(pipes[1]);std::vector<char*> av;for(auto &a:args)av.push_back(const_cast<char*>(a.c_str()));av.push_back(nullptr);execvp(av.front(),av.data());_exit(127);}
    close(pipes[1]);std::string result; char buffer[4096];int status=0;
    // Commands used here emit short bounded output. Drain before waiting to avoid deadlock.
    auto start=std::chrono::steady_clock::now();
    while(true){
        fd_set fds;FD_ZERO(&fds);FD_SET(pipes[0],&fds);timeval tv{0,150000};int ret=select(pipes[0]+1,&fds,nullptr,nullptr,&tv);
        if(ret>0){auto n=::read(pipes[0],buffer,sizeof(buffer));if(n<=0)break;if(result.size()+size_t(n)>2*1024*1024){kill(pid,SIGTERM);close(pipes[0]);waitpid(pid,&status,0);throw std::runtime_error("Command output too large");}result.append(buffer,n);}
        if(std::chrono::steady_clock::now()-start>std::chrono::seconds(timeout)){kill(pid,SIGTERM);close(pipes[0]);waitpid(pid,&status,0);throw std::runtime_error("Command timeout: "+args[0]);}
    }
    close(pipes[0]);waitpid(pid,&status,0);if(!WIFEXITED(status)||WEXITSTATUS(status)!=0)throw std::runtime_error(args[0]+" failed: "+result);
    return result;
}
static std::string sha(const fs::path& p){
    if(!regular(p))throw std::runtime_error("Not a regular file: "+p.string());
    auto s=command({"sha256sum","--",p.string()},10);
    auto pos=s.find_first_of(" \n");if(pos!=64)throw std::runtime_error("Invalid sha256sum output");return s.substr(0,64);
}
static std::string hashText(const std::string& data){
    // Use a temporary file in the private state directory; not /tmp.
    auto dir=stateRoot()/"kanso-native-theme";guard(dir);fs::create_directories(dir);
    auto file=dir/("hash-"+std::to_string(getpid()));
    writeAtomically(file,data);try{auto value=sha(file);fs::remove(file);return value;}catch(...){fs::remove(file);throw;}
}
struct Write {fs::path path;std::string oldText,newText;};
static void applyWrites(const std::vector<Write>& changes){
    for(auto& c:changes){guard(c.path);if(!regular(c.path)||read(c.path)!=c.oldText)throw std::runtime_error("External modification: "+c.path.string());}
    size_t done=0;
    try{for(;done<changes.size();done++)writeAtomically(changes[done].path,changes[done].newText);}
    catch(...){while(done>0){--done;writeAtomically(changes[done].path,changes[done].oldText);}throw;}
}
static bool hasLandscape(){
    auto file=home()/".config/plasma-org.kde.plasma.desktop-appletsrc";
    if(!regular(file))return false;
    std::istringstream lines(read(file));std::string line;
    while(std::getline(lines,line)){
        auto left=line.find_first_not_of(" \t");if(left==std::string::npos)continue;
        auto right=line.find_last_not_of(" \t\r");
        if(line.substr(left,right-left+1)=="wallpaperplugin=org.kanso.livinglandscape")return true;
    }
    return false;
}
static void firefox(const std::string& mode){
    const auto manifest=stateRoot()/"kanso-standalone/app-themes/firefox.json";
    if(!fs::exists(manifest))return;
    guard(manifest);if(!regular(manifest))throw std::runtime_error("Unsafe Firefox manifest");
    auto doc=read(manifest);auto profile=stringField(doc,"profile");if(!profile)throw std::runtime_error("Firefox profile missing from manifest");
    auto file=fs::path(*profile)/"chrome/kanso-vars.css";guard(file);
    if(!regular(file))throw std::runtime_error("Firefox managed CSS missing");
    auto index=managedEntryPos(doc,file);
    auto expected=stringField(doc.substr(index),"after_sha256");
    if(!expected || sha(file)!=*expected)throw std::runtime_error("Firefox CSS changed externally; preserving it");
    auto source=root()/"config/firefox"/("kanso-vars-"+mode+".css");if(!regular(source))throw std::runtime_error("Missing Firefox colors "+source.string());
    auto updated=read(source), newDigest=sha(source);
    auto result=updateManagedHash(doc,file,"after_sha256",newDigest);
    applyWrites({{file,read(file),updated},{manifest,doc,result}});
    std::cout<<"Firefox palette prepared (restart Firefox if necessary)\n";
}
static std::string replaceVSCodeTheme(const std::string& old,const std::string& theme){
    // The installed extension already inserts the setting. Only touch that specific value.
    const std::regex pattern(R"("workbench\.colorTheme"\s*:\s*"([^"\\]|\\.)*")");
    std::smatch match;
    if(!std::regex_search(old,match,pattern))throw std::runtime_error("VS Code theme entry missing; preserving settings");
    if(std::regex_search(match.suffix().str(),pattern))throw std::runtime_error("Ambiguous VS Code theme entries");
    // Reject a commented entry; a new configuration needs a separate intentional install.
    auto line=old.rfind('\n',size_t(match.position()));line=(line==std::string::npos?0:line+1);
    auto prefix=old.substr(line,size_t(match.position())-line);
    if(prefix.find("//")!=std::string::npos||prefix.find("/*")!=std::string::npos)throw std::runtime_error("Commented VS Code theme entry");
    auto result=old;
    result.replace(size_t(match.position()),size_t(match.length()),"\"workbench.colorTheme\": \""+theme+"\"");
    return result;
}
static void devTheme(const std::string& mode){
    const auto manifest=stateRoot()/"kanso-dev-finish/manifest.json";
    if(!fs::exists(manifest))return;
    guard(manifest);if(!regular(manifest))throw std::runtime_error("Unsafe editor theme manifest");
    const auto doc=read(manifest);
    auto target=home()/".config/alacritty/kanso-colors.toml";
    auto palette=root()/"dev-theme/payload/alacritty"/(mode+".toml");
    if(!regular(palette))throw std::runtime_error("Missing editor palette "+palette.string());
    if(!regular(target))throw std::runtime_error("Missing managed Alacritty colors");
    // Refuse to modify any file without matching the old manager's checksum.
    auto pos=managedEntryPos(doc,target);
    auto oldHash=stringField(doc.substr(pos),"sha");
    if(!oldHash||sha(target)!=*oldHash)throw std::runtime_error("Alacritty colors changed externally");
    std::vector<Write> writes{{target,read(target),read(palette)}};
    auto newManifest=updateManagedHash(doc,target,"sha",sha(palette));
    const auto settings=stringField(doc,"settings");
    if(settings && !settings->empty()){
        auto vscode=fs::path(*settings);guard(vscode);
        if(!regular(vscode))throw std::runtime_error("VS Code settings missing");
        auto index=managedEntryPos(doc,vscode);
        auto digest=stringField(doc.substr(index),"sha");
        if(!digest||sha(vscode)!=*digest)throw std::runtime_error("VS Code settings modified externally");
        auto before=read(vscode), after=replaceVSCodeTheme(before,mode=="day"?"Kanso Day":"Kanso Night");
        newManifest=updateManagedHash(newManifest,vscode,"sha",hashText(after));
        writes.push_back({vscode,before,after});
    }
    writes.push_back({manifest,doc,newManifest});applyWrites(writes);
    std::cout<<"Developer themes prepared: "<<mode<<"\n";
}
static void lockscreen(const std::string& mode){
    auto manifest=stateRoot()/"kanso-start-lock/lockscreen.json";
    if(!fs::exists(manifest))return;
    guard(manifest);if(!regular(manifest))throw std::runtime_error("Unsafe lockscreen manifest");
    auto meta=read(manifest);auto cfgName=stringField(meta,"config");auto digest=stringField(meta,"last_hash");
    if(!cfgName||!digest)throw std::runtime_error("Incomplete lockscreen state");
    fs::path config=*cfgName;guard(config);
    if(!regular(config)||sha(config)!=*digest)throw std::runtime_error("KDE lock screen modified externally");
    auto wallpaper=root()/"assets"/(mode=="night"?"kanso-wallpaper-night.png":"kanso-wallpaper.png");
    if(!regular(wallpaper))throw std::runtime_error("Lock screen wallpaper missing");
    if(!available("kwriteconfig6"))throw std::runtime_error("kwriteconfig6 missing");
    const auto old=read(config);
    std::string uri="file://"+wallpaper.string();
    try {
        command({"kwriteconfig6","--file",config.string(),"--group","Greeter","--key","WallpaperPlugin","org.kde.image"},10);
        for(const std::string key:{"Image","PreviewImage"})
            command({"kwriteconfig6","--file",config.string(),"--group","Greeter","--group","Wallpaper","--group","org.kde.image","--group","General","--key",key,uri},10);
        auto updated=replaceField(replaceField(meta,"last_hash",sha(config)),"mode",mode);
        writeAtomically(manifest,updated);
        std::cout<<"Kanso lock screen: "<<mode<<"\n";
    }catch(...){writeAtomically(config,old);throw;}
}
static void scheme(const std::string& mode){
    const auto name=mode=="night"?"KansoNight":"KansoDaylight";
    const auto config=root()/"config/kde"/(std::string(name)+".colors");
    if(!regular(config))throw std::runtime_error("Missing color scheme: "+config.string());
    auto dest=home()/".local/share/color-schemes"/(std::string(name)+".colors");guard(dest);
    if(fs::exists(dest)){
        if(!regular(dest))throw std::runtime_error("Unsafe color scheme file");
        if(read(dest).find("Kanso ")==std::string::npos)throw std::runtime_error("Refusing to replace non-Kanso scheme");
    }
    if(!fs::exists(dest)||read(dest)!=read(config))writeAtomically(dest,read(config));
    if(available("plasma-apply-colorscheme"))command({"plasma-apply-colorscheme",name},25);
    if(!hasLandscape()){
        auto wallpaper=root()/"assets"/(mode=="night"?"kanso-wallpaper-night.png":"kanso-wallpaper.png");
        if(regular(wallpaper)&&available("plasma-apply-wallpaperimage"))command({"plasma-apply-wallpaperimage",wallpaper.string()},25);
    }
    if(available("alacritty")){
        std::string bg=mode=="night"?"#152C34":"#1D3D46";
        std::string fg=mode=="night"?"#F0E3CB":"#F7E9C9";
        try{command({"alacritty","msg","config","-w","-1","colors.primary.background=\""+bg+"\"","colors.primary.foreground=\""+fg+"\""},4);}
        catch(const std::exception& ex){std::cerr<<"Alacritty IPC warning: "<<ex.what()<<'\n';}
    }
}
static int run(const Args& args){
    if(args.size()==1&&args[0]=="--check"){
        for(const std::string mode:{"day","night"}){
            const auto name=mode=="day"?"KansoDaylight":"KansoNight";
            if(!regular(root()/"config/kde"/(std::string(name)+".colors")))throw std::runtime_error("Missing color scheme: "+std::string(name));
            if(!regular(root()/"assets"/(mode=="day"?"kanso-wallpaper.png":"kanso-wallpaper-night.png")))throw std::runtime_error("Missing fallback wallpaper");
        }
        std::cout<<"Kanso Native Theme: assets OK; no settings changed\n";return 0;
    }
    if(args.size()!=2||args[0]!="--apply"||(args[1]!="day"&&args[1]!="night")){
        std::cerr<<"Usage: kanso-native theme --check | --apply day|night\n";return 2;
    }
    const auto& mode=args[1];
    // Preserve the established mode even if an optional app integration is invalid.
    scheme(mode);
    for(auto func:{&firefox,&devTheme,&lockscreen}){
        try{func(mode);}catch(const std::exception& ex){std::cerr<<"Kanso optional theme warning: "<<ex.what()<<'\n';}
    }
    std::cout<<"Kanso native mode: "<<mode<<'\n';return 0;
}
} // namespace kt
int run_native_theme(const std::vector<std::string>& args){try{return kt::run(args);}catch(const std::exception& e){std::cerr<<"Kanso Native Theme: "<<e.what()<<'\n';return 2;}}
