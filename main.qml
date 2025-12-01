// main.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

import org.qfield 1.0
import org.qgis 1.0
import Theme 1.0

// Utilidades de fichero (en QField suelen estar disponibles como FileUtils)
import "qrcode_qml.js" as QRLib

Item {
    id: pluginRoot

    // QField nos inyecta "iface" en el contexto del plugin
    // (estilo a los ejemplos oficiales de QField)
    property var mainWindow: iface.mainWindow()
    property var dashBoard: iface.findItemByObjectName("dashBoard")

    // Estado básico
    property string codeText: ""
    property var qrMatrix: []
    property int qrSize: 0

    // Botón en la toolbar de plugins
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(qrButton)
    }

    // Botón que aparece en la barra de herramientas de QField
    ToolButton {
        id: qrButton
        icon.source: Theme.getThemeIcon("mIconBarcode")

        onPressed: tooltipText.visible = true
        onReleased: tooltipText.visible = false
    }

    Text {
        id: tooltipText
        text: "Generar etiqueta QR"
        visible: false
        anchors.top: qrButton.bottom
        anchors.horizontalCenter: qrButton.horizontalCenter
        color: "white"
        background: Rectangle { color: "black"; radius: 4 }
    }


    // Diálogo principal del plugin
    Dialog {
        id: qrDialog
        modal: true
        title: qsTr("Imprimir etiqueta QR")
        standardButtons: Dialog.Close
        x: (parent ? parent.width : 400) / 2 - width / 2
        y: (parent ? parent.height : 400) / 2 - height / 2

        contentItem: Column {
            spacing: 8
            padding: 12

            Text {
                text: qsTr("Código de la etiqueta")
                font.bold: true
            }

            TextField {
                id: codeField
                text: pluginRoot.codeText
                placeholderText: qsTr("Ej: C025-1234")
                onTextChanged: pluginRoot.codeText = text
                width: 260
            }

            Button {
                text: qsTr("Generar QR")
                enabled: pluginRoot.codeText.length > 0
                onClicked: {
                    var res = QRLib.generateMatrixForQml(pluginRoot.codeText)
                    pluginRoot.qrMatrix = res.matrix
                    pluginRoot.qrSize = res.size
                    qrCanvas.requestPaint()
                }
            }

            // Contenedor del QR (nos servirá para grabToImage)
            Item {
                id: qrContainer
                width: 240
                height: 240
                anchors.horizontalCenter: parent.horizontalCenter

                Canvas {
                    id: qrCanvas
                    anchors.fill: parent

                    onPaint: {
                        if (!pluginRoot.qrMatrix || pluginRoot.qrSize <= 0)
                            return

                        var ctx = getContext("2d")
                        ctx.reset()

                        // Fondo blanco
                        ctx.fillStyle = "#ffffff"
                        ctx.fillRect(0, 0, width, height)

                        var moduleSize = Math.min(width, height) / pluginRoot.qrSize
                        ctx.fillStyle = "#000000"

                        for (var y = 0; y < pluginRoot.qrSize; y++) {
                            for (var x = 0; x < pluginRoot.qrSize; x++) {
                                if (pluginRoot.qrMatrix[y][x]) {
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
                enabled: pluginRoot.qrSize > 0
                onClicked: {
                    qrContainer.grabToImage(function(result) {
                        if (!result || !result.saveToFile)
                            return

                        // Carpeta dentro del "home" del proyecto
                        var dir = qgisProject.homePath + "/qr_labels"

                        // Algunos builds de QField exponen FileUtils en global;
                        // si no, sustituye por tu propia ruta/carpeta.
                        if (typeof FileUtils !== "undefined" && FileUtils.mkpath) {
                            FileUtils.mkpath(dir)
                        }

                        var safeCode = pluginRoot.codeText.replace(/[^a-zA-Z0-9_\-]/g, "_")
                        var filename = dir + "/label_" + safeCode + ".png"

                        var ok = result.saveToFile(filename, "png")
                        if (ok) {
                            // Abrir con app externa (Phomemo, galería, etc.)
                            Qt.openUrlExternally("file://" + filename)
                        } else {
                            console.log("No se pudo guardar la imagen QR en " + filename)
                        }
                    })
                }
            }

            Text {
                text: qsTr("La imagen se guarda en la carpeta del proyecto (/qr_labels).")
                wrapMode: Text.WordWrap
                font.pointSize: 10
                opacity: 0.7
            }
        }
    }
}
