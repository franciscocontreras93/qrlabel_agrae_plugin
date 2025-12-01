import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

import Theme
import org.qfield
import org.qgis

// Capa JS que envuelve a qrcode.js
import "qrcode_qml.js" as QRLib

Item {
    id: root

    property var mainWindow: iface.mainWindow()

    // Estado del QR
    property string codeText: ""
    property var qrMatrix: []
    property int qrSize: 0

    // Al cargar el plugin, añadimos el botón a la toolbar de plugins
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(qrButton)
    }

    // === Botón flotante en la barra de plugins (como en el reloader) ===
    QfToolButton {
        id: qrButton
        iconSource: "icon.svg"       // icono en la carpeta del plugin
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true

        onClicked: {
            qrDialog.open()
        }

        onPressAndHold: {
            mainWindow.displayToast(
                qsTr("aGrae QR Label: genera un código QR y una etiqueta PNG lista para imprimir.")
            )
        }
    }

    // === Diálogo principal para generar y guardar el QR ===
    Dialog {
        id: qrDialog
        parent: mainWindow.contentItem
        visible: false
        modal: true
        font: Theme.defaultFont
        standardButtons: Dialog.Close
        title: qsTr("Imprimir etiqueta QR")

        x: (mainWindow.width - width) / 2
        y: (mainWindow.height - height) / 2

        contentItem: ColumnLayout {
            spacing: 10
            anchors.margins: 12

            Label {
                text: qsTr("Código de la etiqueta")
                font.bold: true
                wrapMode: Text.Wrap
            }

            TextField {
                id: codeField
                Layout.fillWidth: true
                text: root.codeText
                placeholderText: qsTr("Ej: C025-1234")
                onTextChanged: root.codeText = text
            }

            Button {
                text: qsTr("Generar QR")
                Layout.fillWidth: true
                enabled: root.codeText.length > 0

                onClicked: {
                    var res = QRLib.generateMatrixForQml(root.codeText)
                    root.qrMatrix = res.matrix
                    root.qrSize = res.size
                    qrCanvas.requestPaint()
                }
            }

            // Contenedor para el QR (lo usaremos luego para grabToImage)
            Item {
                id: qrContainer
                Layout.alignment: Qt.AlignHCenter
                width: 240
                height: 240

                Canvas {
                    id: qrCanvas
                    anchors.fill: parent

                    onPaint: {
                        if (!root.qrMatrix || root.qrSize <= 0)
                            return

                        var ctx = getContext("2d")
                        ctx.reset()

                        // Fondo blanco
                        ctx.fillStyle = "#ffffff"
                        ctx.fillRect(0, 0, width, height)

                        var moduleSize = Math.min(width, height) / root.qrSize
                        ctx.fillStyle = "#000000"

                        for (var y = 0; y < root.qrSize; y++) {
                            for (var x = 0; x < root.qrSize; x++) {
                                if (root.qrMatrix[y][x]) {
                                    ctx.fillRect(
                                        x * moduleSize,
                                        y * moduleSize,
                                        moduleSize,
                                        moduleSize
                                    )
                                }
                            }
                        }
                    }
                }
            }

            Button {
                text: qsTr("Guardar PNG y abrir para imprimir")
                Layout.fillWidth: true
                enabled: root.qrSize > 0

                onClicked: {
                    qrContainer.grabToImage(function(result) {
                        if (!result || !result.saveToFile)
                            return

                        // Carpeta donde guardar las etiquetas
                        var dir
                        if (qgisProject && qgisProject.homePath) {
                            dir = qgisProject.homePath + "/qr_labels"
                        } else {
                            dir = "/sdcard/QField/qr_labels"
                        }

                        // Crear carpeta si FileUtils existe
                        if (typeof FileUtils !== "undefined" && FileUtils.mkpath) {
                            FileUtils.mkpath(dir)
                        }

                        var safeCode = root.codeText.replace(/[^a-zA-Z0-9_\\-]/g, "_")
                        var filename = dir + "/label_" + safeCode + ".png"

                        var ok = result.saveToFile(filename, "png")
                        if (ok) {
                            Qt.openUrlExternally("file://" + filename)
                            mainWindow.displayToast(
                                qsTr("Etiqueta guardada en %1").arg(filename)
                            )
                        } else {
                            console.log("No se pudo guardar la imagen QR en " + filename)
                            mainWindow.displayToast(
                                qsTr("Error al guardar la etiqueta.")
                            )
                        }
                    })
                }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pointSize: 10
                opacity: 0.7
                text: qsTr("La imagen se guarda en /qr_labels dentro de la carpeta del proyecto (o /sdcard/QField/qr_labels).")
            }
        }
    }
}
