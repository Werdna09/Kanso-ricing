// Kanso V3.2: canonical application identity shared by KWin tracker and dock.
// QML JavaScript: no imports and no workstation-specific paths.
function normalize(raw) {
    var s = String(raw || "").trim().toLowerCase();
    s = s.replace(/\\/g, "/");
    s = s.substring(s.lastIndexOf("/") + 1);
    if (s.endsWith(".desktop")) s = s.slice(0, -8);
    return s;
}
function canonical(raw) {
    var id = normalize(raw);
    if (!id) return "";
    // KWin resourceClass, .desktop ID and installed command can differ.
    var groups = {
        "firefox": ["firefox", "firefox-esr", "firefox-bin", "org.mozilla.firefox", "firefoxdeveloperedition"],
        "dolphin": ["dolphin", "org.kde.dolphin"],
        "alacritty": ["alacritty", "org.alacritty.alacritty"],
        "code": ["code", "code-oss", "code-url-handler", "code-oss-url-handler",
                 "visual-studio-code", "com.visualstudio.code", "com.visualstudio.code-oss",
                 "vscode", "vscode-oss", "code-insiders", "com.visualstudio.code.insiders"],
        "codium": ["codium", "vscodium", "vscodium-url-handler", "com.vscodium.codium"],
        "neovim": ["nvim", "neovim", "org.neovim.nvim", "nvim-qt"],
        "discord": ["discord", "com.discordapp.discord", "discord-canary"],
        "spotify": ["spotify", "spotify-client", "com.spotify.client"],
        "steam": ["steam", "steam-native", "com.valvesoftware.steam"],
        "konsole": ["konsole", "org.kde.konsole"]
    };
    for (var key in groups) {
        if (groups[key].indexOf(id) !== -1) return key;
    }
    return id;
}
function isKnown(raw) {
    var id = canonical(raw);
    return ["firefox", "dolphin", "alacritty", "code", "codium", "neovim",
            "discord", "spotify", "steam", "konsole"].indexOf(id) !== -1;
}
function windowKey(row) {
    var desktop = canonical(row.desktopFile);
    var resource = canonical(row.resourceClass);
    var name = canonical(row.resourceName);
    // Prefer a well-known identifier when the desktop file and resource class disagree.
    if (isKnown(desktop)) return desktop;
    if (isKnown(resource)) return resource;
    if (isKnown(name)) return name;
    return desktop || resource || name || normalize(row.caption) || "unknown-app";
}
function matches(app, target) {
    var key = canonical(target);
    return canonical(app.key) === key || canonical(app.desktopFile) === key ||
           canonical(app.resourceClass) === key || canonical(app.resourceName) === key;
}
