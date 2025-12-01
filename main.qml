import QtQuick 2.12
import QtQuick.Controls 2.5

import org.qfield 1.0
import org.qgis 1.0
import Theme 1.0

import "qrcode_qml.js" as QRLib

Item {
    id: pluginRoot

    // QField inyecta 'iface' en el contexto del plugin
    // Lo usamos para añadir el botón a la toolbar
    property var mainWindow: iface.mainWindow()
    property var dashBoard: iface.findItemByObjectName("dashBoard")

    // Estado básico para el QR
    property string codeText: ""
    property var qrMatrix: []
    property int qrSize: 0

    // Cuando se carga el plugin, añadimos el botón a la barra de herramientas
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(qrButton)
    }

    // Botón de la barra de herramientas de QField
    ToolButton {
        id: qrButton
        icon.source: Theme.getThemeIcon("mIconBarcode")
        onClicked: qrDialog.open()
    }

    // Diálogo principal para escribir código, generar QR y guardar PNG
    Dialog {
        id: qrDialog
        modal: true
        title: qsTr("Imprimir etiqueta QR")

        // Centrado simple (QField suele tener parent ancho/alto)
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
                width: 260
                onTextChanged: pluginRoot.codeText = text
            }

            Button {
                text: qsTr("Generar QR")
                enabled: pluginRoot.codeText.length > 0
                onClicked: {
                    // Generar matriz QR usando la capa JS
                    var res = QRLib.generateMatrixForQml(pluginRoot.codeText)
                    pluginRoot.qrMatrix = res.matrix
                    pluginRoot.qrSize = res.size
                    qrCanvas.requestPaint()
                }
            }

            // Contenedor para el QR (Canvas), útil para grabToImage()
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
                    // Capturamos el contenedor del QR como imagen
                    qrContainer.grabToImage(function(result) {
                        if (!result || !result.saveToFile)
                            return

                        // Carpeta donde guardar las etiquetas
                        var dir
                        if (typeof qgisProject !== "undefined" && qgisProject.homePath) {
                            dir = qgisProject.homePath + "/qr_labels"
                        } else {
                            // Ruta de respaldo si no hay homePath
                            dir = "/sdcard/QField/qr_labels"
                        }

                        // Crear carpeta si FileUtils existe
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
                text: qsTr("La imagen se guarda en /qr_labels dentro de la carpeta del proyecto (o /sdcard/QField).")
                wrapMode: Text.WordWrap
                font.pointSize: 10
                opacity: 0.7
            }
        }
    }
}
