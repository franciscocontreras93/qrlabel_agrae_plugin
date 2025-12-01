import QtQuick 2.12
import QtQuick.Controls 2.5

import org.qfield 1.0
import org.qgis 1.0
import Theme 1.0

// Componentes UI internos de QField (igual que hace el reloader)
import "qrc:/qml" as QFieldItems

// Capa JS que envuelve a qrcode.js
import "qrcode_qml.js" as QRLib

Item {
    id: pluginRoot

    // Accesos básicos
    property var mainWindow: iface.mainWindow()
    property var mapCanvas: iface.mapCanvas()

    // Estado QR
    property string codeText: ""
    property var qrMatrix: []
    property int qrSize: 0

    //
    // BOTÓN PRINCIPAL EN LA TOOLBAR (basado en el reloader)
    //
    QFieldItems.ToolButton {
        id: qrButton
        objectName: "agraeQrLabelButton"
        iconSource: Theme.getThemeIcon("mIconBarcode")  // si no existe, QField usa el icono por defecto

        // Click normal → abre el diálogo para generar etiqueta
        onClicked: {
            qrDialog.open()
        }

        // Pulsación larga → solo mostrar un toast informativo (como hace el reloader)
        onPressAndHold: {
            iface.mainWindow().displayToast(
                qsTr("aGrae QR Label: genera un QR y una etiqueta PNG lista para imprimir.")
            )
        }
    }

    // Al cargar el plugin, añadimos el botón a la toolbar de plugins
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(qrButton)
    }

    //
    // DIÁLOGO PARA GENERAR / GUARDAR EL CÓDIGO QR
    //
    Dialog {
        id: qrDialog
        modal: true
        title: qsTr("Imprimir etiqueta QR")

        // Centrado básico
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
                    var res = QRLib.generateMatrixForQml(pluginRoot.codeText)
                    pluginRoot.qrMatrix = res.matrix
                    pluginRoot.qrSize = res.size
                    qrCanvas.requestPaint()
                }
            }

            // Contenedor para el QR (se usará para grabToImage)
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

                        // Carpeta donde guardar las etiquetas
                        var dir
                        if (typeof qgisProject !== "undefined" && qgisProject.homePath) {
                            dir = qgisProject.homePath + "/qr_labels"
                        } else {
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
                            iface.mainWindow().displayToast(
                                qsTr("Etiqueta guardada en %1").arg(filename)
                            )
                        } else {
                            console.log("No se pudo guardar la imagen QR en " + filename)
                            iface.mainWindow().displayToast(
                                qsTr("Error al guardar la etiqueta.")
                            )
                        }
                    })
                }
            }

            Text {
                text: qsTr("La imagen se guarda en /qr_labels dentro de la carpeta del proyecto (o /sdcard/QField/qr_labels).")
                wrapMode: Text.WordWrap
                font.pointSize: 10
                opacity: 0.7
            }
        }
    }
}
