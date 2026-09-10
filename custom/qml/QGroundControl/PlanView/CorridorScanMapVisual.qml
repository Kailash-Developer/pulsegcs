import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap
import QGroundControl.PlanView

/// Corridor Scan Complex Mission Item visuals
TransectStyleMapVisuals {
    polygonInteractive: false
    hideMapPolygon:     mapPolylineVisuals.dragging

    property bool _currentItem: object.isCurrentItem

    QGCPalette { id: qgcPal }

    QGCMapPolylineVisuals {
        id:             mapPolylineVisuals
        mapControl:     map
        mapPolyline:    object.corridorPolyline
        interactive:    _currentItem && parent.interactive
        lineWidth:      3
        lineColor:      qgcPal.mapMissionTrajectory
        visible:        _currentItem
        opacity:        parent.opacity
    }
}
