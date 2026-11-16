import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property int volume: available ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: available && sink.audio.muted
    readonly property var outputs: Pipewire.nodes.values.filter(node => !node.isStream && node.isSink && node.audio !== null)
    readonly property var inputs: Pipewire.nodes.values.filter(node => !node.isStream && !node.isSink && node.audio !== null)
    PwObjectTracker { objects: [root.sink, root.source] }
    function setVolume(value) { if (available) sink.audio.volume = Math.max(0, Math.min(1, value)) }
    function increase() { if (available) setVolume(sink.audio.volume + .05) }
    function decrease() { if (available) setVolume(sink.audio.volume - .05) }
    function toggleMute() { if (available) sink.audio.muted = !sink.audio.muted }
    function chooseOutput(node) { if (node) Pipewire.preferredDefaultAudioSink = node }
    function chooseInput(node) { if (node) Pipewire.preferredDefaultAudioSource = node }
    readonly property bool microphoneAvailable: source !== null && source.audio !== null
    readonly property bool microphoneMuted: microphoneAvailable && source.audio.muted
    function toggleMicrophone() { if (microphoneAvailable) source.audio.muted = !source.audio.muted }
}
