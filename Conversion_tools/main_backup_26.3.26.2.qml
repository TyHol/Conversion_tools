import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield
import org.qgis
import QtCore

import Theme

import "qrc:/qml" as QFieldItems

Item {
 id: plugin

 property var canvas: iface.mapCanvas().mapSettings
 property var mainWindow: iface.mainWindow()
 property var dashBoard: iface.findItemByObjectName('dashBoard')
 property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')
 property var positionSource: iface.findItemByObjectName('positionSource')
 property var canvasMenu: iface.findItemByObjectName('canvasMenu')
 property var canvasCrs : canvas.destinationCrs ;
 property var canvasEPSG : parseInt(canvasCrs.authid.split(":")[1]); // Canvas destination CRS (not project CRS)
 property var mapCanvas: iface.mapCanvas()




//changable stuff 
property var filetimedate : "26.3.26..2" // version date
property var mapsUrlOption: 3 // Default external map: 1=GMaps pin, 2=GMaps nav, 3=OSM, 4=OSRM route

//default values
property var fsize : "15" // general font size
property var zoomV : "4" // zoom level 
property var decm : "0"  // decimal places for meter coordinates
property var decd : "5"  // decimal places for degree coordinates
  
 //Default visibility of various boxes
property var igvis: true // visibility of Irish grid
property var ukgvis: false // visibility of UK grid
property var custom1vis: false // visibility of custom1
property var custom2vis: false // visibility of custom2 
property var wgs84vis: true // visibility of wgs84 // always visible
property var dmvis: true // visibility of DM
property var dmsvis: false // visibility of DMS
property var dmsBoxesvis: true // visibility of DMS boxes
property var customisationvis: false // visibility of customisation
property var crosshairvis: true // visibility of crosshair
// for testing:
property var degwa : "70"  // width of degree input box when no decimals in it
property var minwa : "70"  // width of minute input box when no decimals in degree box



Settings {
    id: appSettings
    category: "ConversionTools"
    property string pointLayerName: ""
    property int    mapsUrlOption:  3
    property string fontSize:       "15"
    property string zoomLevel:      "4"
    property string decimalsM:      "0"
    property string decimalsD:      "5"
    property bool   showIG:         true
    property bool   showUK:         false
    property bool   showDegrees:    false
    property bool   showDM:         true
    property bool   showDMS:        false
    property bool   showCustom1:    false
    property bool   showCustom2:    false
    property bool   showCrosshair:  true
    property bool   showDMSboxes:   true
    property bool   showCustomisation: false
}

ListModel { id: pointLayerPickerModel }

function populatePointLayerPicker() {
    pointLayerPickerModel.clear()

    var layers = ProjectUtils.mapLayers(qgisProject)
    var normalLayers = []
    var privateLayers = []

    // Collect valid editable point layers, split by private flag (value 4)
    for (var id in layers) {
        var layer = layers[id]
        try {
            if (layer &&
                layer.geometryType &&
                layer.geometryType() === Qgis.GeometryType.Point &&
                layer.supportsEditing === true) {

                var isPrivate = false
                try { isPrivate = (layer.flags & 8) !== 0 } catch (e2) {}

                if (isPrivate)
                    privateLayers.push(layer)
                else
                    normalLayers.push(layer)
            }
        } catch (e) {}
    }

    // Sort each group alphabetically
    normalLayers.sort(function(a, b) { return a.name.localeCompare(b.name) })
    privateLayers.sort(function(a, b) { return a.name.localeCompare(b.name) })

    // If no layers found at all, show a placeholder and bail out
    if (normalLayers.length === 0 && privateLayers.length === 0) {
        pointLayerPickerModel.append({ "name": qsTr("— no editable point layers —"), "isHeader": true })
        pointLayerCombo.currentIndex = 0
        appSettings.pointLayerName = ""
        return
    }

    // Layers exist — add "Active Layer" as first selectable option
    pointLayerPickerModel.append({ "name": qsTr("Active Layer"), "isHeader": false })

    // Append normal layers
    for (var i = 0; i < normalLayers.length; i++)
        pointLayerPickerModel.append({ "name": normalLayers[i].name, "isHeader": false })

    // Append private group header + private layers (if any)
    if (privateLayers.length > 0) {
        pointLayerPickerModel.append({ "name": qsTr("— Private Layers —"), "isHeader": true })
        for (var j = 0; j < privateLayers.length; j++)
            pointLayerPickerModel.append({ "name": privateLayers[j].name, "isHeader": false })
    }

    // Restore saved selection
    var saved = appSettings.pointLayerName
    var found = false
    for (var k = 1; k < pointLayerPickerModel.count; k++) {
        var item = pointLayerPickerModel.get(k)
        if (!item.isHeader && item.name === saved) {
            pointLayerCombo.currentIndex = k
            found = true
            break
        }
    }
    if (!found) {
        pointLayerCombo.currentIndex = 0
        appSettings.pointLayerName = ""
    }
}


Component.onCompleted: {
    iface.addItemToPluginsToolbar(mainPluginButton)
    igukGridsFilter2.locatorBridge.registerQFieldLocatorFilter(igukGridsFilter2);
    canvasMenu.addItem(navButton)
    canvasMenu.addItem(addPointButton)
    canvasMenu.addItem(convertButton)
    canvasMenu.addItem(pasteButton)
    // Restore saved settings into UI
    mapsUrlOption      = appSettings.mapsUrlOption
    font_Size.text     = appSettings.fontSize
    zoom.text          = appSettings.zoomLevel
    decimalsm.text     = appSettings.decimalsM
    decimalsd.text     = appSettings.decimalsD
    showIG.checked     = appSettings.showIG
    showUK.checked     = appSettings.showUK
    showDegrees.checked    = appSettings.showDegrees
    showDM.checked         = appSettings.showDM
    showDMS.checked        = appSettings.showDMS
    showCustom1.checked    = appSettings.showCustom1
    showCustom2.checked    = appSettings.showCustom2
    showCrosshair.checked  = appSettings.showCrosshair
    showDMSboxes.checked   = appSettings.showDMSboxes
    showCustomisation.checked = appSettings.showCustomisation
}

 Component.onDestruction: { 
    igukGridsFilter2.locatorBridge.deregisterQFieldLocatorFilter(igukGridsFilter2);
    }   

    // --- Refactored Functions ---

    // Returns true if the EPSG code in epsgText refers to a geographic CRS (degrees),
    // false if projected (metres). Falls back to false on any error.
    function crsIsGeographic(epsgText) {
        try {
            return CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(epsgText)).isGeographic
        } catch(e) { return false }
    }

    function copyToClipboard(textToCopy) {
        let textEdit = Qt.createQmlObject('import QtQuick; TextEdit { }', plugin);
        textEdit.text = textToCopy;
        textEdit.selectAll();
        textEdit.copy();
        textEdit.destroy();
        mainWindow.displayToast("Copied: " + textToCopy);
    }

    // Builds the external map URL for a WGS84 destination (lat/lon).
    // Option 4 (OSRM routing) also resolves a GPS or screen-centre origin.
    function buildMapsUrl(lat, lon) {
        if (mapsUrlOption === 1)
            return "https://www.google.com/maps/search/?api=1&query=" + lat + "," + lon;
        if (mapsUrlOption === 2)
            return "https://www.google.com/maps/dir/?api=1&destination=" + lat + "%2C" + lon + "&travelmode=driving";
        if (mapsUrlOption === 3)
            return "https://www.openstreetmap.org/#map=15/" + lat + "/" + lon;
        // option 4 — OSRM routing, needs an origin
        var gpsLat, gpsLon;
        if (positionSource.active && positionSource.positionInformation.latitudeValid && positionSource.positionInformation.longitudeValid) {
            gpsLat = positionSource.positionInformation.latitude;
            gpsLon = positionSource.positionInformation.longitude;
            mainWindow.displayToast("Routing from GPS position");
        } else {
            var cp = GeometryUtils.reprojectPoint(
                canvas.center, canvasCrs,
                CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"));
            gpsLat = cp.y;
            gpsLon = cp.x;
            mainWindow.displayToast("No GPS — routing from screen centre");
        }
        return "https://routing.openstreetmap.de/?z=10&center=" + gpsLat + "%2C" + gpsLon
             + "&loc=" + gpsLat + "%2C" + gpsLon
             + "&loc=" + lat + "%2C" + lon
             + "&hl=en&alt=0&srv=0";
    }

    // Shared entry point for all "add point" actions.
    // geometry: already-built QgsGeometry in canvas CRS
    // openForm:  true  → open feature attribute form (button / locator)
    //            false → commit silently (paste)
    function addPointToActiveLayer(geometry, openForm) {
        var layer = null
        var savedName = appSettings.pointLayerName
        if (savedName !== "") {
            layer = qgisProject.mapLayersByName(savedName)[0] || null
            if (!layer) {
                mainWindow.displayToast(qsTr("Saved layer '%1' not found — using active layer").arg(savedName))
                appSettings.pointLayerName = ""
                pointLayerCombo.currentIndex = 0
            }
        }
        if (!layer) {
            dashBoard.ensureEditableLayerSelected()
            if (!dashBoard.activeLayer) {
                mainWindow.displayToast("No active layer selected")
                return
            }
            if (dashBoard.activeLayer.geometryType() !== Qgis.GeometryType.Point) {
                mainWindow.displayToast(qsTr("Active vector layer must be a point geometry"))
                return
            }
            layer = dashBoard.activeLayer
        }
        var feature = FeatureUtils.createFeature(layer, geometry)
        if (openForm) {
            dashBoard.activeLayer = layer
            overlayFeatureFormDrawer.featureModel.feature = feature
            overlayFeatureFormDrawer.state = "Add"
            overlayFeatureFormDrawer.featureModel.resetAttributes(true)
            overlayFeatureFormDrawer.open()
        } else {
            layer.startEditing()
            if (LayerUtils.addFeature(layer, feature)) {
                layer.commitChanges()
                mainWindow.displayToast(qsTr("Point added to '%1'").arg(layer.name))
            } else {
                layer.rollBack()
                mainWindow.displayToast("Failed to add point")
            }
        }
    }

    // Called by the paste handler — reprojects to canvas CRS then adds silently.
    function addPoint(pointX, pointY, crsEpsg) {
        var pt = (crsEpsg !== canvasEPSG)
            ? GeometryUtils.reprojectPoint(
                GeometryUtils.point(pointX, pointY),
                CoordinateReferenceSystemUtils.fromDescription("EPSG:" + crsEpsg),
                CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG))
            : GeometryUtils.point(pointX, pointY);
        addPointToActiveLayer(
            GeometryUtils.createGeometryFromWkt(`POINT(${pt.x} ${pt.y})`), false);
    }

    // Zooms the map canvas to a point, creating a square extent around it.
    // The half-width of that square is controlled by the Zoom setting (1-10):
    //   offset = exp(zoomLevel × 1.8)  → metres for projected CRS
    // For geographic CRS the offset is converted from metres to degrees
    // using the approximation 1° ≈ 111 000 m.
    function zoomToPoint(pointX, pointY, crsEpsg) {
        var sourceCrs = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + crsEpsg);
        var canvasCrsObj = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG);
        var transformedPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(pointX, pointY), sourceCrs, canvasCrsObj);

        // Exponential scale: zoom=1 → ~6 m half-width, zoom=10 → ~66 km half-width
        var offset = Math.exp(parseFloat(zoom.text) * 1.8);
        if (offset > 1000000) { offset = 1000000; }
        if (offset < 1) { offset = 1; }
        if (canvasCrs.isGeographic) { offset = offset / 111000; } // metres → degrees

        var xMin = transformedPoint.x - offset;
        var xMax = transformedPoint.x + offset;
        var yMin = transformedPoint.y - offset;
        var yMax = transformedPoint.y + offset;

        var polygonWkt = `POLYGON((${xMin} ${yMin}, ${xMax} ${yMin}, ${xMax} ${yMax}, ${xMin} ${yMax}, ${xMin} ${yMin}))`;
        var geometry = GeometryUtils.createGeometryFromWkt(polygonWkt);

        const extent = GeometryUtils.reprojectRectangle(
            GeometryUtils.boundingBox(geometry),
            canvasCrsObj,
            mapCanvas.mapSettings.destinationCrs
        );
        mapCanvas.mapSettings.setExtent(extent, true);
    }
function handlePaste(clipboardText, createPointAndZoom) {
    // If no text provided, read from system clipboard
    if (clipboardText === undefined || clipboardText === null)
        clipboardText = Qt.application.clipboard.text;

    // Clean and truncate
    let raw = clipboardText || "";
    let text = raw.trim().replace(/\s+/g, '');
    if (text.length > 100) text = text.substring(0, 100);

    function padGridNumbers(numbers) {
        if (numbers.length !== 10) return null;
        return numbers.substring(0,5) + ' ' + numbers.substring(5);
    }

    // Patterns: strict one or two letters + ten digits
    let ukGridPattern = /^[A-Z]{2}\d{10}$/i;
    let irishGridPattern = /^[A-Z]\d{10}$/i;

    let pointX, pointY, pointCrs, formattedDisplay;

    if (ukGridPattern.test(text)) {
        let letters = text.substring(0,2).toUpperCase();
        let numbers = text.substring(2);
        let padded = padGridNumbers(numbers);
        let entry = ukletterMatrix[letters];
        if (entry && padded) {
            pointX = parseInt(padded.substring(0,5)) + (entry.first * 100000);
            pointY = parseInt(padded.substring(6)) + (entry.second * 100000);
            pointCrs = 27700;
            formattedDisplay = `${letters} ${padded}`;
            ukInputBox.text = formattedDisplay;
            updateCoordinates(pointX, pointY, pointCrs, custom1CRS.text, custom2CRS.text, 2);
        }
    } else if (irishGridPattern.test(text)) {
        let letter = text.substring(0,1).toUpperCase();
        let numbers = text.substring(1);
        let padded = padGridNumbers(numbers);
        let entry = igletterMatrix[letter];
        if (entry && padded) {
            pointX = parseInt(padded.substring(0,5)) + (entry.first * 100000);
            pointY = parseInt(padded.substring(6)) + (entry.second * 100000);
            pointCrs = 29903;
            formattedDisplay = `${letter} ${padded}`;
            igInputBox.text = formattedDisplay;
            updateCoordinates(pointX, pointY, pointCrs, custom1CRS.text, custom2CRS.text, 1);
        }
    }

    // --- If valid ---
    if (pointX !== undefined && pointY !== undefined) {
        if (createPointAndZoom) {
            addPoint(pointX, pointY, pointCrs);
            zoomToPoint(pointX, pointY, pointCrs);
        }
        pasteErrDialog.visible = false;
        appToast.show(`Point added from clipboard at ${formattedDisplay} (EPSG:${pointCrs})`);
        return true;
    }

    // --- If invalid ---
    pasteErrDialog.clipboardText = raw.length > 100 ? raw.substring(0, 100) : raw;
    pasteErrDialog.createPointOnSuccess = createPointAndZoom;
    pasteErrDialog.open();
    return false;
}

Dialog {
    id: pasteErrDialog
    parent: mainWindow.contentItem
    visible: false
    modal: true
    width: 350
    font: Theme.defaultFont
    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) * 0.15

    property string clipboardText: ""
    property bool createPointOnSuccess: false

    title: "Paste Error"
    standardButtons: Dialog.Ok | Dialog.Cancel
    closePolicy: Dialog.NoAutoClose

    onOpened: {
        editablePasteContent.text = clipboardText;
        standardButton(Dialog.Ok).text = "Try Again";
        editablePasteContent.forceActiveFocus();
    }

    onAccepted: {
        let edited = editablePasteContent.text || "";
        if (edited.length > 100)
            edited = edited.substring(0, 100);

        // Delay the re-check until after the dialog closes
        Qt.callLater(function() {
            handlePaste(edited, createPointOnSuccess);
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Invalid coordinate format. Edit the text below and try again."
        }

        TextArea {
            id: editablePasteContent
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            wrapMode: Text.Wrap
            placeholderText: "Pasted content"
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            text: "<b>Valid examples:</b><br>" +
                  "Irish Grid: H 54321 89797<br>" +
                  "UK Grid: NS 45140 72887"
        }
    }
}








MenuItem{ 
    id: addPointButton
    text: qsTr("Add point")
    icon.source: 'plugin_stuff/new.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont
    onClicked: {
        addPointToActiveLayer(
            GeometryUtils.createGeometryFromWkt(`POINT(${canvasMenu.point.x} ${canvasMenu.point.y})`), true);
    }
}

MenuItem {
    id: navButton
    text: qsTr("Open externally")
    icon.source: 'plugin_stuff/car.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont

    onClicked: {
        var transformedPoint = GeometryUtils.reprojectPoint(
            GeometryUtils.point(canvasMenu.point.x, canvasMenu.point.y),
            mapCanvas.mapSettings.destinationCrs,
            CoordinateReferenceSystemUtils.fromDescription("EPSG:4326")
        )
        Qt.openUrlExternally(buildMapsUrl(transformedPoint.y, transformedPoint.x))
    }

}

MenuItem {
    id: convertButton
    text: qsTr("Convert/Show coordinates")
    icon.source: 'plugin_stuff/spir.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont

    onClicked: {
        
        // open main Dialog
        mainDialog.open()
        // Get coordinates from canvas position and put them into the mian Dialog
        updateCoordinates(canvasMenu.point.x, canvasMenu.point.y, canvasEPSG, custom1CRS.text, custom2CRS.text)
              
    }
 }



MenuItem {
    id: pasteButton
    text: qsTr("Paste location from clipboard")
    icon.source: 'plugin_stuff/ig.svg'
    enabled: true
    height: 48
    leftPadding: 10
    font: Theme.defaultFont

    onClicked: {
        // Create temporary TextEdit for clipboard access
        let clipboard = Qt.createQmlObject('import QtQuick; TextEdit { visible: false }', plugin)
        clipboard.paste()
        let clipboardText = clipboard.text;
        clipboard.destroy()

        handlePaste(clipboardText, true);
    }
}







// Irish Grid/ UK Grid Locator Filter
QFieldLocatorFilter {
    id: igukGridsFilter2
    delay: 1000
    name: "IG & UK Grids"
    displayName: "IG & UK Grid finder"
    prefix: "grid"
    locatorBridge: iface.findItemByObjectName('locatorBridge')
    source: Qt.resolvedUrl('plugin_stuff/grids.qml')
    

function triggerResult(result) {
  if (result.userData && result.userData.geometry) {
    const geometry = result.userData.geometry;
    const crs = CoordinateReferenceSystemUtils.fromDescription(result.userData.crs);

    // Reproject the geometry to the map's CRS
    const reprojectedGeometry = GeometryUtils.reprojectPoint(
      geometry,
      crs,
      mapCanvas.mapSettings.destinationCrs
    );

    // Center the map on the reprojected geometry
   mapCanvas.mapSettings.setCenter(reprojectedGeometry, true);

    // Highlight the geometry on the map
    locatorBridge.locatorHighlightGeometry.qgsGeometry = geometry;
    locatorBridge.locatorHighlightGeometry.crs = crs;
  } else {
    mainWindow.displayToast("Invalid geometry in result");
  }
}
function triggerResultFromAction(result, actionId) {
  if (result.userData && result.userData.geometry) {
    const geometry = result.userData.geometry;
    const crs = CoordinateReferenceSystemUtils.fromDescription(result.userData.crs);

    // Reproject the geometry to the map's CRS
    const reprojectedPoint = GeometryUtils.reprojectPoint(
      geometry,
      crs,
      mapCanvas.mapSettings.destinationCrs
    );

    if (actionId === 1) {
      // Set the navigation destination
      const navigation = iface.findItemByObjectName('navigation');
      if (navigation) {
        navigation.destination = reprojectedPoint;
        mainWindow.displayToast("Destination set successfully");
      } else {
        mainWindow.displayToast("Navigation component not found");
      }

    } else if (actionId === 2) {
        addPointToActiveLayer(
            GeometryUtils.createGeometryFromWkt(`POINT(${reprojectedPoint.x} ${reprojectedPoint.y})`), true);
    }
  } else {
    mainWindow.displayToast("Invalid action or geometry");
  }
  
}
}   




//small crosshair
Rectangle {
    id: crosshair
    visible: true
    parent: iface.mapCanvas()
    color: "transparent"
    width: 40
    height: 40
    anchors.centerIn: parent

    property int gap: 10          // size of transparent center hole (adjust 8–14)
    property int lineW: 5         // total line thickness (keeps it odd → perfect centering)

    // ── Horizontal left arm
    Rectangle {
        width: (parent.width - parent.gap) / 2
        height: parent.lineW
        color: "transparent"
        anchors {
            right: parent.horizontalCenter
            rightMargin: parent.gap / 2
            verticalCenter: parent.verticalCenter
        }

        // White bottom part
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.bottom: parent.bottom }
        // Black core – exactly centered vertically
        Rectangle { width: parent.width; height: 2; color: "black"; anchors.centerIn: parent }
        // White top part
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.top: parent.top }
    }

    // ── Horizontal right arm (identical)
    Rectangle {
        width: (parent.width - parent.gap) / 2
        height: parent.lineW
        color: "transparent"
        anchors {
            left: parent.horizontalCenter
            leftMargin: parent.gap / 2
            verticalCenter: parent.verticalCenter
        }
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.bottom: parent.bottom }
        Rectangle { width: parent.width; height: 2;   color: "black";  anchors.centerIn: parent }
        Rectangle { width: parent.width; height: 1.5; color: "white"; anchors.top:    parent.top }
    }

    // ── Vertical top arm
    Rectangle {
        width: parent.lineW
        height: (parent.height - parent.gap) / 2
        color: "transparent"
        anchors {
            bottom: parent.verticalCenter
            bottomMargin: parent.gap / 2
            horizontalCenter: parent.horizontalCenter
        }

        // White right part
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.right: parent.right }
        // Black core – exactly centered horizontally
        Rectangle { width: 2;   height: parent.height; color: "black";  anchors.centerIn: parent }
        // White left part
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.left:  parent.left }
    }

    // ── Vertical bottom arm (identical)
    Rectangle {
        width: parent.lineW
        height: (parent.height - parent.gap) / 2
        color: "transparent"
        anchors {
            top: parent.verticalCenter
            topMargin: parent.gap / 2
            horizontalCenter: parent.horizontalCenter
        }
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.right: parent.right }
        Rectangle { width: 2;   height: parent.height; color: "black";  anchors.centerIn: parent }
        Rectangle { width: 1.5; height: parent.height; color: "white"; anchors.left:  parent.left }
    }

    // Optional tiny center ring (many people love this for vertex snapping)
    // Rectangle {
     //    width: 10; height: 10; radius: 5
    //     color: "transparent"
    //    border.color: "#ccffffff"
    //     border.width: 1
    //     anchors.centerIn: parent
   //  }
}

QfToolButton {
 id: mainPluginButton
 bgcolor: Theme.darkGray
 iconSource: 'plugin_stuff/icon2.svg'
 round: true
 onClicked: mainDialog.open()
 onPressAndHold: settingsDialog.open()
}
 



Dialog {
 id: mainDialog
 parent: mainWindow.contentItem
 visible: false
 modal: true
 font: Theme.defaultFont
 Layout.preferredHeight: 35
 width: 380


 x: (mainWindow.width - width) / 2
 y: (mainWindow.height - height) * 0.15

 ColumnLayout {
 anchors.fill: parent
 anchors.margins : 1



RowLayout{
 Layout.fillWidth: true
 Label {
 id: label_1
 visible: true
 font.bold: true
 wrapMode: Text.Wrap
 text: qsTr("Grab:")
 font.pixelSize: font_Size.text
 font.family: "Arial" // Set font family
 font.italic: true // Make text italic
 } 

Button {
 text: qsTr("Screencenter")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 Layout.preferredHeight: 35 
 onClicked: {
 var pos = canvas.center
 updateCoordinates(pos.x, pos.y, canvasEPSG, custom1CRS.text, custom2CRS.text)
 } 
 } 

 
 Button {
 text: qsTr("GPS")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 Layout.preferredHeight: 35 

 onClicked: {
 if (!positionSource.active || !positionSource.positionInformation.latitudeValid || !positionSource.positionInformation.longitudeValid) {
 mainWindow.displayToast(qsTr("GPS must be active"))} else 
 { 
 var pos = positionSource.projectedPosition
 updateCoordinates(pos.x, pos.y, canvasEPSG, custom1CRS.text, custom2CRS.text) 
 }
 }
 }
     Button {
        text: "⚙"
        font.pixelSize: 18
        Layout.preferredHeight: 32
        Layout.preferredWidth: 32
        onClicked: settingsDialog.open()
        contentItem: Text {
            text: "⚙"
            font.pixelSize: 18
            color: "#000000"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
Button {
 text: qsTr("Paste from clipboard")
 font.bold: true
 Layout.fillWidth: true
 visible: true
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 Layout.preferredHeight: 35 
 onClicked: {

    // Create temporary TextEdit for clipboard access
    let clipboard = Qt.createQmlObject('import QtQuick; TextEdit { visible: false }', plugin)
    clipboard.paste();
    let clipboardText = clipboard.text;
    clipboard.destroy();

    handlePaste(clipboardText, false);
 } 
 } 

ColumnLayout{
visible: true 
//spacing: 1

// Irish Grid
RowLayout{
    id: igridrow
    visible: igvis

TextField {
 id: igInputBox //1
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.bold: true
 font.italic: true
 Layout.fillWidth: true
 placeholderText: "Irish Grid: X 00000 00000"
 property bool isProgrammaticUpdate: false
 // Custom validation logic
 onTextChanged: {

    if (isProgrammaticUpdate) {
 // Skip validation if the text is being updated programmatically
 isProgrammaticUpdate = false
 return
 }
   igInputBox.placeholderText  = "IG"
 // Remove any non-alphanumeric characters (except spaces)
 var cleanedText = igInputBox.text.replace(/[^A-Za-z0-9\s]/g, '')

 // Ensure the first character is a valid letter from the matrix
 if (cleanedText.length > 0 && !igletterMatrix[cleanedText[0].toUpperCase()]) {
 cleanedText = cleanedText.substring(1)
 }

 // Insert spaces at the correct positions
 if (cleanedText.length > 1 && cleanedText[1] !== ' ') {
 cleanedText = cleanedText[0] + ' ' + cleanedText.substring(1)
 }
 if (cleanedText.length > 7 && cleanedText[7] !== ' ') {
 cleanedText = cleanedText.substring(0, 7) + ' ' + cleanedText.substring(7)
 }

 // Ensure the characters after the first space are digits
 if (cleanedText.length > 2) {
 var firstNumberPart = cleanedText.substring(2, 7)
 if (!/^\d{0,5}$/.test(firstNumberPart)) {
 firstNumberPart = firstNumberPart.replace(/\D/g, '')
 cleanedText = cleanedText.substring(0, 2) + firstNumberPart + cleanedText.substring(7)
 }
 }

 // Ensure the characters after the second space are digits
 if (cleanedText.length > 8) {
 var secondNumberPart = cleanedText.substring(8, 13)
 if (!/^\d{0,5}$/.test(secondNumberPart)) {
 secondNumberPart = secondNumberPart.replace(/\D/g, '')
 cleanedText = cleanedText.substring(0, 8) + secondNumberPart + cleanedText.substring(13)
 }
 }

 // Limit the total length to 13 characters (X 00000 00000)
 if (cleanedText.length > 13) {
 cleanedText = cleanedText.substring(0, 13)
 }

 // Update the text field
 igInputBox.text = cleanedText

 // Convert IG to other formats
 if (igInputBox.isValidInput()) {
 var letter = igInputBox.text.substring(0, 1).toUpperCase()
 var X5 = parseInt(igInputBox.text.substring(2, 7), 10)
 var Y5 = parseInt(igInputBox.text.substring(8, 13), 10)
 var matrixEntry = igletterMatrix[letter]
 var xIN = X5 + (matrixEntry.first * 100000)
 var yIN = Y5 + (matrixEntry.second * 100000)
 
 updateCoordinates(xIN, yIN, 29903, custom1CRS.text, custom2CRS.text , 1) 
 }
 }

 // Function to validate the final input
 function isValidInput() {
 var regex = /^[A-Za-z]\s\d{5}\s\d{5}$/
 return regex.test(igInputBox.text) && igletterMatrix[igInputBox.text[0].toUpperCase()]
 }
}


Button {
    text: "⧉"
    id: copyIG  
    font.bold: true
    width: 10
    height: 10

    background: Rectangle {
        color: "#B3EBF2" 
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(igInputBox.text)
    }
}
} 
// UK Grid 
 
RowLayout{
    id:ukgridrow 
    visible: ukgvis

TextField {
 id: ukInputBox //2
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.bold: true
 font.italic: true 
 Layout.fillWidth: true
 placeholderText: "UK Grid: XX 00000 00000"
 
 // Flag to indicate programmatic updates
 property bool isProgrammaticUpdate: false

 // Custom validation logic
 onTextChanged: {
ukInputBox.placeholderText  = "UKG"    
 if (isProgrammaticUpdate) {
 // Skip validation if the text is being updated programmatically
 isProgrammaticUpdate = false
 return
 }

 // Remove any non-alphanumeric characters (except spaces)
 var cleanedText = ukInputBox.text.replace(/[^A-Za-z0-9\s]/g, '')

 // Ensure the first two characters are valid letters from the matrix
 if (cleanedText.length > 1) {
 var firstTwoLetters = cleanedText.substring(0, 2).toUpperCase()
 if (!ukletterMatrix[firstTwoLetters]) {
 cleanedText = cleanedText.substring(2)
 }
 }

 // Insert spaces at the correct positions
 if (cleanedText.length > 2 && cleanedText[2] !== ' ') {
 cleanedText = cleanedText.substring(0, 2) + ' ' + cleanedText.substring(2)
 }
 if (cleanedText.length > 8 && cleanedText[8] !== ' ') {
 cleanedText = cleanedText.substring(0, 8) + ' ' + cleanedText.substring(8)
 }

 // Ensure the characters after the first space are digits
 if (cleanedText.length > 3) {
 var firstNumberPart = cleanedText.substring(3, 8)
 if (!/^\d{0,5}$/.test(firstNumberPart)) {
 firstNumberPart = firstNumberPart.replace(/\D/g, '')
 cleanedText = cleanedText.substring(0, 3) + firstNumberPart + cleanedText.substring(8)
 }
 }

 // Ensure the characters after the second space are digits
 if (cleanedText.length > 9) {
 var secondNumberPart = cleanedText.substring(9, 14)
 if (!/^\d{0,5}$/.test(secondNumberPart)) {
 secondNumberPart = secondNumberPart.replace(/\D/g, '')
 cleanedText = cleanedText.substring(0, 9) + secondNumberPart + cleanedText.substring(14)
 }
 }

 // Limit the total length to 14 characters (XX 00000 00000)
 if (cleanedText.length > 14) {
 cleanedText = cleanedText.substring(0, 14)
 }

 // Update the text field
 ukInputBox.text = cleanedText

 // Convert UK Grid to other formats
 if (ukInputBox.isValidInput()) {
 var letter = ukInputBox.text.substring(0, 2).toUpperCase()
 var X5 = parseInt(ukInputBox.text.substring(3, 8), 10)
 var Y5 = parseInt(ukInputBox.text.substring(9, 14), 10)
 var matrixEntry = ukletterMatrix[letter]
 var xIN = X5 + (matrixEntry.first * 100000)
 var yIN = Y5 + (matrixEntry.second * 100000)
 
 updateCoordinates(xIN, yIN, 27700, custom1CRS.text, custom2CRS.text, 2) 
 }
 }

 // Function to validate the final input
 function isValidInput() {
 var regex = /^[A-Za-z]{2}\s\d{5}\s\d{5}$/
 return regex.test(ukInputBox.text) && ukletterMatrix[ukInputBox.text.substring(0, 2).toUpperCase()]
 }
}
Button {
    text: "⧉"
    id: copyUK  
    //visible: false
    font.bold: true
    width: 10
    height: 10
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(ukInputBox.text)
    }
}
} 
 
// Custom1 Row
RowLayout {
    id: custom1row
    visible: custom1vis

TextField {
    id: custom1BoxXY //3
    property bool isProgrammaticUpdate: false
    Layout.preferredHeight: 35
    Layout.preferredWidth: 180
    font.pixelSize: font_Size.text
    font.family: "Arial"
    font.bold: true
    font.italic: true
    placeholderText: crsIsGeographic(custom1CRS.text) ? "Lat, Long" : "X, Y"
    //visible: false
    text: ""

    // Timer for delayed validation
    Timer {
        id: validationTimer
        interval: 500 // 500ms delay
        running: false
        repeat: false
        onTriggered: {
            // Run validation logic here
            validateInput(custom1BoxXY);

            // Parse coordinates more robustly
            var parts = custom1BoxXY.text.split(',').map(function(part) {
                return parseFloat(part.trim());
            });

            if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                updateCoordinates(parts[0], parts[1], custom1CRS.text, custom1CRS.text, custom2CRS.text, 3);
            }
        }
    }

    onTextChanged: {
        if (isProgrammaticUpdate) {
            isProgrammaticUpdate = false;
            return;
        }

        // Restart the timer on every keystroke
        validationTimer.restart();
    }
}

//end of custombox1 


 TextField {
 id: custom1CRS
  Layout.fillWidth: true
 Layout.preferredHeight: 35 
 placeholderText: " EPSG"
 font.pixelSize: font_Size.text // Smaller text size
 font.family: "Arial" // Set font family
 font.italic: true // Make text italic
 font.bold: true
 text: canvasEPSG
 // Enforce integer number input
 validator: IntValidator {
 bottom: 0 // Allow any negative number
 top: 10000000 // Allow any positive number
 } 
 
 }
 Button {
    text: "⧉"
    id: custom1copy
    font.bold: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(custom1BoxXY.text)
    }
}

 }
 
// custom2
RowLayout {
 id: custom2row
 visible: custom2vis



TextField {
    id: custom2BoxXY
    property bool isProgrammaticUpdate: false
    Layout.preferredWidth: 180
    Layout.preferredHeight: 35
    font.pixelSize: font_Size.text
    font.family: "Arial"
    font.italic: true
    font.bold: true
    placeholderText: crsIsGeographic(custom2CRS.text) ? "Lat, Long" : "X, Y"
    //visible: false
    text: ""

    Timer {
        id: validationTimer2
        interval: 500
        running: false
        repeat: false
        onTriggered: {
            // Run validation logic here
            validateInput(custom2BoxXY);

            // Parse coordinates more robustly
            var parts = custom2BoxXY.text.split(',').map(function(part) {
                return parseFloat(part.trim());
            });

            if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                updateCoordinates(parts[0], parts[1], custom2CRS.text, custom1CRS.text, custom2CRS.text, 4);
            }
        }
    }

    onTextChanged: {
        if (isProgrammaticUpdate) {
            isProgrammaticUpdate = false;
            return;
        }
        validationTimer2.restart();
    }
}
//end of second custom box



 TextField {
 id: custom2CRS
  Layout.fillWidth: true
 Layout.preferredHeight: 35 
 placeholderText: " EPSG"
 font.pixelSize: font_Size.text
 font.family: "Arial" // Set font family
 font.bold: true
 font.italic: true // Make text italic
 text: "4326"
 //visible: false
 // Enforce integer number input
 validator: IntValidator {
 bottom: 0 // Allow any negative number
 top: 10000000 // Allow any positive number
 }
  }

 Button {
    text: "⧉"
    id: custom2copy
    font.bold: true
    //visible: false
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(custom2BoxXY.text)
    }
 }
}


// wgs1984 
RowLayout{
 id: wgsdegreesrow
 visible: wgs84vis 
TextField {
 id: wgs84Box //5
  Layout.fillWidth: true
 font.bold: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 placeholderText: "Lat(N), Long(E) "
 text: ""
 property bool isProgrammaticUpdate: false
 
 onTextChanged: {

    if (isProgrammaticUpdate) {
 // Skip validation if the text is being updated programmatically
 isProgrammaticUpdate = false
 return
 }
    wgs84Box.placeholderText  = "Lat Long"
 var cursorPos = cursorPosition // Store cursor position
 var originalText = text

 // Clean input: allow digits, minus, dot, comma, and spaces
 var cleanedText = text.replace(/[^0-9-.,\s]/g, '')

 // Split by comma
 var parts = cleanedText.split(',')
 if (parts.length > 2) {
 cleanedText = parts[0] + ',' + parts[1]
 parts = cleanedText.split(',')
 }

 // Process each part
 for (var i = 0; i < parts.length; i++) {
 var num = parts[i].trim()

 // Allow partial input (e.g., "-", "45.", "45.1") during typing
 if (num === '' || num === '-' || num.match(/^-?\d*\.?\d*$/)) {
 // If it’s a valid partial number (including just a dot), keep it as-is
 parts[i] = num
 continue
 }

 // Remove extra dots (keep only the first one)
 var dots = (num.match(/\./g) || []).length
 if (dots > 1) {
 var firstDotIndex = num.indexOf('.')
 num = num.substring(0, firstDotIndex + 1) + num.substring(firstDotIndex + 1).replace(/\./g, '')
 }

 // Parse and clamp the value
 var value = parseFloat(num)
 if (isNaN(value)) {
 num = num.replace(/[^0-9-.]/g, '') // Remove invalid characters
 } else if (value < -90) {
 num = '-90'
 } else if (value > 90) {
 num = '90'
 } else {
 num = value.toString()
 }
 parts[i] = num
 }

 // Reconstruct the text
 cleanedText = parts[0] || ''
 if (parts.length > 1) {
 cleanedText += ', ' + (parts[1] || '')
 }

 // Update text only if it changed, and restore cursor
 if (text !== cleanedText) {
 text = cleanedText
 cursorPosition = cursorPos
 
 // convert get X,Y from textfield:
 {var parts = wgs84Box.text.split(',')
 var xlat = parts[0] 
 var ylon = parts[1] 
 
 updateCoordinates(ylon, xlat, 4326, custom1CRS.text, custom2CRS.text,5)} 
 }
 }
}
 Button {
    text: "⧉"
    id: wgs84copy
    font.bold: true
    //visible: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(wgs84Box.text)
    }
}
}

RowLayout{
    id: dmrow
    visible: dmvis
TextField {
 id: wgs84DMBox //6
  Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 font.bold: true
 placeholderText: "D M.mm (Read only)" //"Lat(N), Long(E) (e.g., 34° 27.36', 56° 40.2')"
 //visible: false
 text: ""

 property bool isProgrammaticUpdate: false
 
  onTextChanged: {
 //   wgs84DMBox.placeholderText  = "Lat Long"
  if (isProgrammaticUpdate) {
 // Skip validation if the text is being updated programmatically
 isProgrammaticUpdate = false
 return
 }
 
  
 }}
 Button {
    text: "⧉"
    id: wgsdm84copy
    font.bold: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(wgs84DMBox.text)
    }
}
 

}
RowLayout{
    id: dmsrow
    visible : dmsvis
TextField {
 id: wgs84DMSBox //6
  Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text 
 font.family: "Arial"
 font.italic: true
 font.bold: true
 placeholderText: "D M S.ss (Read only)" //"Lat(N), Long(E) (e.g., 34° 27.36', 56° 40.2')"
 text: ""

 property bool isProgrammaticUpdate: false
 
 // need to get this to work or delete it....
 onTextChanged: {
 //   wgs84DMBox.placeholderText  = "Lat Long"
  if (isProgrammaticUpdate) {
 // Skip validation if the text is being updated programmatically
 isProgrammaticUpdate = false
 return
 }
 

 }}
 Button {
    text: "⧉"
    id: wgsdms84copy
    font.bold: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#B3EBF2"
        radius: width / 2
    }
    onClicked: {
        copyToClipboard(wgs84DMSBox.text)
    }
}
 
}
// Seperate input boxes for lat Degrees, lon Minutes, lat Degrees and long minutes. 
// Entering decimals in the Degrees boxes will remove the minute boxes.
// update of the other coordinate boxes is achieved by button which enters the parsed 
// ddlat and ddlong from these boxes into the above wgs84Box.
 
RowLayout {
   
 id: latlongboxesDMS
 spacing: 5
 visible: dmsBoxesvis

 // Latitude Degrees
 TextField {
 id: latDegrees
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.bold: true
 font.family: "Arial"
 font.italic: true
 placeholderText: "D"
 leftPadding: 4
 rightPadding: 0
 validator: DoubleValidator {
 bottom: -90
 top: 90
 decimals: 5
 }
 Timer {
 id: latDegClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(latDegrees.text)
 if (!isNaN(value)) {
 value = Math.max(-90, Math.min(90, value))
 latDegrees.text = value // update to safe value (preserve decimals)
 }
 }
 }

 onTextChanged: {
 latDegClampTimer.restart() // each change restarts the timer
 
 if (lonDegrees.text.includes('.') || latDegrees.text.includes('.')) { // if there is a decimal in the either degrees box just show degrees & clear data in minutes and seconds boxes
 latMinutes.visible = false
 latMinutes.text = ""
 latSeconds.visible = false
 latSeconds.text = ""
 lonMinutes.visible = false
  lonMinutes.text = "" 
 lonSeconds.visible = false
 lonSeconds.text = ""
 } 
 else if(lonMinutes.text.includes('.') || latMinutes.text.includes('.')){ // if there is a decimal in the minutes box show degrees and minutes & clear data in seconds box
  lonDegrees.Layout.preferredWidth = degwa
  latDegrees.Layout.preferredWidth = degwa
  latMinutes.visible = true
  latSeconds.visible = false
  latSeconds.text = ""  
  lonMinutes.visible = true
  lonSeconds.visible = false
  lonSeconds.text = ""
 }
    else {   // if there are no decimals in the degrees or minutes boxes show all boxes
  lonDegrees.Layout.preferredWidth = degwa
  latDegrees.Layout.preferredWidth = degwa
  latMinutes.visible = true
  lonMinutes.visible = true
  lonMinutes.Layout.preferredWidth = minwa
  latMinutes.Layout.preferredWidth = minwa
  latSeconds.visible = true
  lonSeconds.visible = true 
 }
 } 
 }

 // Latitude Minutes (decimal)
 TextField {
 id: latMinutes
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "M"
 validator: DoubleValidator {
 bottom: 0
 top: +60
 decimals: 4
 }
Timer {
 id: latMinClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(latMinutes.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(59.999, value))
 latMinutes.text = value
 }
 }
}
onTextChanged: {
 latMinClampTimer.restart()
var hideSecs = latMinutes.text.includes(".") || lonMinutes.text.includes(".")|| lonDegrees.text.includes(".")|| latDegrees.text.includes(".");
  lonSeconds.visible = !hideSecs;
  latSeconds.visible = !hideSecs;
  if (hideSecs== true) {lonSeconds.text = "" 
  latSeconds.text = ""}
}
 }

 // Latitude Seconds
 TextField {
 id: latSeconds
 visible: true
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "S"
 validator: DoubleValidator {
 bottom: 0
 top: 60
 decimals: 3
 }
 Timer {
 id: latSecClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(latSeconds.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(60, value))
 latSeconds.text = value
 }
 }
}
onTextChanged: latSecClampTimer.restart()

 }

 // Longitude Degrees
 TextField {
 id: lonDegrees
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
  font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
leftPadding: 4



 rightPadding: 0
 placeholderText: "D"
 validator: DoubleValidator {
 bottom: -180
 top: 180
 decimals: 5
 }
Timer {
 id: lonDegClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(lonDegrees.text)
 if (!isNaN(value)) {
 value = Math.max(-180, Math.min(180, value))
 lonDegrees.text = value
 }
 }
}
onTextChanged: {lonDegClampTimer.restart()

 
 if (lonDegrees.text.includes('.') || latDegrees.text.includes('.')) { // if there is a decimal in the either degrees box just show degrees & clear data in minutes and seconds boxes
 latMinutes.visible = false
 latMinutes.text = ""
 latSeconds.visible = false
 latSeconds.text = ""
 lonMinutes.visible = false
  lonMinutes.text = "" 
 lonSeconds.visible = false
 lonSeconds.text = ""
 } 
 else if(lonMinutes.text.includes('.') || latMinutes.text.includes('.')){ // if there is a decimal in the minutes box show degrees and minutes & clear data in seconds box
  lonDegrees.Layout.preferredWidth = degwa
  latDegrees.Layout.preferredWidth = degwa
  latMinutes.visible = true
  latSeconds.visible = false
  latSeconds.text = ""  
  lonMinutes.visible = true
  lonSeconds.visible = false
  lonSeconds.text = ""
 }
    else {   // if there are no decimals in the degrees or minutes boxes show all boxes
  lonDegrees.Layout.preferredWidth = degwa
  latDegrees.Layout.preferredWidth = degwa
  latMinutes.visible = true
  lonMinutes.visible = true
  lonMinutes.Layout.preferredWidth = minwa
  latMinutes.Layout.preferredWidth = minwa
  latSeconds.visible = true
  lonSeconds.visible = true 
    } 
 }
 }

 // Longitude Minutes (decimal)
 TextField {
 id: lonMinutes
 Layout.preferredWidth: 60
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "M"
 validator: DoubleValidator {
 bottom: 0
 top: 60
 decimals: 4
 }
Timer {
 id: lonMinClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(lonMinutes.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(59.999, value))
 lonMinutes.text = value
 }
 }
}
onTextChanged: {
 lonMinClampTimer.restart();
 var hideSecs = latMinutes.text.includes(".") || lonMinutes.text.includes(".")|| lonDegrees.text.includes(".")|| latDegrees.text.includes(".");
  lonSeconds.visible = !hideSecs;
  latSeconds.visible = !hideSecs;
  if (hideSecs== true) {lonSeconds.text = "" 
  latSeconds.text = ""}

 }
 }

 // Longitude Seconds
 TextField {
 id: lonSeconds
 visible: true
 Layout.fillWidth: true
 Layout.preferredHeight: 35
 font.pixelSize: font_Size.text
 font.family: "Arial"
 font.bold: true
 font.italic: true
 leftPadding: 4
 rightPadding: 0
 placeholderText: "S"
 validator: DoubleValidator {
 bottom: 0
 top: 60
 decimals: 3
 }
 Timer {
 id: lonSecClampTimer
 interval: 1000
 running: false
 repeat: false
 onTriggered: {
 var value = parseFloat(lonSeconds.text)
 if (!isNaN(value)) {
 value = Math.max(0, Math.min(60, value))
 lonSeconds.text = value
 }
 }
}
onTextChanged: lonSecClampTimer.restart()

 }

 // Update Button
 Button {
 text: "↺" // update from this row should get rid of this in future.....
     font.bold: true
    visible: true
    width: 35
    height: 35
    background: Rectangle {
        color: "#edad98"
        radius: width / 2
    }


 onClicked:{ 
 var latDeg = parseFloat(latDegrees.text) || 0
 var latMin = parseFloat(latMinutes.text) || 0
 var latSec = parseFloat(latSeconds.text) || 0
 var lonDeg = parseFloat(lonDegrees.text) || 0
 var lonMin = parseFloat(lonMinutes.text) || 0
 var lonSec = parseFloat(lonSeconds.text) || 0
 
 // should I notify the wgs84boxBox that this is a programmtic update?.
 wgs84Box.isProgrammaticUpdate = true
 // update the wgs84Box 
 if (latDeg < 0) { var latDecimal = latDeg - (latMin / 60) - (latSec / 3600) } 
 else
 var latDecimal = latDeg + (latMin / 60) + (latSec / 3600)
 if (lonDeg < 0) {
 var lonDecimal = lonDeg - (lonMin / 60) - (lonSec / 3600) } 
 else   
 var lonDecimal = lonDeg + (lonMin / 60) + (lonSec / 3600) 

 wgs84Box.text = latDecimal.toFixed(decimalsd.text) + ", " + lonDecimal.toFixed(decimalsd.text)

 // convert get X,Y from textfield:
 {var parts = wgs84Box.text.split(',')
 var xlat = parts[0] 
 var ylon = parts[1] 
 
 updateCoordinates(ylon, xlat, 4326, custom1CRS.text, custom2CRS.text,5)} 
 }


onPressAndHold: {
 var latDeg = parseFloat(latDegrees.text) || 0
 var latMin = parseFloat(latMinutes.text) || 0
 var latSec = parseFloat(latSeconds.visible ? latSeconds.text : 0) || 0
 var lonDeg = parseFloat(lonDegrees.text) || 0
 var lonMin = parseFloat(lonMinutes.text) || 0
 var lonSec = parseFloat(lonSeconds.visible ? lonSeconds.text : 0) || 0
 
 var latDecimal = latDeg + (latMin / 60) + (latSec / 3600)
 var lonDecimal = lonDeg + (lonMin / 60) + (lonSec / 3600)
 wgs84Box.text = latDecimal.toFixed(decimalsd.text) + ", " + lonDecimal.toFixed(decimalsd.text)

 // convert get X,Y from textfield:
 {var parts = wgs84Box.text.split(',')
 var xlat = parts[0] 
 var ylon = parts[1] 
 
 updateCoordinates(ylon, xlat, 4326, custom1CRS.text, custom2CRS.text,5)} 
 bigDialog2.open()
 } 
 }
 }
}

 
 
 
RowLayout{ 
 Label {
 id: label_2
 visible: true
 wrapMode: Text.Wrap
 font.bold: true
 text: qsTr("Do:")
 font.pixelSize: font_Size.text 
 font.family: "Arial" // Set font family
 font.italic: true // Make text italic
 } 
 
 Button {
 
 text: qsTr("Pan/\nZoom")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text  -3
 Layout.preferredHeight: 60 
 onClicked: { //pan to point
 // Parse coordinates from text fields 
 var parts = wgs84Box.text.split(',')
 var xIN = parts[1] 
 var yIN = parts[0] 
 var customcrsIN = CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"); 
 
 var customcrsOUT = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG); 
 var transformedPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(xIN, yIN), customcrsIN, customcrsOUT); 
 
 
 iface.mapCanvas().mapSettings.center.x = transformedPoint.x;
 iface.mapCanvas().mapSettings.center.y = transformedPoint.y;
 

 
 mainWindow.displayToast( transformedPoint.x + ", " + transformedPoint.y)
 mainDialog.close() 
 }
 onPressAndHold: { // zoom to point
 var parts = wgs84Box.text.split(',')
 var xIN = parts[1] 
 var yIN = parts[0]
 zoomToPoint(xIN, yIN, 4326)
 mainDialog.close()
 } 
 }
 
Button {
 text: qsTr("Add")
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 Layout.preferredHeight: 60 

 onClicked: {
    var parts = wgs84Box.text.split(',');
    if (parts.length < 2) {
        mainWindow.displayToast(qsTr("Input some coordinates first!"))
        return
    }
    addPoint(parts[1], parts[0], 4326)
    mainDialog.close();
 }    
}


Button {
 visible: true
 text: "Navigate/\nWeb"
  Layout.fillWidth: true
 font.bold: true
 font.pixelSize: font_Size.text -3
 Layout.preferredHeight: 60 
 onClicked: { 
 let navigation = iface.findItemByObjectName('navigation');
 
 // Parse coordinates and transform
 var parts = wgs84Box.text.split(',');
 var transformedPoint = GeometryUtils.reprojectPoint(
 GeometryUtils.point(parts[1], parts[0]),
 CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"),
 CoordinateReferenceSystemUtils.fromDescription("EPSG:" + canvasEPSG)
 );
 
 iface.mapCanvas().mapSettings.center.x = transformedPoint.x;
 iface.mapCanvas().mapSettings.center.y = transformedPoint.y;
 mainWindow.displayToast("navigating to:"+ transformedPoint.x + ", " + transformedPoint.y);

 // Directly set destination
 navigation.destination = transformedPoint;
 mainDialog.close()
 }
  onPressAndHold: {
    var parts = wgs84Box.text.split(',');
    if (parts.length < 2) {
        console.log("Invalid coordinate format");
        return;
    }

    var lon = parseFloat(parts[1]); // Ensure proper order
    var lat = parseFloat(parts[0]);

    Qt.openUrlExternally(buildMapsUrl(lat, lon));
     mainDialog.close()
}


}
Button {
 text: qsTr("BIG")
 
 font.bold: true
  Layout.fillWidth: true
 font.pixelSize: font_Size.text 
 Layout.preferredHeight: 60 
 onClicked: { 
    bigDialog.open() 
    }

 onPressAndHold: {
     bigDialog2.open() 
     }
 }
 } 
 

 
} // end of big column

Dialog {
    id: settingsDialog
    parent: mainWindow.contentItem
    modal: true
    title: qsTr("Settings")
    width: 380
    anchors.centerIn: parent
    onOpened: populatePointLayerPicker()

Column {
    width: parent.width
    spacing: 4

    // --- Add points to (top) ---
    Label { text: qsTr("    Add new points to:"); font.pixelSize: 12; font.family: "Arial"; font.italic: true }
    ComboBox {
        id: pointLayerCombo
        width: parent.width
        font.pixelSize: 12
        model: pointLayerPickerModel
        textRole: "name"
        onActivated: {
            var item = pointLayerPickerModel.get(currentIndex)
            if (item.isHeader) {
                currentIndex = currentIndex > 0 ? currentIndex - 1 : 0
                return
            }
            appSettings.pointLayerName = (currentIndex === 0) ? "" : item.name
        }
        delegate: ItemDelegate {
            width: pointLayerCombo.width
            enabled: !model.isHeader
            contentItem: Text {
                text: model.name
                font.pixelSize: 12
                font.italic: model.isHeader
                color: model.isHeader ? "#888888" : (highlighted ? "#ffffff" : "#000000")
                verticalAlignment: Text.AlignVCenter
                leftPadding: model.isHeader ? 4 : 8
            }
            highlighted: pointLayerCombo.highlightedIndex === index
        }
    }

    // --- Frame: display checkboxes ---
    GroupBox {
        title: qsTr("Display")
        width: parent.width
        GridLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 3
            columnSpacing: 0
            rowSpacing: 0
            CheckBox { id: showIG;       text: "Irish Grid"; font.pixelSize: 10; checked: true;  onCheckedChanged: { igridrow.visible = checked;      appSettings.showIG = checked } }
            CheckBox { id: showDegrees;  text: "Degrees";    font.pixelSize: 10; checked: false; onCheckedChanged: { wgsdegreesrow.visible = checked;  appSettings.showDegrees = checked } }
            CheckBox { id: showDMS;      text: "D M S.ss";   font.pixelSize: 10; checked: false; onCheckedChanged: { dmsrow.visible = checked;         appSettings.showDMS = checked } }
            CheckBox { id: showUK;       text: "UK Grid";    font.pixelSize: 10; checked: false; onCheckedChanged: { ukgridrow.visible = checked;      appSettings.showUK = checked } }
            CheckBox { id: showDM;       text: "D M.mm";     font.pixelSize: 10; checked: true;  onCheckedChanged: { dmrow.visible = checked;          appSettings.showDM = checked } }
            CheckBox { id: showCustom1;  text: "Custom 1";   font.pixelSize: 10; checked: false; onCheckedChanged: { custom1row.visible = checked;     appSettings.showCustom1 = checked } }
            CheckBox { id: showCustom2;  text: "Custom 2";   font.pixelSize: 10; checked: false; onCheckedChanged: { custom2row.visible = checked;     appSettings.showCustom2 = checked } }
            CheckBox { id: showDMSboxes;  text: "DMS Boxes"; font.pixelSize: 10; checked: true;  onCheckedChanged: { latlongboxesDMS.visible = checked; appSettings.showDMSboxes = checked } }
            CheckBox { id: showCrosshair; text: "Crosshair"; font.pixelSize: 10; checked: true; onCheckedChanged: { crosshair.visible = checked; appSettings.showCrosshair = checked } }
            
        }
    }

    // --- Frame: external map ---
    ButtonGroup { id: mapsUrlGroup }
    GroupBox {
        title: qsTr("External map")
        width: parent.width
        GridLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 2
            columnSpacing: 0
            rowSpacing: 0
            RadioButton { text: "GMaps pin";  font.pixelSize: 10; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 1; onCheckedChanged: if (checked) { mapsUrlOption = 1; appSettings.mapsUrlOption = 1 } }
            RadioButton { text: "GMaps nav";  font.pixelSize: 10; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 2; onCheckedChanged: if (checked) { mapsUrlOption = 2; appSettings.mapsUrlOption = 2 } }
            RadioButton { text: "OSM";        font.pixelSize: 10; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 3; onCheckedChanged: if (checked) { mapsUrlOption = 3; appSettings.mapsUrlOption = 3 } }
            RadioButton { text: "OSRM route"; font.pixelSize: 10; ButtonGroup.group: mapsUrlGroup; checked: mapsUrlOption === 4; onCheckedChanged: if (checked) { mapsUrlOption = 4; appSettings.mapsUrlOption = 4 } }
        }
    }

    // --- Frame: numeric/format settings ---
    GroupBox {
        title: qsTr("Format")
        width: parent.width
        GridLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            columns: 4
            columnSpacing: 0
            rowSpacing: 0
            Label { font.pixelSize: 10; font.family: "Arial"; font.italic: true; text: "Font Size:" }
            TextField {
                id: font_Size
                font.pixelSize: 10; font.family: "Arial"; font.italic: true
                text: fsize; Layout.preferredWidth: 40; Layout.preferredHeight: 20
                validator: IntValidator { bottom: 5; top: 25 }
                onTextChanged: appSettings.fontSize = text
            }
            Label { font.pixelSize: 10; font.family: "Arial"; font.italic: true; text: "Zoom:" }
            TextField {
                id: zoom
                font.pixelSize: 10; font.family: "Arial"; font.italic: true
                text: zoomV; Layout.preferredWidth: 40; Layout.preferredHeight: 20
                validator: IntValidator { bottom: 1; top: 10 }
                onTextChanged: appSettings.zoomLevel = text
            }
            Label { font.pixelSize: 10; font.family: "Arial"; font.italic: true; text: "Decimals (m):" }
            TextField {
                id: decimalsm
                font.pixelSize: 10; font.family: "Arial"; font.italic: true
                text: decm; Layout.preferredWidth: 40; Layout.preferredHeight: 20
                validator: IntValidator { bottom: 0; top: 10 }
                onTextChanged: appSettings.decimalsM = text
            }
            Label { font.pixelSize: 10; font.family: "Arial"; font.italic: true; text: "Decimals (deg):" }
            TextField {
                id: decimalsd
                font.pixelSize: 10; font.family: "Arial"; font.italic: true
                text: decd; Layout.preferredWidth: 40; Layout.preferredHeight: 20
                validator: IntValidator { bottom: 0; top: 10 }
                onTextChanged: appSettings.decimalsD = text
            }
        }
    }

    // --- Reset button (bottom) ---
    Button {
        text: qsTr("Reset")
        width: parent.width
        font.pixelSize: 10
        implicitHeight: 35
        onClicked: {
            custom1CRS.text = canvasEPSG
            custom2CRS.text = "4326"
            font_Size.text      = fsize;    appSettings.fontSize  = fsize
            decimalsm.text      = decm;     appSettings.decimalsM = decm
            decimalsd.text      = decd;     appSettings.decimalsD = decd
            zoom.text           = zoomV;    appSettings.zoomLevel = zoomV
            showIG.checked      = igvis;    showUK.checked        = ukgvis
            showCustom1.checked = custom1vis; showCustom2.checked = custom2vis
            showDegrees.checked = wgs84vis
            showDM.checked      = dmvis;    showDMS.checked       = dmsvis
            showDMSboxes.checked = dmsBoxesvis; showCrosshair.checked = crosshairvis
            mapsUrlOption = 3;              appSettings.mapsUrlOption = 3
            appSettings.pointLayerName = ""; pointLayerCombo.currentIndex = 0
        }
    }

    // --- Version ---
    Label {
        text: filetimedate
        width: parent.width
        font.pixelSize: 9
        font.family: "Arial"
        font.italic: true
        horizontalAlignment: Text.AlignRight
    }
} // end of column
} // end of settingsDialog
Dialog {
    id: bigDialog
    font.pixelSize: 35
    width: 350
    height: 400
    modal: true
    anchors.centerIn: parent

    Column {
        spacing: 20
        width: parent.width
        anchors.centerIn: parent

        // GPS Box
        Rectangle {
            id: gpsBox
            width: parent.width
            implicitHeight: childrenRect.height + 20
            color: "#D9CCE7"
            radius: 10
            border.color: "black"
            border.width: 0.5
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                id: childrenRect
                width: parent.width
                spacing: 10
                anchors.margins: 10
                anchors.centerIn: parent

                Label {
                    text: "GPS"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // IG (GPS)
                MouseArea {
                    width: parent.width
                    height: gpsIG.implicitHeight
                    onClicked: {
                        copyToClipboard(gpsIG.text)
                    }

                    Label {
                        id: gpsIG
                        text: (positionSource.active && positionSource.positionInformation.latitudeValid && positionSource.positionInformation.longitudeValid)
        ? ((showIG.checked
            ? justIG(positionSource.projectedPosition, canvasEPSG)
            : justUKG(positionSource.projectedPosition, canvasEPSG)))
        : "No GPS"
                        font.pixelSize: 35
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // LL (GPS)
                MouseArea {
                    width: parent.width
                    height: gpsLL.implicitHeight
                    onClicked: {
                        copyToClipboard(gpsLL.text)
                    }

                    Label {
                        id: gpsLL
                        text: (positionSource.active && positionSource.positionInformation.latitudeValid && positionSource.positionInformation.longitudeValid)
                            ? justLL(positionSource.projectedPosition, canvasEPSG)
                            : ""
                        font.pixelSize: 30
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        // Screen Center Box
        Rectangle {
            id: screenBox
            width: parent.width
            implicitHeight: childrenRect2.height + 20
            color: "#f0f0f0"
            radius: 10
            border.color: "black"
            border.width: 0.5
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                id: childrenRect2
                width: parent.width
                spacing: 10
                anchors.margins: 10
                anchors.centerIn: parent

                Label {
                    text: "Screen Center"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // IG (Screen Center)
                MouseArea {
                    width: parent.width
                    height: screenIG.implicitHeight
                    onClicked: {
                        copyToClipboard(screenIG.text)
                    }

                    Label {
                        id: screenIG
                        text:  showIG.checked ? justIG(canvas.center, canvasEPSG) :justUKG(canvas.center, canvasEPSG)
                        font.pixelSize: 35
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // LL (Screen Center)
                MouseArea {
                    width: parent.width
                    height: screenLL.implicitHeight
                    onClicked: {
                        copyToClipboard(screenLL.text)
                    }

                    Label {
                        id: screenLL
                        text: justLL(canvas.center, canvasEPSG)
                        font.pixelSize: 30
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}

Dialog {
    id: bigDialog2
    font.pixelSize: 35
    width: 400
    height: 350
    modal: true
    anchors.centerIn: parent

    // Third Box: Box contents
    Rectangle {
        id: boxBox
        width: parent.width
        implicitHeight: childrenRect3.height + 20
        color: "#f0fef0"
        radius: 10
        border.color: "black"
        border.width: 0.5
        anchors.horizontalCenter: parent.horizontalCenter

        Column {
            id: childrenRect3
            width: parent.width
            spacing: 10
            anchors.margins: 10
            anchors.centerIn: parent

            Label {
                text: "Text box contents"
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // igInputBox text
            MouseArea {
                width: parent.width
                height: igCopy.implicitHeight
                onClicked: {
                    copyToClipboard(igCopy.text)
                }

                Label {
                    id: igCopy
                    text: igInputBox.text
                    font.pixelSize: 35
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // wgs84Box text
            MouseArea {
                width: parent.width
                height: wgs84Copy.implicitHeight
                onClicked: {
                    copyToClipboard(wgs84Copy.text)
                }

                Label {
                    id: wgs84Copy
                    text: wgs84Box.text
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // wgs84DMBox text
            MouseArea {
                width: parent.width
                height: wgs84DMCopy.implicitHeight
                onClicked: {
                    copyToClipboard(wgs84DMCopy.text)
                }

                Label {
                    id: wgs84DMCopy
                    text: wgs84DMBox.text
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // wgs84DMSBox text
            MouseArea {
                width: parent.width
                height: wgs84DMSCopy.implicitHeight
                onClicked: {
                    copyToClipboard(wgs84DMSCopy.text)
                }

                Label {
                    id: wgs84DMSCopy
                    text: wgs84DMSBox.text
                    font.pixelSize: 30
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}

}
 




 // Lookup table for the IG letter matrix (for EPSG:29903 /29902)
 property var igletterMatrix: {
 'V': { first: 0, second: 0 },
 'W': { first: 1, second: 0 },
 'X': { first: 2, second: 0 },
 'Y': { first: 3, second: 0 },
 'Z': { first: 4, second: 0 },
 'Q': { first: 0, second: 1 },
 'R': { first: 1, second: 1 },
 'S': { first: 2, second: 1 },
 'T': { first: 3, second: 1 },
 'L': { first: 0, second: 2 },
 'M': { first: 1, second: 2 },
 'N': { first: 2, second: 2 },
 'O': { first: 3, second: 2 },
 'P': { first: 4, second: 2 },
 'F': { first: 0, second: 3 },
 'G': { first: 1, second: 3 },
 'H': { first: 2, second: 3 },
 'J': { first: 3, second: 3 },
 'K': { first: 4, second: 3 },
 'A': { first: 0, second: 4 },
 'B': { first: 1, second: 4 },
 'C': { first: 2, second: 4 },
 'D': { first: 3, second: 4 },
 'E': { first: 4, second: 4 }
 }
// Lookup table for the UK letter matrix (for EPSG:27700)
property var ukletterMatrix: {
 'SV': { first: 0, second: 0 },
 'SW': { first: 1, second: 0 },
 'SX': { first: 2, second: 0 },
 'SY': { first: 3, second: 0 },
 'SZ': { first: 4, second: 0 },
 'TV': { first: 5, second: 0 },
 'SR': { first: 1, second: 1 },
 'SS': { first: 2, second: 1 },
 'ST': { first: 3, second: 1 },
 'SU': { first: 4, second: 1 },
 'TQ': { first: 5, second: 1 },
 'TR': { first: 6, second: 1 },
 'SM': { first: 1, second: 2 },
 'SN': { first: 2, second: 2 },
 'SO': { first: 3, second: 2 },
 'SP': { first: 4, second: 2 },
 'TL': { first: 5, second: 2 },
 'TM': { first: 6, second: 2 },
 'SH': { first: 2, second: 3 },
 'SJ': { first: 3, second: 3 },
 'SK': { first: 4, second: 3 },
 'TF': { first: 5, second: 3 },
 'TG': { first: 6, second: 3 },
 'SC': { first: 2, second: 4 },
 'SD': { first: 3, second: 4 },
 'SE': { first: 4, second: 4 },
 'TA': { first: 5, second: 4 },
 'NW': { first: 1, second: 5 },
 'NX': { first: 2, second: 5 },
 'NY': { first: 3, second: 5 },
 'NZ': { first: 4, second: 5 },
 'OV': { first: 5, second: 5 },
 'NR': { first: 1, second: 6 },
 'NS': { first: 2, second: 6 },
 'NT': { first: 3, second: 6 },
 'NU': { first: 4, second: 6 },
 'NL': { first: 0, second: 7 },
 'NM': { first: 1, second: 7 },
 'NN': { first: 2, second: 7 },
 'NO': { first: 3, second: 7 },
 'HW': { first: 1, second: 10 },
 'HX': { first: 2, second: 10 },
 'HY': { first: 3, second: 10 },
 'HZ': { first: 4, second: 10 },
 'NF': { first: 0, second: 8 },
 'NG': { first: 1, second: 8 },
 'NH': { first: 2, second: 8 },
 'NJ': { first: 3, second: 8 },
 'NK': { first: 4, second: 8 },
 'NA': { first: 0, second: 9 },
 'NB': { first: 1, second: 9 },
 'NC': { first: 2, second: 9 },
 'ND': { first: 3, second: 9 },
 'HT': { first: 3, second: 11 },
 'HU': { first: 4, second: 11 },
 'HP': { first: 4, second: 12 }}

function validateInput(textBox) {
    // Your validation logic here
    console.log("Validating input for:", textBox.objectName);

    // Example validation logic
    var inputText = textBox.text;
    var cleanedText = inputText.replace(/[^0-9-.,\s]/g, '');
    var parts = cleanedText.split(',');

    if (parts.length > 2) {
        cleanedText = parts[0] + ',' + parts[1];
        parts = cleanedText.split(',');
    }

    // Process each part
    for (var i = 0; i < parts.length; i++) {
        var num = parts[i].trim();

        if (num === '' || num === '-' || num.match(/^-?\d*\.?\d*$/)) {
            parts[i] = num;
            continue;
        }

        var dots = (num.match(/\./g) || []).length;
        if (dots > 1) {
            var firstDotIndex = num.indexOf('.');
            num = num.substring(0, firstDotIndex + 1) + num.substring(firstDotIndex + 1).replace(/\./g, '');
        }

        var value = parseFloat(num);
        if (isNaN(value)) {
            num = num.replace(/[^0-9-.]/g, '');
        } else if (value < -1000000) {
            num = '';
        } else if (value > 1000000) {
            num = '';
        } else {
            num = value.toString();
        }
        parts[i] = num;
    }

    // Reconstruct the text
    cleanedText = parts[0] || '';
    if (parts.length > 1) {
        cleanedText += ', ' + (parts[1] || '');
    }

    // Update the text box if the text has changed
    if (textBox.text !== cleanedText) {
        textBox.isProgrammaticUpdate = true;
        textBox.text = cleanedText;
    }
}

// Converts a projected (x, y) coordinate to a national grid reference string
// (e.g. "H 54321 89797" for Irish Grid, "NS 45140 72887" for UK Grid).
// Works for both grids — pass the appropriate maxCoord and letterMatrix:
//   Irish Grid:  maxCoord = 1 000 000,  letterMatrix = igletterMatrix
//   UK Grid:     maxCoord = 10 000 000, letterMatrix = ukletterMatrix
// The algorithm divides x/y into 100 km tiles, looks up the tile letter(s),
// then takes the remainder within the tile as a zero-padded 5-digit number.
function getGridRefFromXY(x, y, maxCoord, letterMatrix) {
    if (x < 0 || y < 0 || x >= maxCoord || y >= maxCoord) return ""
    var firstIndex  = Math.floor(x / 100000)
    var secondIndex = Math.floor(y / 100000)
    var letters = Object.keys(letterMatrix).find(function(key) {
        return letterMatrix[key].first === firstIndex && letterMatrix[key].second === secondIndex
    })
    if (!letters) return ""
    return letters + ' ' + String(Math.round(x % 100000)).padStart(5, '0') + ' ' + String(Math.round(y % 100000)).padStart(5, '0')
}

function getIGFromXY(x, y) { return getGridRefFromXY(x, y, 1000000,  igletterMatrix) }
function getUKFromXY(x, y) { return getGridRefFromXY(x, y, 10000000, ukletterMatrix) }

function decimalToDDM(decimal) {
 if (typeof decimal !== 'number' || isNaN(decimal)) return ''
 
 var sign = decimal < 0 ? '-' : ''
 var absDecimal = Math.abs(decimal)
 
 var degrees = Math.floor(absDecimal)
 var minutes = (absDecimal - degrees) * 60
 
 return `${sign}${degrees}° ${minutes.toFixed(3)}'`

}
 


function decTODeg(decimal) {
if (typeof decimal !== 'number' || isNaN(decimal)) {
 return ''
 }
 
 const sign = decimal < 0 ? -1 : 1
 const absDecimal = Math.abs(decimal)
 return Math.floor(absDecimal) * sign
}



function degtoSeconds(decimal) {
 if (typeof decimal !== 'number' || isNaN(decimal)) {
 return ''
 }
 
 const absDecimal = Math.abs(decimal)
 const degrees = Math.floor(absDecimal)
 const minutes = (absDecimal - degrees) * 60
 return ((minutes - Math.floor(minutes)) * 60).toFixed(2)
}

// Reprojects (x, y) from sourceEPSG and updates every coordinate display box
// EXCEPT the one that triggered the call (to avoid infinite update loops).
// inputDialog values:
//   1 = Irish Grid input      (igInputBox)
//   2 = UK Grid input         (ukInputBox)
//   3 = Custom 1 input        (custom1BoxXY)
//   4 = Custom 2 input        (custom2BoxXY)
//   5 = WGS84 decimal input   (wgs84Box)
//   6 = WGS84 DDM/DMS input   (wgs84DMBox / DMS boxes)
//   undefined = external call — update everything
// isProgrammaticUpdate is set before each text assignment to suppress the
// box's own onTextChanged handler from firing a second updateCoordinates call.
 function updateCoordinates(x, y, sourceEPSG, targetEPSG1, targetEPSG2, inputDialog) {
 var sourceCrs = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(sourceEPSG))
 var targetCrs1 = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(targetEPSG1))
 var targetCrs2 = CoordinateReferenceSystemUtils.fromDescription("EPSG:" + parseInt(targetEPSG2))

 if (inputDialog !== 1) { // Update IG
 var igPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, CoordinateReferenceSystemUtils.fromDescription("EPSG:29903"))
 var igRef = getIGFromXY(igPoint.x, igPoint.y)
 igInputBox.isProgrammaticUpdate = true
 igInputBox.text = igRef
 // Hide the row when the point is outside Irish Grid coverage (result is "")
 igridrow.visible = showIG.checked && igRef !== ""
 }

 if (inputDialog !== 2) { // Update UK
 var ukPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, CoordinateReferenceSystemUtils.fromDescription("EPSG:27700"))
 var ukRef = getUKFromXY(ukPoint.x, ukPoint.y)
 ukInputBox.isProgrammaticUpdate = true
 ukInputBox.text = ukRef
 // Hide the row when the point is outside UK Grid coverage (result is "")
 ukgridrow.visible = showUK.checked && ukRef !== ""
 }

 if (inputDialog !== 3) { // Update Custom1
 var custom1Point = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, targetCrs1)
 custom1BoxXY.isProgrammaticUpdate = true
 custom1BoxXY.text = formatPoint(custom1Point, targetCrs1)
 }

 if (inputDialog !== 4) { // Update Custom2
 var custom2Point = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, targetCrs2)
 custom2BoxXY.isProgrammaticUpdate = true
 custom2BoxXY.text = formatPoint(custom2Point, targetCrs2)
 }

 if (inputDialog !== 5) { // Update WGS84
 var wgs84Point = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
 wgs84Box.isProgrammaticUpdate = true
 wgs84Box.text = parseFloat(wgs84Point.y.toFixed(decimalsd.text)) + ", " + parseFloat(wgs84Point.x.toFixed(decimalsd.text))
 }

 if (inputDialog !== 6) { // Update WGS84 DDM
 var wgs84dmPoint = GeometryUtils.reprojectPoint(GeometryUtils.point(x, y), sourceCrs, CoordinateReferenceSystemUtils.fromDescription("EPSG:4326")) 
 wgs84DMBox.isProgrammaticUpdate = true
 wgs84DMBox.text = decimalToDDM(wgs84dmPoint.y) + ", " + decimalToDDM(wgs84dmPoint.x)
 
 wgs84DMSBox.text = decimalToDMss(wgs84dmPoint.y) + ", " + decimalToDMss(wgs84dmPoint.x)

 // Update d m s boxes
 latDegrees.text = decTODeg(wgs84dmPoint.y)
 latMinutes.text = decimalToMinutes(wgs84dmPoint.y)
 latSeconds.text = degtoSeconds(wgs84dmPoint.y)
 lonDegrees.text = decTODeg(wgs84dmPoint.x)
 lonMinutes.text = decimalToMinutes(wgs84dmPoint.x)
 lonSeconds.text = degtoSeconds(wgs84dmPoint.x) 

 } 
 }

// Quick-format helpers used by bigDialog to show GPS / screen-centre positions.
// Each reprojects a {x, y} source point and returns a formatted string.
// source.x/y are in the CRS given by `crs` (EPSG integer).

// Returns an Irish Grid reference string, or "" if out of range.
function justIG(source,crs){
var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),  CoordinateReferenceSystemUtils.fromDescription("EPSG:"+crs) , CoordinateReferenceSystemUtils.fromDescription("EPSG:29903"))
 return getIGFromXY(point.x, point.y)
 }

// Returns a UK National Grid reference string, or "" if out of range.
function justUKG(source,crs){
var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),  CoordinateReferenceSystemUtils.fromDescription("EPSG:"+crs) , CoordinateReferenceSystemUtils.fromDescription("EPSG:27700"))
 return getUKFromXY(point.x, point.y)
 }

// Returns a WGS84 "lat, lon" string rounded to the current decimals setting.
function justLL(source,crs){
var point = GeometryUtils.reprojectPoint(GeometryUtils.point(source.x, source.y),  CoordinateReferenceSystemUtils.fromDescription("EPSG:"+crs) , CoordinateReferenceSystemUtils.fromDescription("EPSG:4326"))
return ( point.y.toFixed(decimalsd.text)+", "+ point.x.toFixed(decimalsd.text) )  // y=lat, x=lon
 }

 
 // Formats a reprojected point as "x, y" (easting/lon first, northing/lat second).
 // Uses the metres decimal setting for projected CRS, degrees setting for geographic.
 function formatPoint(point, crs) {
 if (!crs.isGeographic) {
 return parseFloat(point.x.toFixed(decimalsm.text)) + ", " + parseFloat(point.y.toFixed(decimalsm.text))
 } else {
 return parseFloat(point.x.toFixed(decimalsd.text)) + ", " + parseFloat(point.y.toFixed(decimalsd.text))
 }
 }


 // Returns the whole-minutes component of a decimal degree value (0–59).
 // Used to populate the DMS minute input boxes.
 function decimalToMinutes(decimal) {
if (typeof decimal !== 'number' || isNaN(decimal)) return ''
    var absDecimal = Math.abs(decimal);
    var degrees = Math.floor(absDecimal);
    return Math.floor((absDecimal - degrees) * 60);
}

 function decimalToDMss(decimal) {

if (typeof decimal !== 'number' || isNaN(decimal)) return ''

    var sign = decimal < 0 ? '-' : '';
    var absDecimal = Math.abs(decimal);

    var degrees = Math.floor(absDecimal);
    var minutes = Math.floor((absDecimal - degrees) * 60);
    var seconds = ((absDecimal - degrees - minutes / 60) * 3600).toFixed(2);

    return `${sign}${degrees}° ${minutes}' ${seconds}"`;
}
 

}
