pragma Singleton
import QtQuick

// Coordinates bar dropdowns so only one is ever open at a time. Every
// dropdown (BarPopup instances, CalendarPopup) calls requestOpen() from its
// own open() and notifyClosed() from its own close(), so closing via
// Escape/click-outside/re-toggle stays in sync with this too.
QtObject {
    property var activePopup: null

    function requestOpen(p) {
        if (activePopup && activePopup !== p) activePopup.close()
        activePopup = p
    }

    function notifyClosed(p) {
        if (activePopup === p) activePopup = null
    }
}
