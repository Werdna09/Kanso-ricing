// Native Wayland window picker / dock debugger using KWin through kdotool.
// No Python, no shell interpolation, no window-title output in dock diagnostics.
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#include <chrono>
#include <poll.h>
#include <fcntl.h>
#include <cerrno>
#include <cctype>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>
#include <algorithm>
#include <stdexcept>
namespace kw {
using Args=std::vector<std::string>;
struct Result {int code;std::string output;};
static Result exec(const Args& args,const std::string& input="",int timeout=12){
    int toChild[2],fromChild[2];if(pipe(toChild)<0)throw std::runtime_error("pipe failed");
    if(pipe(fromChild)<0){close(toChild[0]);close(toChild[1]);throw std::runtime_error("pipe failed");}
    pid_t pid=fork();if(pid<0)throw std::runtime_error("fork failed");
    if(pid==0){dup2(toChild[0],STDIN_FILENO);dup2(fromChild[1],STDOUT_FILENO);
        close(toChild[0]);close(toChild[1]);close(fromChild[0]);close(fromChild[1]);
        std::vector<char*> av;for(const auto& s:args)av.push_back(const_cast<char*>(s.c_str()));av.push_back(nullptr);
        execvp(av[0],av.data());_exit(127);
    }
    close(toChild[0]);close(fromChild[1]);
    int flags=fcntl(fromChild[0],F_GETFL,0);if(flags>=0)fcntl(fromChild[0],F_SETFL,flags|O_NONBLOCK);
    flags=fcntl(toChild[1],F_GETFL,0);if(flags>=0)fcntl(toChild[1],F_SETFL,flags|O_NONBLOCK);
    size_t written=0;bool inputOpen=true,outputOpen=true,exited=false;int st=0;std::string out;
    auto end=std::chrono::steady_clock::now()+std::chrono::seconds(timeout);
    while(outputOpen||!exited){
        if(std::chrono::steady_clock::now()>end){kill(pid,SIGTERM);waitpid(pid,&st,0);
            if(inputOpen)close(toChild[1]);
            if(outputOpen)close(fromChild[0]);
            return {124,out};
        }
        if(inputOpen && written==input.size()){close(toChild[1]);inputOpen=false;}
        pollfd fds[2]={{fromChild[0],short(outputOpen?POLLIN:0),0},{toChild[1],short(inputOpen?POLLOUT:0),0}};
        if(poll(fds,2,50)<0 && errno!=EINTR){kill(pid,SIGTERM);waitpid(pid,&st,0);throw std::runtime_error("poll failed");}
        if(inputOpen && (fds[1].revents & POLLOUT)){
            const auto n=write(toChild[1],input.data()+written,input.size()-written);
            if(n>0)written+=size_t(n);
        }
        if(inputOpen && (fds[1].revents & (POLLHUP|POLLERR))){close(toChild[1]);inputOpen=false;}
        if(outputOpen&&(fds[0].revents&(POLLIN|POLLHUP))){
            char buf[2048];ssize_t n=read(fromChild[0],buf,sizeof(buf));
            if(n>0){if(out.size()+size_t(n)>1024*1024){kill(pid,SIGTERM);waitpid(pid,&st,0);close(fromChild[0]);if(inputOpen)close(toChild[1]);throw std::runtime_error("helper output exceeds 1 MiB");}out.append(buf,size_t(n));}
            else if(n==0){close(fromChild[0]);outputOpen=false;}
        }
        if(!exited){pid_t w=waitpid(pid,&st,WNOHANG);if(w==pid)exited=true;else if(w<0){exited=true;st=0;}}
    }
    if(inputOpen)close(toChild[1]);
    return {WIFEXITED(st)?WEXITSTATUS(st):128,out};
}
static std::string clean(std::string s){for(char& c:s)if((unsigned char)c<32||c==127)c=' ';return s;}
static std::vector<Args> rows(const std::string& text){
    std::vector<Args> result;std::istringstream input(text);std::string line;
    while(std::getline(input,line)){
        Args fields;std::istringstream s(line);std::string f;while(std::getline(s,f,'\t'))fields.push_back(clean(f));
        if(fields.size()==4&&fields[0].size()>0)result.push_back(std::move(fields));
        if(result.size()>1000)throw std::runtime_error("too many windows");
    }
    return result;
}
}
int run_native_windows(const std::vector<std::string>& args){
    if(args.size()>1 || (args.size()==1&&args[0]!="--dock-debug")){std::cerr<<"Usage: kanso-native windows [--dock-debug]\n";return 2;}
    const bool debug=!args.empty();
    // Escaping prevents tab/newline data from corrupting line boundaries.
    const std::string js="var out=[];var ws=workspace.stackingOrder;function c(s){return String(s||'').replace(/[\\t\\r\\n]/g,' ');}" \
     "for(var i=0;i<ws.length;i++){var w=ws[i];if(w.deleted||w.skipTaskbar||w.specialWindow||(!w.normalWindow&&!w.dialog))continue;" \
     "out.push([c(w.internalId),c(w.resourceClass||w.desktopFileName||''),c(w.caption||''),w.active?'1':'0'].join('\\t'));}" \
     "output_result(out.join('\\n'));";
    try{
        const auto info=kw::exec({"kdotool","kwinscript","--inline",js});if(info.code)throw std::runtime_error("kdotool failed");
        const auto items=kw::rows(info.output);if(debug){
            std::cout<<"Kanso dock diagnostics (window captions hidden):\n";
            for(const auto& r:items)std::cout<<"ID "<<r[0]<<" app="<<r[1]<<"\n";
            return 0;
        }
        if(items.empty()){std::cout<<"No windows found\n";return 0;}
        const char* home=getenv("HOME");if(!home||!*home)throw std::runtime_error("HOME missing");
        const char* env=getenv("KANSO_ROOT");const auto root=std::filesystem::path(env&&*env?env:std::string(home)+"/Rice/kanso");
        const auto theme=root/"config/rofi/kanso.rasi";if(!std::filesystem::is_regular_file(theme))throw std::runtime_error("missing rofi theme");
        std::string labels;for(auto& r:items){labels+=(r[3]=="1"?"● ":"  ")+r[1]+"  ·  "+r[2]+"\n";}
        const auto choice=kw::exec({"rofi","-no-config","-theme",theme.string(),"-dmenu","-no-custom","-format","i","-p","Windows"},labels,300);
        if(choice.code==1)return 0;
        if(choice.code)return choice.code;
        const auto first=choice.output.find_first_not_of(" \r\n\t");if(first==std::string::npos)return 1;
        const auto text=choice.output.substr(first);if(!std::all_of(text.begin(),text.end(),[](char c){return (c>='0'&&c<='9')||c=='\r'||c=='\n';}))return 2;
        const unsigned long idx=std::stoul(text);if(idx>=items.size())return 2;
        const auto &id=items[idx][0];if(id.empty()||id.size()>128||!std::all_of(id.begin(),id.end(),[](char c){return std::isalnum((unsigned char)c)||c=='-'||c=='_';}))return 2;
        return kw::exec({"kdotool","windowactivate",id}).code;
    }catch(const std::exception& e){std::cerr<<"Kanso windows: "<<e.what()<<"\n";return 2;}
}
