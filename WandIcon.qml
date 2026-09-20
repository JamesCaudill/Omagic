import QtQuick
import QtQuick.Shapes
import qs.Commons

// An open O orbit, a wand, and a four-point spark on a 24 px design grid.
Item {
  id: root
  property color color: Color.foreground
  property string fontFamily: "" // Retained for existing panel callers.
  implicitWidth: 24
  implicitHeight: 24

  Item {
    width: 24
    height: 24
    anchors.centerIn: parent
    scale: Math.min(root.width, root.height) / 24

    Shape {
      anchors.fill: parent
      antialiasing: true

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: 1.8
        capStyle: ShapePath.RoundCap
        PathSvg {
          path: "M 11.5 4.5 C 6.6 4.2 2.7 8 2.7 12.8 C 2.7 17.5 6.5 21.3 11.2 21.3 C 15.9 21.3 19.7 17.5 19.7 12.8"
        }
      }

      ShapePath {
        fillColor: "transparent"
        strokeColor: root.color
        strokeWidth: 2.4
        capStyle: ShapePath.RoundCap
        PathSvg { path: "M 6.7 17.3 L 12.4 11.6" }
      }

      ShapePath {
        fillColor: root.color
        strokeWidth: 0
        PathSvg {
          path: "M 17.5 1.5 Q 18.5 5.5 22.5 6.5 Q 18.5 7.5 17.5 11.5 Q 16.5 7.5 12.5 6.5 Q 16.5 5.5 17.5 1.5 Z"
        }
      }
    }
  }
}
