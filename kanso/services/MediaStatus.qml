import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Scope {
    id: root
    readonly property var player: {
        const players = Mpris.players.values
        for (const candidate of players) if (candidate.isPlaying) return candidate
        return players.length > 0 ? players[0] : null
    }
    readonly property bool available: player !== null
    readonly property bool playing: available && player.isPlaying
    readonly property string displayText: {
        if (!available) return ""
        if (player.trackArtist && player.trackTitle) return player.trackArtist + " · " + player.trackTitle
        return player.trackTitle || player.trackArtist || player.identity || "Media"
    }
    function togglePlaying() { if (available && player.canTogglePlaying) player.togglePlaying() }
    function next() { if (available && player.canGoNext) player.next() }
    function previous() { if (available && player.canGoPrevious) player.previous() }
}
