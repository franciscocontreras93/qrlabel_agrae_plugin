.pragma library

// qrcode_qml.js
// Capa mínima para usar qrcode.js desde QML/QField sin DOM

// 1) "Fingimos" un objeto document muy básico si no existe.
//    Así qrcode.js no se queja cuando evalúa document.documentElement...
if (typeof document === "undefined") {
    var document = {
        documentElement: { tagName: "html" },
        createElement: function (tag) {
            // No lo vamos a usar en QML, pero lo definimos para que no explote
            return {};
        }
    };
}

// 2) Cargamos la librería original que tú ya tienes (qrcode.js).
//    Debe estar en la MISMA carpeta que este archivo.
Qt.include("qrcode.js");

//
// 3) API mínima para QML:
//    generateMatrixForQml(text, correctLevel)
//
//    Devuelve:
//      { matrix: [[0/1,...],...], size: N }
//

/**
 * Genera la matriz (array 2D) del código QR usando QRCodeModel
 * sin apoyarse en DOM ni en métodos de dibujo de qrcode.js.
 *
 * @param {String} text        Texto / código a codificar.
 * @param {Number} correctLvl  Nivel de corrección (opcional, por defecto M).
 *                              Usar QRCode.CorrectLevel.L|M|Q|H si se desea.
 * @return {Object} { matrix: [[0/1,...],...], size: N }
 */
function generateMatrixForQml(text, correctLvl) {
    if (!text || text.length === 0) {
        return { matrix: [], size: 0 };
    }

    if (typeof QRCode === "undefined" ||
        typeof QRCodeModel === "undefined") {
        console.log("qrcode_qml.js: QRCode o QRCodeModel no disponibles. ¿Se cargó correctamente qrcode.js?");
        return { matrix: [], size: 0 };
    }

    // Nivel de corrección por defecto: M
    correctLvl = correctLvl || QRCode.CorrectLevel.M;

    // Buscamos la versión mínima (typeNumber) que soporte el texto.
    var typeNumber = 1;
    for (var t = 1; t <= 40; t++) {
        var qrTest = new QRCodeModel(t, correctLvl);
        try {
            qrTest.addData(text);
            qrTest.make();
            typeNumber = t;
            break;
        } catch (e) {
            // Si no cabe en esta versión, probamos la siguiente
        }
    }

    // Generamos el QR definitivo
    var qr = new QRCodeModel(typeNumber, correctLvl);
    qr.addData(text);
    qr.make();

    var count = qr.getModuleCount();
    var matrix = [];

    for (var row = 0; row < count; row++) {
        var rowArr = [];
        for (var col = 0; col < count; col++) {
            // true/false -> 1/0
            rowArr.push(qr.isDark(row, col) ? 1 : 0);
        }
        matrix.push(rowArr);
    }

    return { matrix: matrix, size: count };
}
