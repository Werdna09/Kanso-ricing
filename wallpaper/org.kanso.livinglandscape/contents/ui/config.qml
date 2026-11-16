import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    property var configDialog
    property var wallpaperConfiguration
    property var parentLayout
    property var screenSize
    property alias formLayout: formLayout
    property int cfg_SlideDuration: 850
    property int cfg_SlideDurationDefault: 850
    property string cfg_AppearanceOverride: "system"
    property string cfg_AppearanceOverrideDefault: "system"

    Kirigami.FormLayout {
        id: formLayout
        Layout.fillWidth: true
        QQC2.ComboBox {
            id: appearanceBox
            Kirigami.FormData.label: "Vzhled panoramatu:"
            model: [
                {text: "Podle režimu KDE / Kanso", value: "system"},
                {text: "Vždy den", value: "day"},
                {text: "Vždy noc", value: "night"}
            ]
            textRole: "text"
            currentIndex: root.cfg_AppearanceOverride === "night" ? 2 :
                          root.cfg_AppearanceOverride === "day" ? 1 : 0
            onActivated: root.cfg_AppearanceOverride = model[currentIndex].value
        }
        QQC2.SpinBox {
            Kirigami.FormData.label: "Přejezd panoramatu (ms):"
            from: 0; to: 3000; stepSize: 50
            value: root.cfg_SlideDuration
            onValueModified: root.cfg_SlideDuration = value
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Voda, mlha, lístky a náhodné animace byly odstraněny. "
                + "Dvě podoby jediné krajiny se přepínají společně s barevným režimem KDE. "
                + "Původní přejezd KWin Slide zůstává zachovaný."
        }
    }
}
