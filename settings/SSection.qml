import QtQuick

// Small caps group title
SLabel {
    property string title
    text: App.lowerRice ? title.toLowerCase() : title.toUpperCase()
    color: App.dim
    font.pixelSize: 12
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
    topPadding: 18
}
