import QtQuick
import qs

// =============================================================================
// Calendar — a real, navigable month grid.
// =============================================================================
// Replaces waycal (a small Rust binary in ~/.cargo/bin opened by clicking the
// waybar clock). waycal is a perfectly good calendar; it is simply a separate
// application with its own window, its own colours and its own idea of what a
// calendar looks like, which is the fragmentation this migration is undoing.
//
// A reusable component: the dashboard embeds it, and so can anything else.
// It keeps its own browsing position, so paging to next month and closing the
// panel does not leave it stuck there -- `reset()` is called on open.
//
// WEEK START
//   Monday. Qt's Date.getDay() returns 0 for Sunday, so the column index is
//   (day + 6) % 7 rather than day. Getting that wrong shifts the entire grid by
//   one and is the classic calendar bug.
// =============================================================================

Column {
    id: root

    // The month being viewed, as an offset from the current one. 0 is today's
    // month; negative is the past.
    property int monthOffset: 0

    // -----------------------------------------------------------------
    // Stepping, with motion
    //
    // The grid slides in the direction of travel and cross-fades, so paging
    // through months reads as movement along a timeline rather than as the
    // numbers being swapped out underneath you. Direction matters: going back
    // slides right, going forward slides left, matching the arrow you pressed.
    //
    // The swap happens at the midpoint of the animation, while the grid is off
    // to one side and transparent -- so the new month is never seen arriving in
    // the old one's position.
    //
    // A single reusable animation rather than one per direction: `slideFrom`
    // carries the sign, and the animation reads it.
    // -----------------------------------------------------------------

    // Horizontal offset applied to the grid while a step is in flight.
    property real slide: 0
    property real gridOpacity: 1

    function step(months) {
        if (months === 0) return;
        if (Appearance.motionless) {
            root.monthOffset += months;
            return;
        }
        stepAnimation.stop();
        stepAnimation.months = months;
        stepAnimation.start();
    }

    SequentialAnimation {
        id: stepAnimation

        property int months: 1
        // Travel distance. Enough to read as movement, short enough that a
        // held arrow key does not feel like scrubbing.
        readonly property real distance: 26

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "slide"
                to: stepAnimation.months > 0 ? -stepAnimation.distance : stepAnimation.distance
                duration: Appearance.duration(110)
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root; property: "gridOpacity"; to: 0
                duration: Appearance.duration(110)
                easing.type: Easing.InCubic
            }
        }

        // The swap, at the midpoint.
        ScriptAction {
            script: {
                root.monthOffset += stepAnimation.months;
                // Jump to the far side so the new month slides IN from the
                // direction it is arriving from.
                root.slide = stepAnimation.months > 0
                    ? stepAnimation.distance : -stepAnimation.distance;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "slide"; to: 0
                duration: Appearance.duration(220)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "gridOpacity"; to: 1
                duration: Appearance.duration(220)
                easing.type: Easing.OutCubic
            }
        }
    }

    // -----------------------------------------------------------------
    // Keyboard
    //
    //   left / right   previous / next month
    //   up   / down    previous / next year
    //   home / t       back to today
    //
    // Up is the PAST and down is the future, so that up/down pair with
    // left/right consistently: both "back" directions are up-and-left, both
    // "forward" directions are down-and-right.
    //
    // Held keys are fine: step() cancels an animation already in flight and
    // starts the next, so paging quickly skips ahead rather than queueing a
    // backlog of slides to sit through.
    // -----------------------------------------------------------------

    focus: true

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Left:  root.step(-1);  event.accepted = true; break;
        case Qt.Key_Right: root.step(1);   event.accepted = true; break;
        case Qt.Key_Up:    root.step(-12); event.accepted = true; break;
        case Qt.Key_Down:  root.step(12);  event.accepted = true; break;
        case Qt.Key_Home:
        case Qt.Key_T:
            if (root.monthOffset !== 0) root.step(-root.monthOffset);
            event.accepted = true;
            break;
        }
    }

    readonly property date viewed: {
        const now = Time.now;
        return new Date(now.getFullYear(), now.getMonth() + root.monthOffset, 1);
    }

    readonly property int viewedYear: root.viewed.getFullYear()
    readonly property int viewedMonth: root.viewed.getMonth()
    readonly property bool atToday: root.monthOffset === 0

    function reset() { root.monthOffset = 0; }

    // Days in the viewed month. Day 0 of the NEXT month is the last day of
    // this one -- the standard trick, and it handles February and leap years
    // without a table.
    readonly property int daysInMonth: new Date(root.viewedYear, root.viewedMonth + 1, 0).getDate()

    // Which column the 1st falls in, Monday-first.
    readonly property int firstColumn: {
        const day = new Date(root.viewedYear, root.viewedMonth, 1).getDay();
        return (day + 6) % 7;
    }

    // Trailing days of the previous month, so the grid starts full rather than
    // with a ragged hole.
    readonly property int daysInPrevMonth: new Date(root.viewedYear, root.viewedMonth, 0).getDate()

    spacing: Appearance.sm

    // Scrolling anywhere over the calendar pages months, which is what most
    // people try first.
    // A WheelHandler, not a MouseArea: an Item child with anchors.fill inside a
    // Column makes the Column refuse to position ANY of its children, which
    // stacks the whole calendar at 0,0. Input handlers are not Items, so the
    // positioner never sees this one.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }

    // --- header ----------------------------------------------------------
    Item {
        width: parent.width
        implicitHeight: Appearance.controlHeightSmall

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.xs

            Text {
                text: Qt.formatDate(root.viewed, "MMMM")
                color: Theme.text
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                font.weight: Appearance.weightSemi
                font.letterSpacing: Appearance.trackingHeading
                anchors.verticalCenter: parent.verticalCenter
            }

            // The year is dimmer, so the month reads first -- you almost
            // always know what year it is.
            Text {
                text: Qt.formatDate(root.viewed, "yyyy")
                color: root.atToday ? Theme.muted : Theme.accent
                font.family: Appearance.font
                font.pixelSize: Appearance.fontTitle
                font.weight: Appearance.weightNormal
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    enabled: !Appearance.motionless
                    ColorAnimation { duration: Appearance.durationNormal }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.xs

            Button {
                width: Appearance.controlHeightSmall
                height: Appearance.controlHeightSmall
                variant: "ghost"
                icon: "chevron-left"
                onClicked: root.step(-1)
            }

            // Only offered when it would do something.
            Button {
                width: visible ? implicitWidth : 0
                height: Appearance.controlHeightSmall
                visible: !root.atToday
                variant: "soft"
                text: "Today"
                onClicked: root.step(-root.monthOffset)
            }

            Button {
                width: Appearance.controlHeightSmall
                height: Appearance.controlHeightSmall
                variant: "ghost"
                icon: "chevron-right"
                onClicked: root.step(1)
            }
        }
    }

    // --- weekday labels ----------------------------------------------------
    Row {
        width: parent.width

        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

            Item {
                required property string modelData
                required property int index

                width: root.width / 7
                height: 24

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    // Weekend labels sit back, so the working week reads first.
                    color: index >= 5 ? Theme.wash(Theme.muted, 0.6) : Theme.muted
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontCaption
                    font.weight: Appearance.weightMedium
                    font.letterSpacing: Appearance.trackingLabel
                }
            }
        }
    }

    // --- grid ---------------------------------------------------------------
    // Always six rows. A fixed height stops the panel resizing as you page
    // between a month that needs five rows and one that needs six.
    Grid {
        width: parent.width
        columns: 7

        // Carries the step animation. A transform rather than a layout change,
        // so nothing relayouts during the slide.
        x: root.slide
        opacity: root.gridOpacity

        Repeater {
            model: 42

            Item {
                required property int index

                width: root.width / 7
                height: 34

                // Which day this cell shows, and whether it belongs to the
                // month being viewed.
                readonly property int dayNumber: {
                    const offset = index - root.firstColumn;
                    if (offset < 0) return root.daysInPrevMonth + offset + 1;
                    if (offset >= root.daysInMonth) return offset - root.daysInMonth + 1;
                    return offset + 1;
                }

                readonly property bool inMonth: {
                    const offset = index - root.firstColumn;
                    return offset >= 0 && offset < root.daysInMonth;
                }

                readonly property bool isToday: inMonth
                    && root.viewedYear === Time.year
                    && root.viewedMonth === Time.month
                    && dayNumber === Time.day

                readonly property bool isWeekend: (index % 7) >= 5

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: parent.isToday ? Theme.accent
                         : dayMouse.containsMouse && parent.inMonth ? Theme.hover
                         : "transparent"

                    Behavior on color {
                        enabled: !Appearance.motionless
                        ColorAnimation { duration: Appearance.durationFast }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.dayNumber
                    color: {
                        if (parent.isToday) return Theme.onAccent(Theme.accent);
                        if (!parent.inMonth) return Theme.wash(Theme.muted, 0.35);
                        if (parent.isWeekend) return Theme.wash(Theme.text, 0.65);
                        return Theme.text;
                    }
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSmall
                    font.weight: parent.isToday ? Appearance.weightSemi : Appearance.weightNormal
                }

                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: parent.inMonth
                }
            }
        }
    }
}
